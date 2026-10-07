from datetime import datetime, timezone
from pydantic import BaseModel
from typing import Optional


def utcnow() -> datetime:
    """当前 UTC 时间，不带时区（与数据库 DATETIME(3) 列一致），精确到毫秒。"""
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    return now.replace(microsecond=now.microsecond // 1000 * 1000)


def to_utc_iso(value: datetime) -> str:
    """数据库存的是不带时区的 UTC 时间；输出 ISO 8601 并带 Z，如 2026-10-07T03:47:00.123Z。"""
    return value.replace(tzinfo=timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


class DegradableResponse(BaseModel):
    """降级标记：开发环境下服务不可用、回落 mock 时 degraded 为 true，reason 说明原因。
    未降级时 degraded 为 false、reason 为 null，两个字段始终返回。"""

    degraded: bool = False
    reason: Optional[str] = None
