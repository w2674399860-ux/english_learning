from datetime import datetime

from sqlalchemy import JSON, Boolean, CheckConstraint, FetchedValue, ForeignKey, Index, String, Text, text
from sqlalchemy.dialects.mysql import BIGINT, DATETIME
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base

DIFFICULTIES = ("beginner", "intermediate", "advanced")


class LearningRecord(Base):
    """学习记录。时间列存 UTC（不带时区的 DATETIME(3)），由数据库生成。

    user_id 可空：D-1 期间产生的无主测试记录保持为空，任何用户都看不到。
    新记录一律带 user_id，且所有查询都按 user_id 过滤（app/models/history.py）。
    """

    __tablename__ = "learning_records"
    __table_args__ = (
        CheckConstraint(
            "difficulty IN ('beginner', 'intermediate', 'advanced')", name="difficulty_valid"
        ),
        Index("idx_records_user_created", "user_id", "created_at", "id"),
        Index("idx_records_user_fav", "user_id", "is_favorite"),
        {"mysql_engine": "InnoDB", "mysql_charset": "utf8mb4", "mysql_collate": "utf8mb4_0900_ai_ci"},
    )
    # 插入 / 更新后取回数据库生成的 created_at、updated_at
    __mapper_args__ = {"eager_defaults": True}

    id: Mapped[int] = mapped_column(BIGINT(unsigned=True), primary_key=True, autoincrement=True)
    words: Mapped[list[str]] = mapped_column(JSON, nullable=False)
    difficulty: Mapped[str] = mapped_column(String(16), nullable=False, server_default="intermediate")
    english_story: Mapped[str] = mapped_column(Text, nullable=False)
    chinese_translation: Mapped[str] = mapped_column(Text, nullable=False)
    english_blank: Mapped[str] = mapped_column(Text, nullable=False)
    chinese_blank: Mapped[str] = mapped_column(Text, nullable=False)
    is_favorite: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("0"))
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    # 由前端上报：生成与保存是两次独立请求，服务端无法核实
    is_degraded: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("0"))
    image_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DATETIME(fsp=3), nullable=False, server_default=text("CURRENT_TIMESTAMP(3)")
    )
    updated_at: Mapped[datetime] = mapped_column(
        DATETIME(fsp=3),
        nullable=False,
        server_default=text("CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)"),
        server_onupdate=FetchedValue(),
    )
    user_id: Mapped[int | None] = mapped_column(
        BIGINT(unsigned=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=True
    )
