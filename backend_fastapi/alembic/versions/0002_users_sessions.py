"""users, sessions, learning_records.user_id

依据 docs/数据库设计方案.md 4.1、4.2、4.3 与 A-2 方案：
- users：用户名存小写，CHECK 约束保证格式
- sessions：只存凭证的 SHA-256（ascii_bin）
- learning_records.user_id：可空（D-1 期间的无主测试记录保持为空、不可见），外键级联删除
- 以 user_id 开头的联合索引取代 idx_records_created

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-07
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision: str = "0002"
down_revision: Union[str, None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

TABLE_OPTIONS = {"mysql_engine": "InnoDB", "mysql_charset": "utf8mb4", "mysql_collate": "utf8mb4_0900_ai_ci"}


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", mysql.BIGINT(unsigned=True), autoincrement=True, nullable=False),
        sa.Column("username", sa.String(20), nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("1"), nullable=False),
        sa.Column("password_changed_at", mysql.DATETIME(fsp=3), nullable=True),
        sa.Column("last_login_at", mysql.DATETIME(fsp=3), nullable=True),
        sa.Column(
            "created_at", mysql.DATETIME(fsp=3),
            server_default=sa.text("CURRENT_TIMESTAMP(3)"), nullable=False,
        ),
        sa.Column(
            "updated_at", mysql.DATETIME(fsp=3),
            server_default=sa.text("CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3)"), nullable=False,
        ),
        sa.PrimaryKeyConstraint("id", name="pk_users"),
        sa.UniqueConstraint("username", name="uk_users_username"),
        sa.CheckConstraint(
            "REGEXP_LIKE(username, '^[a-z0-9_]{3,20}$', 'c')", name="ck_users_username_format"
        ),
        **TABLE_OPTIONS,
    )

    op.create_table(
        "sessions",
        sa.Column("id", mysql.BIGINT(unsigned=True), autoincrement=True, nullable=False),
        sa.Column("user_id", mysql.BIGINT(unsigned=True), nullable=False),
        sa.Column("token_hash", mysql.CHAR(64, charset="ascii", collation="ascii_bin"), nullable=False),
        sa.Column("created_at", mysql.DATETIME(fsp=3), nullable=False),
        sa.Column("expires_at", mysql.DATETIME(fsp=3), nullable=False),
        sa.Column("revoked_at", mysql.DATETIME(fsp=3), nullable=True),
        sa.Column("last_used_at", mysql.DATETIME(fsp=3), nullable=True),
        sa.PrimaryKeyConstraint("id", name="pk_sessions"),
        sa.UniqueConstraint("token_hash", name="uk_sessions_token_hash"),
        **TABLE_OPTIONS,
    )
    # 先建索引再加外键：否则 MySQL 会为外键自动多建一个索引
    op.create_index("idx_sessions_user", "sessions", ["user_id"])
    op.create_index("idx_sessions_expires", "sessions", ["expires_at"])
    op.create_foreign_key(
        "fk_sessions_user_id_users", "sessions", "users", ["user_id"], ["id"], ondelete="CASCADE"
    )

    op.add_column("learning_records", sa.Column("user_id", mysql.BIGINT(unsigned=True), nullable=True))
    op.create_index("idx_records_user_created", "learning_records", ["user_id", "created_at", "id"])
    op.create_index("idx_records_user_fav", "learning_records", ["user_id", "is_favorite"])
    op.create_foreign_key(
        "fk_learning_records_user_id_users", "learning_records", "users",
        ["user_id"], ["id"], ondelete="CASCADE",
    )
    op.drop_index("idx_records_created", table_name="learning_records")


def downgrade() -> None:
    op.create_index("idx_records_created", "learning_records", ["created_at", "id"])
    op.drop_index("idx_records_user_fav", table_name="learning_records")
    op.drop_constraint("fk_learning_records_user_id_users", "learning_records", type_="foreignkey")
    op.drop_index("idx_records_user_created", table_name="learning_records")
    op.drop_column("learning_records", "user_id")
    op.drop_table("sessions")
    op.drop_table("users")
