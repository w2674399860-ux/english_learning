"""测试公共设施：配置隔离、测试库防护、断网、上游打桩、TestClient、数据库 fixture。

导入顺序很重要：必须先写环境变量、再导入任何 app 模块。
"""
import asyncio
import io
import os
import socket
import sys
from pathlib import Path

import httpx
import pytest
from dotenv import dotenv_values
from sqlalchemy.engine import make_url

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

# ---------------------------------------------------------------------------
# 1. 测试库：只认 TEST_DATABASE_URL（进程环境变量优先，其次 backend_fastapi/.env 中这一个键）。
#    库名必须是 english_learning_test，且不能指向本机 3306（本机 MySQL 8.0）。
#    不满足时整轮测试中止；未配置时数据库测试跳过，其余测试照常运行。
# ---------------------------------------------------------------------------
TEST_DB_NAME = "english_learning_test"
TEST_DATABASE_URL = (
    os.environ.get("TEST_DATABASE_URL")
    or dotenv_values(BACKEND_DIR / ".env").get("TEST_DATABASE_URL")
    or ""
)


def _check_test_db_url(url: str) -> str | None:
    """返回拒绝原因；安全时返回 None。错误信息里不带密码。"""
    parsed = make_url(url)
    if parsed.database != TEST_DB_NAME:
        return f"database must be {TEST_DB_NAME!r}, got {parsed.database!r}"
    if parsed.host in ("localhost", "127.0.0.1", "::1") and parsed.port in (None, 3306):
        return "refusing to use local port 3306 (or no port): that is the host MySQL 8.0"
    return None


if TEST_DATABASE_URL:
    _reason = _check_test_db_url(TEST_DATABASE_URL)
    if _reason:
        pytest.exit(f"unsafe TEST_DATABASE_URL: {_reason}", returncode=4)

# ---------------------------------------------------------------------------
# 2. 配置隔离：pydantic-settings 中进程环境变量优先于 .env，
#    把 Settings 的全部字段写成测试值，测试结果不取决于本机 .env，真实 Key 也进不来。
#    DATABASE_URL 也指向测试库：即使某段代码误用它，连到的也只是测试库。
# ---------------------------------------------------------------------------
TEST_API_KEY = "test-key-not-real"
DEEPSEEK_BASE = "https://deepseek.test"
OCR_BASE = "http://ocr.test"

os.environ.update({
    "DEEPSEEK_API_KEY": TEST_API_KEY,
    "DEEPSEEK_API_BASE": DEEPSEEK_BASE,
    "AI_FALLBACK_ENABLED": "false",
    "DATABASE_URL": TEST_DATABASE_URL,
    "TEST_DATABASE_URL": TEST_DATABASE_URL,
    "SERVER_HOST": "127.0.0.1",
    "SERVER_PORT": "8000",
    "DEBUG": "false",
    "OCR_SERVICE_URL": OCR_BASE,
    "OCR_MODE": "docker",
    "FRONTEND_URL": "http://localhost:3000",
    "SESSION_TTL_DAYS": "30",
    # 测试中开启接口文档（S-1 测试要访问 /docs）；关闭会话定时清理，避免后台任务干扰测试库
    "API_DOCS_ENABLED": "true",
    "SESSION_CLEANUP_ENABLED": "false",
    # 限流默认关闭：不连库的测试不能因为计数去访问数据库。S-5 的测试用 fixture 打开并收紧额度；
    # 路由是否挂了限流依赖由 tests/unit/test_ratelimit_rules.py 清点，关掉开关也藏不住漏挂
    "RATE_LIMIT_ENABLED": "false",
})

import app.api.learn as learn_api  # noqa: E402
import app.api.ocr as ocr_api  # noqa: E402
import app.auth.passwords as passwords  # noqa: E402
from app.auth.dependencies import CurrentUser, get_current_user  # noqa: E402
from app.core.config import settings  # noqa: E402
from app.services.ai_service import AIService  # noqa: E402
from app.services.learn_service import LearnService  # noqa: E402
from app.services.ocr_service import OCRService  # noqa: E402
from main import app as fastapi_app  # noqa: E402

_RealAsyncClient = httpx.AsyncClient


# ---------------------------------------------------------------------------
# 3. 断网
# ---------------------------------------------------------------------------
@pytest.fixture(autouse=True)
def _block_sockets(monkeypatch):
    """兜底：任何绕过 httpx 打桩的真实连接（含 DNS）都直接失败。

    例外只有两个：
    - Windows 上 asyncio 事件循环用 socket.socketpair() 建自唤醒管道，其实现是在 127.0.0.1 上自连
      （3.13 中函数名为 _fallback_socketpair）。只放行调用方正是这个函数的那一次 connect。
    - 测试库（TEST_DATABASE_URL 的主机与端口，已在上面校验过不是本机 3306）。
    """
    real_connect = socket.socket.connect
    real_getaddrinfo = socket.getaddrinfo
    socketpair_impls = {"socketpair", "_fallback_socketpair"}
    allowed = set()
    if TEST_DATABASE_URL:
        parsed = make_url(TEST_DATABASE_URL)
        allowed.add((parsed.host, parsed.port))

    def guarded_connect(self, address):
        if sys._getframe(1).f_code.co_name in socketpair_impls or tuple(address[:2]) in allowed:
            return real_connect(self, address)
        raise RuntimeError(f"tests must not open network connections: {address!r}")

    def guarded_getaddrinfo(host, port, *args, **kwargs):
        if (host, port) in allowed:
            return real_getaddrinfo(host, port, *args, **kwargs)
        raise RuntimeError(f"tests must not open network connections: {(host, port)!r}")

    def guard(*args, **kwargs):
        raise RuntimeError(f"tests must not open network connections: {args!r}")

    monkeypatch.setattr(socket.socket, "connect", guarded_connect)
    monkeypatch.setattr(socket.socket, "connect_ex", guard)
    monkeypatch.setattr(socket, "getaddrinfo", guarded_getaddrinfo)


class Upstream:
    """模拟 DeepSeek 与 OCR 上游。按主机名分派，记录收到的请求。

    处理函数可以返回 httpx.Response，或抛出 httpx 异常（模拟超时、连不上等）。
    """

    def __init__(self):
        self.handlers = {}
        self.requests: list[httpx.Request] = []

    def on(self, base_url: str, handler):
        self.handlers[httpx.URL(base_url).host] = handler

    def calls(self, base_url: str) -> list[httpx.Request]:
        host = httpx.URL(base_url).host
        return [r for r in self.requests if r.url.host == host]

    def dispatch(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        handler = self.handlers.get(request.url.host)
        if handler is None:
            pytest.fail(f"unexpected outbound request: {request.method} {request.url}")
        return handler(request)


@pytest.fixture(autouse=True)
def upstream(monkeypatch) -> Upstream:
    """所有 httpx.AsyncClient 强制走 MockTransport；未设置处理函数的请求让测试失败。

    TestClient 用的是同步 httpx.Client，不受影响。
    """
    up = Upstream()
    transport = httpx.MockTransport(up.dispatch)

    class _MockedAsyncClient(_RealAsyncClient):
        def __init__(self, *args, **kwargs):
            kwargs["transport"] = transport
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(httpx, "AsyncClient", _MockedAsyncClient)
    return up


# ---------------------------------------------------------------------------
# 4. 上游响应构造
# ---------------------------------------------------------------------------
def deepseek_reply(content: str) -> httpx.Response:
    """DeepSeek chat/completions 的正常响应外层，content 是模型输出文本。"""
    return httpx.Response(200, json={"choices": [{"message": {"content": content}}]})


def raiser(exc_type, message: str = "simulated"):
    """返回一个抛出指定 httpx 异常的处理函数。"""

    def handler(request: httpx.Request):
        raise exc_type(message, request=request)

    return handler


def tiny_png() -> bytes:
    from PIL import Image

    buf = io.BytesIO()
    Image.new("RGB", (8, 8), "white").save(buf, format="PNG")
    return buf.getvalue()


# ---------------------------------------------------------------------------
# 5. 配置覆盖：修改 settings 后新建 Service；monkeypatch 在测试结束时自动还原。
# ---------------------------------------------------------------------------
@pytest.fixture
def make_ai_service(monkeypatch):
    def factory(*, fallback: bool = False, api_key: str = TEST_API_KEY) -> AIService:
        monkeypatch.setattr(settings, "ai_fallback_enabled", fallback)
        monkeypatch.setattr(settings, "deepseek_api_key", api_key)
        return AIService()

    return factory


@pytest.fixture
def make_ocr_service(monkeypatch):
    def factory(mode: str) -> OCRService:
        monkeypatch.setattr(settings, "ocr_mode", mode)
        return OCRService()

    return factory


FAKE_USER = CurrentUser(id=424242, username="fake_user", session_id=1)


@pytest.fixture
def client():
    """不连数据库的 TestClient：鉴权依赖替换为固定的假用户。

    只给测试 OCR / 生成 / 静态路由等与账号无关的行为使用；鉴权本身在 test_auth_* 中连测试库测试。
    """
    from fastapi.testclient import TestClient

    from app.db.session import get_session

    async def no_database():
        # 限流依赖需要会话参数；限流关闭时不会使用它，这里不创建 engine
        yield None

    fastapi_app.dependency_overrides[get_current_user] = lambda: FAKE_USER
    fastapi_app.dependency_overrides[get_session] = no_database
    try:
        with TestClient(fastapi_app) as c:
            yield c
    finally:
        fastapi_app.dependency_overrides.pop(get_current_user, None)
        fastapi_app.dependency_overrides.pop(get_session, None)


@pytest.fixture(autouse=True)
def _cheap_password_hasher(monkeypatch):
    """测试中用低成本参数，保持速度；生产参数由 test_auth_rules 单独断言。"""
    from argon2 import PasswordHasher

    monkeypatch.setattr(passwords, "password_hasher", PasswordHasher(time_cost=1, memory_cost=1024, parallelism=1))


@pytest.fixture
def use_ai(monkeypatch, make_ai_service):
    """替换 /learn/compose 路由持有的单例。"""

    def apply(**kwargs) -> AIService:
        service = make_ai_service(**kwargs)
        monkeypatch.setattr(learn_api, "learn_service", LearnService(service))
        return service

    return apply


@pytest.fixture
def use_ocr(monkeypatch, make_ocr_service):
    """替换 /ocr/recognize 路由持有的单例。"""

    def apply(mode: str) -> OCRService:
        service = make_ocr_service(mode)
        monkeypatch.setattr(ocr_api, "ocr_service", service)
        return service

    return apply


# ---------------------------------------------------------------------------
# 6. 数据库（只连测试库）
#    - 每轮测试开始时用 Alembic 把测试库升级到 head（顺带测了迁移脚本本身）
#    - engine 用 NullPool：TestClient 在另一个线程跑自己的事件循环，连接不能跨事件循环复用；
#      NullPool 不保留连接，就不会出现共用
#    - 每个测试开始前清空业务表，测试之间互不影响
# ---------------------------------------------------------------------------
# 按外键依赖的反方向清空
DATA_TABLES = ("learning_records", "sessions", "users", "rate_limit_counters")
_NO_AUTO_INCREMENT = {"rate_limit_counters"}
DEFAULT_PASSWORD = "river-stone-42"


def alembic_config():
    from alembic.config import Config

    cfg = Config(str(BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(BACKEND_DIR / "alembic"))
    cfg.attributes["target"] = "test"
    cfg.attributes["skip_logging_config"] = True  # 不让 alembic 改写 pytest 的日志处理器
    return cfg


def make_test_engine():
    from sqlalchemy.pool import NullPool

    from app.db.session import make_engine

    return make_engine(TEST_DATABASE_URL, poolclass=NullPool)


async def _truncate(engine):
    from sqlalchemy import text

    async with engine.begin() as conn:
        for table in DATA_TABLES:
            await conn.execute(text(f"DELETE FROM {table}"))
            if table not in _NO_AUTO_INCREMENT:
                await conn.execute(text(f"ALTER TABLE {table} AUTO_INCREMENT = 1"))


@pytest.fixture(scope="session")
def migrated_test_db():
    if not TEST_DATABASE_URL:
        pytest.skip("TEST_DATABASE_URL 未配置，跳过数据库测试（见 backend_fastapi/.env.example）")
    from alembic import command

    command.upgrade(alembic_config(), "head")
    return TEST_DATABASE_URL


@pytest.fixture
def clean_db(migrated_test_db):
    """同步 fixture：在任何事件循环之外清空业务表。"""
    engine = make_test_engine()

    async def run():
        await _truncate(engine)
        await engine.dispose()

    asyncio.run(run())
    return migrated_test_db


@pytest.fixture
async def db_engine(clean_db):
    engine = make_test_engine()
    yield engine
    await engine.dispose()


@pytest.fixture
async def db_session(db_engine):
    from sqlalchemy.ext.asyncio import async_sessionmaker

    async with async_sessionmaker(db_engine, expire_on_commit=False)() as session:
        yield session


@pytest.fixture
def db_client(clean_db):
    """接上测试库的 TestClient：替换 get_session 依赖项。"""
    from fastapi.testclient import TestClient
    from sqlalchemy.ext.asyncio import async_sessionmaker

    from app.db.session import get_session

    engine = make_test_engine()
    sessionmaker = async_sessionmaker(engine, expire_on_commit=False)

    async def override():
        async with sessionmaker() as session:
            yield session

    fastapi_app.dependency_overrides[get_session] = override
    try:
        with TestClient(fastapi_app) as c:
            yield c
    finally:
        fastapi_app.dependency_overrides.pop(get_session, None)
        asyncio.run(engine.dispose())


def bearer(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def register(client, username: str, password: str = DEFAULT_PASSWORD) -> dict:
    """注册并返回响应体（含 token 与 user）。"""
    resp = client.post("/api/v1/auth/register", json={"username": username, "password": password})
    assert resp.status_code == 201, resp.text
    return resp.json()


@pytest.fixture
def alice_client(db_client):
    """已登录为 alice 的 TestClient（真实鉴权，连测试库）。"""
    body = register(db_client, "alice")
    db_client.headers.update(bearer(body["token"]))
    db_client.user = body["user"]
    return db_client


async def insert_user(session, username: str) -> int:
    """直接在库里建用户（模型层测试用，不走接口）。"""
    from app.models.user import User

    user = User(username=username, password_hash="not-a-real-hash")
    session.add(user)
    await session.commit()
    return user.id
