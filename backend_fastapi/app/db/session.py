"""数据库连接：engine 懒创建、会话依赖项、连接安全检查。"""
from collections.abc import AsyncIterator

from sqlalchemy import event
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import settings

# 本机已装的 MySQL 8.0 占用 3306，开发与测试一律走 Docker 中 MySQL 8.4 的 3307
_LOCAL_HOSTS = {"localhost", "127.0.0.1", "::1"}


class DatabaseConfigError(RuntimeError):
    pass


def check_database_url(url: str) -> None:
    """连接本机时必须显式指定端口且不是 3306。错误信息不含密码。

    容器内（E-2）通过服务名访问 3306 不受影响。
    """
    if not url:
        raise DatabaseConfigError("DATABASE_URL is not configured (see backend_fastapi/.env.example)")
    parsed = make_url(url)
    if parsed.host in _LOCAL_HOSTS and parsed.port in (None, 3306):
        raise DatabaseConfigError(
            f"refusing to connect to {parsed.host}:{parsed.port or 3306}: "
            "local port 3306 is the host MySQL 8.0; use the Docker MySQL on 3307"
        )


def _set_utc(dbapi_connection, connection_record):
    # 服务器已设 --default-time-zone=+00:00；这里按连接再设一次，生产库时区不同也不受影响
    cursor = dbapi_connection.cursor()
    cursor.execute("SET time_zone = '+00:00'")
    cursor.close()


def make_engine(url: str, **kwargs) -> AsyncEngine:
    check_database_url(url)
    # hide_parameters：数据库报错信息中不带 SQL 参数（可能含密码哈希、凭证哈希与用户内容）
    options = {"pool_pre_ping": True, "hide_parameters": True}
    if "poolclass" not in kwargs:
        # pool_recycle 小于 MySQL 默认 wait_timeout（28800 秒）
        options.update(pool_recycle=1800, pool_size=5, max_overflow=10)
    options.update(kwargs)
    engine = create_async_engine(url, **options)
    event.listen(engine.sync_engine, "connect", _set_utc)
    return engine


_engine: AsyncEngine | None = None
_sessionmaker: async_sessionmaker[AsyncSession] | None = None


def get_engine() -> AsyncEngine:
    global _engine, _sessionmaker
    if _engine is None:
        _engine = make_engine(settings.database_url)
        _sessionmaker = async_sessionmaker(_engine, expire_on_commit=False)
    return _engine


async def get_session() -> AsyncIterator[AsyncSession]:
    """FastAPI 依赖项：每个请求一个会话。"""
    get_engine()
    async with _sessionmaker() as session:
        yield session


async def dispose_engine() -> None:
    global _engine, _sessionmaker
    if _engine is not None:
        await _engine.dispose()
        _engine = None
        _sessionmaker = None
