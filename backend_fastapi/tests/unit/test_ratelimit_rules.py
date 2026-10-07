"""S-5 限流（不连数据库）：窗口计算、文案、客户端 IP、计数 SQL、配置、路由挂载。"""
from datetime import datetime
from types import SimpleNamespace

import pytest
from fastapi.routing import APIRoute
from pydantic import ValidationError
from sqlalchemy.dialects import mysql
from sqlalchemy.exc import OperationalError

from app.core.config import Settings, settings
from app.ratelimit import limiter
from main import app

# ---- 窗口（统一 UTC，按纪元对齐） ----------------------------------------------


@pytest.mark.parametrize("now, window, start, retry_after", [
    (datetime(2026, 10, 7, 12, 0, 30), 60, datetime(2026, 10, 7, 12, 0), 30),
    (datetime(2026, 10, 7, 12, 7, 0, 500_000), 600, datetime(2026, 10, 7, 12, 0), 180),
    (datetime(2026, 10, 7, 12, 59, 59), 3600, datetime(2026, 10, 7, 12, 0), 1),
    (datetime(2026, 10, 7, 12, 0, 30), 86400, datetime(2026, 10, 7, 0, 0), 43170),
    # 窗口起点本身属于新窗口，等待整个窗口
    (datetime(2026, 10, 7, 0, 0, 0), 86400, datetime(2026, 10, 7, 0, 0), 86400),
    # 不足 1 秒向上取整，至少 1
    (datetime(2026, 10, 7, 12, 0, 59, 900_000), 60, datetime(2026, 10, 7, 12, 0), 1),
])
def test_window_of(now, window, start, retry_after):
    assert limiter.window_of(now, window) == (start, retry_after)


# ---- 文案 ---------------------------------------------------------------------

@pytest.mark.parametrize("seconds, text", [
    (1, "1 分钟"), (59, "1 分钟"), (60, "1 分钟"), (61, "2 分钟"), (480, "8 分钟"),
    (3599, "60 分钟"), (3600, "约 1 小时"), (43170, "约 12 小时"), (86400, "约 24 小时"),
])
def test_format_wait(seconds, text):
    assert limiter.format_wait(seconds) == text


@pytest.mark.parametrize("window, text", [
    (86400, "每天"), (3600, "每小时"), (600, "每 10 分钟"), (60, "每分钟"), (7200, "每 2 小时"), (90, "每 90 秒"),
])
def test_period_text(window, text):
    assert limiter.period_text(window) == text


@pytest.mark.parametrize("scope, retry_after, detail", [
    ("ocr", 10800, "识别次数已用完（每天 60 次），请约 3 小时后再试"),
    ("compose", 10800, "生成次数已用完（每天 30 次），请约 3 小时后再试"),
    ("login", 480, "登录尝试过于频繁（每 10 分钟 10 次），请 8 分钟后再试"),
    ("register", 2400, "注册过于频繁（每小时 5 次），请 40 分钟后再试"),
])
def test_too_many_detail_uses_defaults(scope, retry_after, detail):
    assert limiter.too_many_detail(limiter.get_rule(scope), retry_after) == detail


def test_detail_follows_configured_quota(monkeypatch):
    monkeypatch.setattr(settings, "rate_limit_compose_per_user", 2)
    monkeypatch.setattr(settings, "rate_limit_compose_window_seconds", 60)
    rule = limiter.get_rule("compose")
    assert (rule.limit, rule.window_seconds) == (2, 60)
    assert limiter.too_many_detail(rule, 30) == "生成次数已用完（每分钟 2 次），请 1 分钟后再试"


# ---- 客户端 IP：只取连接地址，IPv6 归并到 /64 -----------------------------------

def _request(host, headers=()):
    return SimpleNamespace(client=SimpleNamespace(host=host) if host is not None else None, headers=dict(headers))


@pytest.mark.parametrize("host, subject", [
    ("203.0.113.7", "ip:203.0.113.7"),
    ("2001:db8:1:2:aaaa:bbbb:cccc:dddd", "ip:2001:db8:1:2::/64"),
    ("2001:DB8:1:2::1", "ip:2001:db8:1:2::/64"),
    ("::ffff:203.0.113.7", "ip:203.0.113.7"),
    ("::1", "ip:::/64"),
    ("testclient", "ip:unknown"),
    (None, "ip:unknown"),
])
def test_ip_subject(host, subject):
    assert limiter.ip_subject(_request(host)) == subject


def test_ip_subject_ignores_forwarded_headers():
    request = _request("203.0.113.7", {"x-forwarded-for": "198.51.100.1", "x-real-ip": "198.51.100.2"})
    assert limiter.ip_subject(request) == "ip:203.0.113.7"


def test_subjects_fit_column():
    longest = limiter.ip_subject(_request("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"))
    assert len(longest) <= 64
    assert limiter.user_subject(18446744073709551615) == "u:18446744073709551615"


# ---- 计数 SQL ------------------------------------------------------------------

def test_upsert_sql_does_not_use_values_function():
    stmt = limiter.counter_upsert("ocr", "u:1", datetime(2026, 10, 7))
    sql = str(stmt.compile(dialect=mysql.dialect())).replace("\n", " ")
    update_clause = sql.split("ON DUPLICATE KEY UPDATE", 1)[1]
    assert "VALUES(" not in update_clause.upper().replace(" ", "")
    assert "count = (rate_limit_counters.count + %s)" in update_clause or \
        "count = rate_limit_counters.count + %s" in update_clause
    # 参数绑定：值不出现在 SQL 文本中
    assert "u:1" not in sql


class _FakeSession:
    """第一次 execute 抛出指定错误码的 OperationalError，之后正常。"""

    def __init__(self, errno, failures=1):
        self.errno, self.failures = errno, failures
        self.executes = self.rollbacks = self.commits = 0

    async def execute(self, stmt):
        self.executes += 1
        if self.failures:
            self.failures -= 1
            raise OperationalError("INSERT ...", {}, Exception(self.errno, "simulated"))

    async def scalar(self, stmt):
        return 1

    async def commit(self):
        self.commits += 1

    async def rollback(self):
        self.rollbacks += 1


@pytest.mark.parametrize("errno", [1213, 1205])
async def test_hit_retries_on_deadlock_or_lock_timeout(errno):
    session = _FakeSession(errno)
    decision = await limiter.hit(session, limiter.Rule("ocr", 5, 60), "u:1", now=datetime(2026, 10, 7))
    assert decision.allowed and decision.count == 1
    assert (session.executes, session.rollbacks, session.commits) == (2, 1, 1)


async def test_hit_gives_up_after_max_attempts():
    session = _FakeSession(1213, failures=99)
    with pytest.raises(OperationalError):
        await limiter.hit(session, limiter.Rule("ocr", 5, 60), "u:1", now=datetime(2026, 10, 7))
    assert session.executes == limiter.MAX_ATTEMPTS


async def test_hit_does_not_retry_other_errors():
    session = _FakeSession(1045)
    with pytest.raises(OperationalError):
        await limiter.hit(session, limiter.Rule("ocr", 5, 60), "u:1", now=datetime(2026, 10, 7))
    assert session.executes == 1


async def test_disabled_limiter_does_not_touch_database(monkeypatch):
    monkeypatch.setattr(settings, "rate_limit_enabled", False)
    await limiter.enforce(None, "ocr", "u:1")  # session 为 None 也不报错


# ---- 配置 ----------------------------------------------------------------------

def test_defaults_match_claude_md():
    fields = Settings.model_fields
    assert fields["rate_limit_enabled"].default is True
    assert {k: fields[k].default for k in (
        "rate_limit_ocr_per_user", "rate_limit_ocr_window_seconds",
        "rate_limit_compose_per_user", "rate_limit_compose_window_seconds",
        "rate_limit_login_per_ip", "rate_limit_login_window_seconds",
        "rate_limit_register_per_ip", "rate_limit_register_window_seconds",
        "compose_max_words", "compose_max_word_length",
        "max_upload_bytes", "max_request_bytes", "history_max_page_size",
    )} == {
        "rate_limit_ocr_per_user": 60, "rate_limit_ocr_window_seconds": 86400,
        "rate_limit_compose_per_user": 30, "rate_limit_compose_window_seconds": 86400,
        "rate_limit_login_per_ip": 10, "rate_limit_login_window_seconds": 600,
        "rate_limit_register_per_ip": 5, "rate_limit_register_window_seconds": 3600,
        "compose_max_words": 20, "compose_max_word_length": 40,
        "max_upload_bytes": 10 * 1024 * 1024, "max_request_bytes": 1024 * 1024, "history_max_page_size": 50,
    }


@pytest.mark.parametrize("key, value", [
    ("rate_limit_ocr_window_seconds", 86401),  # 窗口超过 1 天会被 2 天保留期的清理误删
    ("rate_limit_login_window_seconds", 0),
    ("rate_limit_compose_per_user", 0),
    ("max_upload_bytes", 0),
    ("history_max_page_size", 0),
])
def test_invalid_limits_are_rejected(key, value):
    with pytest.raises(ValidationError):
        Settings(**{key: value})


def test_retention_covers_longest_window():
    assert limiter.RETENTION.total_seconds() >= 2 * 86400


# ---- 路由挂载 -------------------------------------------------------------------

EXPECTED_LIMITS = {
    ("POST", "/api/v1/ocr/recognize"): ("ocr", "user"),
    ("POST", "/api/v1/learn/compose"): ("compose", "user"),
    ("POST", "/api/v1/auth/login"): ("login", "ip"),
    ("POST", "/api/v1/auth/register"): ("register", "ip"),
}


def _limits_of(dependant):
    found = []
    for dep in dependant.dependencies:
        scope = getattr(dep.call, "rate_limit_scope", None)
        if scope:
            found.append((scope, dep.call.rate_limit_kind))
        found.extend(_limits_of(dep))
    return found


def test_rate_limits_are_attached_to_exactly_the_expected_routes():
    actual = {}
    for route in app.routes:
        if isinstance(route, APIRoute):
            for method in route.methods:
                limits = _limits_of(route.dependant)
                if limits:
                    actual[(method, route.path)] = limits
    assert actual == {k: [v] for k, v in EXPECTED_LIMITS.items()}


def test_uvicorn_does_not_trust_proxy_headers(monkeypatch):
    import main

    captured = {}
    monkeypatch.setattr(main.uvicorn, "run", lambda *a, **kw: captured.update(kw))
    main.run()
    assert captured["proxy_headers"] is False
