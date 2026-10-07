"""防滥用限流（S-5）：固定窗口计数，存 rate_limit_counters 表。

- 窗口按 Unix 纪元对齐、统一 UTC：按天的额度在 UTC 0 点（北京时间 8 点）重置
- 计数：INSERT ... ON DUPLICATE KEY UPDATE count = count + 1（不用已废弃的 VALUES()），
  同一事务里读回计数后立即提交。同一行的写入由 InnoDB 行锁串行化，并发下不会少算
- 先计数再比较：count > limit 即超限。被拒绝的请求同样计入（计数只用于比较，多计不影响结果）
- 客户端 IP 只取 TCP 连接地址，不读 X-Forwarded-For 等请求头（部署到反向代理后的调整见 CLAUDE.md 第 10 节）
"""
import ipaddress
import logging
import math
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from sqlalchemy import delete, func, select
from sqlalchemy.dialects.mysql import insert as mysql_insert
from sqlalchemy.exc import DBAPIError

from app.core.config import settings
from app.models.rate_limit import RateLimitCounter
from app.schemas.common import utcnow

logger = logging.getLogger("app.ratelimit")

# scope → (额度配置项, 窗口配置项)
RULE_SETTINGS = {
    "ocr": ("rate_limit_ocr_per_user", "rate_limit_ocr_window_seconds"),
    "compose": ("rate_limit_compose_per_user", "rate_limit_compose_window_seconds"),
    "login": ("rate_limit_login_per_ip", "rate_limit_login_window_seconds"),
    "register": ("rate_limit_register_per_ip", "rate_limit_register_window_seconds"),
}

# scope → 429 文案模板；{period} 如"每天"，{limit} 为额度，{wait} 如"请约 3 小时后再试"/"请 8 分钟后再试"
DETAIL_TEMPLATES = {
    "ocr": "识别次数已用完（{period} {limit} 次），{wait}",
    "compose": "生成次数已用完（{period} {limit} 次），{wait}",
    "login": "登录尝试过于频繁（{period} {limit} 次），{wait}",
    "register": "注册过于频繁（{period} {limit} 次），{wait}",
}

# 死锁（1213）与锁等待超时（1205）时整笔重试
RETRYABLE_ERRNOS = {1213, 1205}
MAX_ATTEMPTS = 3

# 过期窗口保留时长（IP 属于个人信息，不超过 2 天）。窗口配置上限为 1 天，保证清理不会删到当前窗口
RETENTION = timedelta(days=2)
CLEANUP_BATCH_SIZE = 1000

# 时钟：测试中替换为固定时间
clock = utcnow


@dataclass(frozen=True)
class Rule:
    scope: str
    limit: int
    window_seconds: int


@dataclass(frozen=True)
class Decision:
    allowed: bool
    count: int
    retry_after: int


def get_rule(scope: str) -> Rule:
    limit_attr, window_attr = RULE_SETTINGS[scope]
    return Rule(scope, getattr(settings, limit_attr), getattr(settings, window_attr))


def window_of(now: datetime, window_seconds: int) -> tuple[datetime, int]:
    """返回 (窗口起点（不带时区的 UTC）, 距窗口结束的秒数（向上取整，至少 1）)。"""
    ts = now.replace(tzinfo=timezone.utc).timestamp()
    start = int(ts // window_seconds) * window_seconds
    retry_after = max(1, math.ceil(start + window_seconds - ts))
    return datetime.fromtimestamp(start, timezone.utc).replace(tzinfo=None), retry_after


# ---- 计数主体 -------------------------------------------------------------------

def user_subject(user_id: int) -> str:
    return f"u:{user_id}"


def client_ip(request) -> str:
    """TCP 连接的对端地址（日志用）。不读 X-Forwarded-For。"""
    return request.client.host if request.client else "unknown"


def ip_subject(request) -> str:
    """按 IP 计数的主体：IPv4 按单个地址；IPv6 归并到 /64（同一用户可在自己的 /64 内随意换地址）。"""
    try:
        addr = ipaddress.ip_address(client_ip(request))
    except ValueError:
        return "ip:unknown"
    if addr.version == 6:
        if addr.ipv4_mapped is not None:
            return f"ip:{addr.ipv4_mapped}"
        return f"ip:{ipaddress.ip_network(f'{addr}/64', strict=False)}"
    return f"ip:{addr}"


# ---- 计数 -----------------------------------------------------------------------

def counter_upsert(scope: str, subject: str, window_start: datetime):
    stmt = mysql_insert(RateLimitCounter).values(scope=scope, subject=subject, window_start=window_start, count=1)
    return stmt.on_duplicate_key_update(count=RateLimitCounter.count + 1)


def _errno(exc: DBAPIError) -> int | None:
    args = getattr(exc.orig, "args", ())
    return args[0] if args and isinstance(args[0], int) else None


async def hit(session, rule: Rule, subject: str, now: datetime | None = None) -> Decision:
    """计数一次并判断是否超限。在调用方的会话中执行并立即提交，行锁只持有几毫秒。"""
    window_start, retry_after = window_of(now or clock(), rule.window_seconds)
    key = (
        RateLimitCounter.scope == rule.scope,
        RateLimitCounter.subject == subject,
        RateLimitCounter.window_start == window_start,
    )
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            await session.execute(counter_upsert(rule.scope, subject, window_start))
            count = await session.scalar(select(RateLimitCounter.count).where(*key))
            await session.commit()
            break
        except DBAPIError as e:
            await session.rollback()
            if _errno(e) not in RETRYABLE_ERRNOS or attempt == MAX_ATTEMPTS:
                raise
            logger.info("rate limit counter retry %d after errno %s", attempt, _errno(e))
    return Decision(allowed=count <= rule.limit, count=count, retry_after=retry_after)


# ---- 429 ------------------------------------------------------------------------

def format_wait(seconds: int) -> str:
    if seconds >= 3600:
        return f"约 {max(1, round(seconds / 3600))} 小时"
    return f"{max(1, math.ceil(seconds / 60))} 分钟"


def period_text(window_seconds: int) -> str:
    for unit, single, name in ((86400, "每天", "天"), (3600, "每小时", "小时"), (60, "每分钟", "分钟")):
        if window_seconds % unit == 0:
            n = window_seconds // unit
            return single if n == 1 else f"每 {n} {name}"
    return f"每 {window_seconds} 秒"


def too_many_detail(rule: Rule, retry_after: int) -> str:
    wait = format_wait(retry_after)
    wait = f"请{wait}后再试" if wait.startswith("约") else f"请 {wait}后再试"
    return DETAIL_TEMPLATES[rule.scope].format(period=period_text(rule.window_seconds), limit=rule.limit, wait=wait)


async def enforce(session, scope: str, subject: str) -> None:
    """计数一次；超限时抛 429（中文 detail，带 Retry-After）。限流关闭时不访问数据库。"""
    if not settings.rate_limit_enabled:
        return
    rule = get_rule(scope)
    decision = await hit(session, rule, subject)
    if not decision.allowed:
        logger.warning(
            "rate limit exceeded: scope=%s subject=%s count=%d limit=%d",
            rule.scope, subject, decision.count, rule.limit,
        )
        raise HTTPException(
            status_code=429,
            detail=too_many_detail(rule, decision.retry_after),
            headers={"Retry-After": str(decision.retry_after)},
        )


# ---- 清理 -----------------------------------------------------------------------

def _expired(now: datetime):
    return RateLimitCounter.window_start < now - RETENTION


async def count_expired(session, now: datetime | None = None) -> int:
    return await session.scalar(
        select(func.count()).select_from(RateLimitCounter).where(_expired(now or utcnow()))
    )


async def cleanup(session, now: datetime | None = None) -> int:
    """分批删除过期窗口（每批 CLEANUP_BATCH_SIZE 行、单独提交），避免长时间锁表。"""
    now = now or utcnow()
    removed = 0
    while True:
        result = await session.execute(
            delete(RateLimitCounter).where(_expired(now)).with_dialect_options(mysql_limit=CLEANUP_BATCH_SIZE)
        )
        await session.commit()
        removed += result.rowcount
        if result.rowcount < CLEANUP_BATCH_SIZE:
            return removed
