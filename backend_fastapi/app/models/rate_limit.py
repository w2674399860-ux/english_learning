from datetime import datetime

from sqlalchemy import Index, text
from sqlalchemy.dialects.mysql import DATETIME, INTEGER, VARCHAR
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base

_TABLE_OPTIONS = {"mysql_engine": "InnoDB", "mysql_charset": "utf8mb4", "mysql_collate": "utf8mb4_0900_ai_ci"}
# scope 与 subject 只含 ASCII（动作名、u:<id>、ip:<地址>），用 ascii_bin：主键更短、按字节比较
_ASCII = {"charset": "ascii", "collation": "ascii_bin"}


class RateLimitCounter(Base):
    """限流计数（docs/数据库设计方案.md 4.4）。不设外键；IP 属于个人信息，过期窗口保留不超过 2 天。

    window_start 是 UTC 时间窗口起点，由应用按窗口长度对齐后写入（app/ratelimit/limiter.py）。
    """

    __tablename__ = "rate_limit_counters"
    __table_args__ = (Index("idx_rl_window", "window_start"), _TABLE_OPTIONS)

    scope: Mapped[str] = mapped_column(VARCHAR(32, **_ASCII), primary_key=True)
    subject: Mapped[str] = mapped_column(VARCHAR(64, **_ASCII), primary_key=True)
    window_start: Mapped[datetime] = mapped_column(DATETIME(), primary_key=True)
    count: Mapped[int] = mapped_column(INTEGER(unsigned=True), nullable=False, server_default=text("0"))
