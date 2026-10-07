"""Alembic 迁移环境（异步）。

目标库由 `-x target=dev|test` 选择（默认 dev），测试代码也可通过 config.attributes["target"] 指定：
- dev：settings.database_url
- test：settings.test_database_url，库名必须是 english_learning_test
两者都经过 check_database_url：拒绝连接本机 3306（本机 MySQL 8.0）。
"""
import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy.engine import Connection, make_url
from sqlalchemy.pool import NullPool

import app.models.learning_record  # noqa: F401  注册模型到 Base.metadata
import app.models.rate_limit  # noqa: F401
import app.models.user  # noqa: F401
from app.core.config import settings
from app.db.base import Base
from app.db.session import DatabaseConfigError, make_engine

config = context.config
if config.config_file_name is not None and not config.attributes.get("skip_logging_config"):
    fileConfig(config.config_file_name, disable_existing_loggers=False)

target_metadata = Base.metadata

TEST_DB_NAME = "english_learning_test"


def _database_url() -> str:
    target = config.attributes.get("target") or context.get_x_argument(as_dictionary=True).get("target", "dev")
    if target == "dev":
        return settings.database_url
    if target == "test":
        url = settings.test_database_url
        if not url:
            raise DatabaseConfigError("TEST_DATABASE_URL is not configured")
        if make_url(url).database != TEST_DB_NAME:
            raise DatabaseConfigError(f"test target must use database {TEST_DB_NAME!r}")
        return url
    raise DatabaseConfigError(f"unknown -x target={target!r} (use dev or test)")


def run_migrations_offline() -> None:
    raise DatabaseConfigError("offline (--sql) mode is not supported")


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    engine = make_engine(_database_url(), poolclass=NullPool)
    try:
        async with engine.connect() as connection:
            await connection.run_sync(do_run_migrations)
    finally:
        await engine.dispose()


def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
