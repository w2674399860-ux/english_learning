from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, FetchedValue, ForeignKey, Index, String, UniqueConstraint, text
from sqlalchemy.dialects.mysql import BIGINT, CHAR, DATETIME
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base

_TABLE_OPTIONS = {"mysql_engine": "InnoDB", "mysql_charset": "utf8mb4", "mysql_collate": "utf8mb4_0900_ai_ci"}


class User(Base):
    """用户（docs/数据库设计方案.md 4.1）。用户名统一存小写。"""

    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("username", name="uk_users_username"),
        # 'c'：区分大小写匹配（列的排序规则不区分大小写，普通 REGEXP 会放过大写字母）
        CheckConstraint("REGEXP_LIKE(username, '^[a-z0-9_]{3,20}$', 'c')", name="username_format"),
        _TABLE_OPTIONS,
    )
    __mapper_args__ = {"eager_defaults": True}

    id: Mapped[int] = mapped_column(BIGINT(unsigned=True), primary_key=True, autoincrement=True)
    username: Mapped[str] = mapped_column(String(20), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("1"))
    password_changed_at: Mapped[datetime | None] = mapped_column(DATETIME(fsp=3), nullable=True)
    last_login_at: Mapped[datetime | None] = mapped_column(DATETIME(fsp=3), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DATETIME(fsp=3), nullable=False, server_default=text("CURRENT_TIMESTAMP(3)")
    )
    updated_at: Mapped[datetime] = mapped_column(
        DATETIME(fsp=3),
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)"),
        server_onupdate=FetchedValue(),
    )


class UserSession(Base):
    """登录会话（docs/数据库设计方案.md 4.2）。只存凭证的 SHA-256，凭证原文只发给客户端。

    时间列由应用写入（与 users.password_changed_at 同一时钟来源，避免容器与主机时钟偏差）。
    """

    __tablename__ = "sessions"
    __table_args__ = (
        UniqueConstraint("token_hash", name="uk_sessions_token_hash"),
        Index("idx_sessions_user", "user_id"),
        Index("idx_sessions_expires", "expires_at"),
        _TABLE_OPTIONS,
    )

    id: Mapped[int] = mapped_column(BIGINT(unsigned=True), primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BIGINT(unsigned=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    token_hash: Mapped[str] = mapped_column(CHAR(64, charset="ascii", collation="ascii_bin"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DATETIME(fsp=3), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DATETIME(fsp=3), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DATETIME(fsp=3), nullable=True)
    last_used_at: Mapped[datetime | None] = mapped_column(DATETIME(fsp=3), nullable=True)
