"""create learning_records

依据 docs/数据库设计方案.md 4.3。user_id 在 A-2 的迁移中再加。

Revision ID: 0001
Revises:
Create Date: 2026-10-07
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "learning_records",
        sa.Column("id", mysql.BIGINT(unsigned=True), autoincrement=True, nullable=False),
        sa.Column("words", sa.JSON(), nullable=False),
        sa.Column("difficulty", sa.String(16), server_default="intermediate", nullable=False),
        sa.Column("english_story", sa.Text(), nullable=False),
        sa.Column("chinese_translation", sa.Text(), nullable=False),
        sa.Column("english_blank", sa.Text(), nullable=False),
        sa.Column("chinese_blank", sa.Text(), nullable=False),
        sa.Column("is_favorite", sa.Boolean(), server_default=sa.text("0"), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("is_degraded", sa.Boolean(), server_default=sa.text("0"), nullable=False),
        sa.Column("image_name", sa.String(255), nullable=True),
        sa.Column(
            "created_at", mysql.DATETIME(fsp=3),
            server_default=sa.text("CURRENT_TIMESTAMP(3)"), nullable=False,
        ),
        sa.Column(
            "updated_at", mysql.DATETIME(fsp=3),
            server_default=sa.text("CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)"), nullable=False,
        ),
        sa.PrimaryKeyConstraint("id", name="pk_learning_records"),
        sa.CheckConstraint(
            "difficulty IN ('beginner', 'intermediate', 'advanced')",
            name="ck_learning_records_difficulty_valid",
        ),
        mysql_engine="InnoDB",
        mysql_charset="utf8mb4",
        mysql_collate="utf8mb4_0900_ai_ci",
    )
    op.create_index("idx_records_created", "learning_records", ["created_at", "id"])


def downgrade() -> None:
    op.drop_index("idx_records_created", table_name="learning_records")
    op.drop_table("learning_records")
