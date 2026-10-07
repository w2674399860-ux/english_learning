"""测试公共设施：配置隔离、断网、上游打桩、TestClient。

导入顺序很重要：必须先写环境变量、再导入任何 app 模块。
"""
import io
import os
import socket
import sys
import tempfile
from pathlib import Path

import httpx
import pytest

# ---------------------------------------------------------------------------
# 1. 配置隔离：pydantic-settings 中进程环境变量优先于 .env，
#    把 Settings 的全部字段写成测试值，测试结果不取决于本机 .env，真实 Key 也进不来。
# ---------------------------------------------------------------------------
TEST_API_KEY = "test-key-not-real"
DEEPSEEK_BASE = "https://deepseek.test"
OCR_BASE = "http://ocr.test"

os.environ.update({
    "DEEPSEEK_API_KEY": TEST_API_KEY,
    "DEEPSEEK_API_BASE": DEEPSEEK_BASE,
    "AI_FALLBACK_ENABLED": "false",
    "DATABASE_URL": "sqlite:///./unused-in-tests.db",
    "SERVER_HOST": "127.0.0.1",
    "SERVER_PORT": "8000",
    "DEBUG": "false",
    "OCR_SERVICE_URL": OCR_BASE,
    "OCR_MODE": "docker",
    "FRONTEND_URL": "http://localhost:3000",
})

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

# ---------------------------------------------------------------------------
# 2. 导入 main 会连带执行 app/api/history.py 的模块级 HistoryModel()，
#    它会打开并建表。先把数据库路径改到临时目录，避免碰开发库。
# ---------------------------------------------------------------------------
import app.models.history as _history_model  # noqa: E402

_TMP_DB_DIR = tempfile.mkdtemp(prefix="e3a-tests-")
_history_model.DB_DIR = _TMP_DB_DIR
_history_model.DB_PATH = os.path.join(_TMP_DB_DIR, "unused.db")

import app.api.learn as learn_api  # noqa: E402
import app.api.ocr as ocr_api  # noqa: E402
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

    唯一例外：Windows 上 asyncio 事件循环用 socket.socketpair() 建自唤醒管道，
    其实现是在 127.0.0.1 上自连（3.13 中函数名为 _fallback_socketpair）。
    只放行调用方正是这个函数的那一次 connect。
    """
    real_connect = socket.socket.connect
    socketpair_impls = {"socketpair", "_fallback_socketpair"}

    def guarded_connect(self, address):
        if sys._getframe(1).f_code.co_name in socketpair_impls:
            return real_connect(self, address)
        raise RuntimeError(f"tests must not open network connections: {address!r}")

    def guard(*args, **kwargs):
        raise RuntimeError(f"tests must not open network connections: {args!r}")

    monkeypatch.setattr(socket.socket, "connect", guarded_connect)
    monkeypatch.setattr(socket.socket, "connect_ex", guard)
    monkeypatch.setattr(socket, "getaddrinfo", guard)


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


@pytest.fixture
def client():
    from fastapi.testclient import TestClient

    with TestClient(fastapi_app) as c:
        yield c


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
