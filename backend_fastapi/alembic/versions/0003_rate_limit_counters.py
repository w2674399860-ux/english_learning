"""rate_limit_counters

依据 docs/数据库设计方案.md 4.4 与 S-5 方案：
- 主键 (scope, subject, window_start)，计数用 INSERT ... ON DUPLICATE KEY UPDATE count = count + 1
- scope / subject 只含 ASCII，用 ascii_bin
- 不设外键；idx_rl_window 用于清理过期窗口

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-07
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE_OPTIONS = {"mysql_engine": "InnoDB", "mysql_charset": "utf8mb4", "mysql_collate": "utf8mb4_0900_ai_ci"}


def upgrade() -> None:
    op.create_table(
        "rate_limit_counters",
        sa.Column("scope", mysql.VARCHAR(32, charset="ascii", collation="ascii_bin"), nullable=False),
        sa.Column("subject", mysql.VARCHAR(64, charset="ascii", collation="ascii_bin"), nullable=False),
        sa.Column("window_start", mysql.DATETIME(), nullable=False),
        sa.Column("count", mysql.INTEGER(unsigned=True), server_default=sa.text("0"), nullable=False),
        sa.PrimaryKeyConstraint("scope", "subject", "window_start", name="pk_rate_limit_counters"),
        **TABLE_OPTIONS,
    )
    op.create_index("idx_rl_window", "rate_limit_counters", ["window_start"])


def downgrade() -> None:
    op.drop_table("rate_limit_counters")
