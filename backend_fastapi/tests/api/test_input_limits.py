"""S-5 输入上限（不连数据库）：请求体大小 413、生成词表 422。

请求体大小在 ASGI 中间件里检查，早于鉴权：未登录的超大请求同样 413，不会先被完整接收。
"""
import pytest
from conftest import tiny_png
from fastapi.testclient import TestClient

from app.core.config import settings
from main import app

OCR_URL = "/api/v1/ocr/recognize"
COMPOSE_URL = "/api/v1/learn/compose"


@pytest.fixture
def anonymous():
    """未登录的 TestClient（不连库：没有凭证时鉴权在使用会话之前就返回 401）。"""
    from app.db.session import get_session

    async def no_database():
        yield None

    app.dependency_overrides[get_session] = no_database
    try:
        with TestClient(app) as c:
            yield c
    finally:
        app.dependency_overrides.pop(get_session, None)


@pytest.fixture
def small_limits(monkeypatch):
    monkeypatch.setattr(settings, "max_upload_bytes", 2000)
    monkeypatch.setattr(settings, "max_request_bytes", 500)


def multipart(size: int) -> bytes:
    """返回总长度恰好为 size 的 multipart 请求体（boundary 固定）。"""
    head = b'--B\r\nContent-Disposition: form-data; name="file"; filename="a.png"\r\nContent-Type: image/png\r\n\r\n'
    tail = b"\r\n--B--\r\n"
    return head + b"x" * (size - len(head) - len(tail)) + tail


MULTIPART_HEADERS = {"Content-Type": "multipart/form-data; boundary=B"}


def chunks(body: bytes, size: int = 256):
    for i in range(0, len(body), size):
        yield body[i:i + size]


# ---- 413：上传 -----------------------------------------------------------------

def test_upload_over_limit_by_content_length(client, small_limits, use_ocr):
    use_ocr("mock")
    resp = client.post(OCR_URL, content=multipart(2001), headers=MULTIPART_HEADERS)
    assert resp.status_code == 413
    assert resp.json() == {"detail": "图片不能超过 2 KB"}


def test_upload_detail_uses_megabytes(client, use_ocr):
    use_ocr("mock")
    resp = client.post(OCR_URL, content=multipart(10 * 1024 * 1024 + 1), headers=MULTIPART_HEADERS)
    assert resp.status_code == 413
    assert resp.json() == {"detail": "图片不能超过 10 MB"}


def test_upload_at_limit_is_accepted(client, small_limits, use_ocr):
    use_ocr("mock")
    resp = client.post(OCR_URL, content=multipart(2000), headers=MULTIPART_HEADERS)
    assert resp.status_code == 200, resp.text


def test_real_image_upload_still_works(client, use_ocr):
    use_ocr("mock")
    resp = client.post(OCR_URL, files={"file": ("a.png", tiny_png(), "image/png")})
    assert resp.status_code == 200


def test_chunked_upload_over_limit(client, small_limits, use_ocr):
    """没有 Content-Length（分块传输）时边收边数。"""
    use_ocr("mock")
    resp = client.post(OCR_URL, content=chunks(multipart(5000)), headers=MULTIPART_HEADERS)
    assert "content-length" not in {k.lower() for k in resp.request.headers}
    assert resp.status_code == 413
    assert resp.json()["detail"].startswith("图片不能超过")


def test_chunked_upload_within_limit(client, small_limits, use_ocr):
    use_ocr("mock")
    resp = client.post(OCR_URL, content=chunks(multipart(1500)), headers=MULTIPART_HEADERS)
    assert resp.status_code == 200, resp.text


@pytest.mark.parametrize("chunked", [False, True])
def test_oversized_upload_rejected_before_authentication(anonymous, small_limits, chunked):
    """未登录：大小检查先于鉴权，返回 413 而不是 401（不会先把整个请求体收下来）。"""
    body = multipart(5000)
    resp = anonymous.post(OCR_URL, content=chunks(body) if chunked else body, headers=MULTIPART_HEADERS)
    assert resp.status_code == 413


def test_small_anonymous_upload_still_401(anonymous, small_limits):
    resp = anonymous.post(OCR_URL, content=multipart(1000), headers=MULTIPART_HEADERS)
    assert resp.status_code == 401


# ---- 413：其他接口 ----------------------------------------------------------------

def test_json_body_over_request_limit(client, small_limits):
    resp = client.post(COMPOSE_URL, json={"words": ["a" * 600]})
    assert resp.status_code == 413
    assert resp.json() == {"detail": "请求内容过大"}


def test_upload_limit_only_applies_to_ocr(client, small_limits):
    """1500 字节的 JSON：小于上传上限，但超过普通接口上限。"""
    resp = client.post(COMPOSE_URL, content=b"{" + b" " * 1500 + b"}", headers={"Content-Type": "application/json"})
    assert resp.status_code == 413


def test_non_api_paths_are_not_limited(client, small_limits):
    assert client.get("/health").status_code == 200


# ---- 422：生成词表 ---------------------------------------------------------------

@pytest.fixture
def compose_ok(upstream, use_ai):
    use_ai(fallback=True, api_key="")  # 未配置 Key 时回落示例故事，不访问网络


def test_compose_accepts_max_words(client, compose_ok):
    resp = client.post(COMPOSE_URL, json={"words": [f"w{i}" for i in range(20)]})
    assert resp.status_code == 200, resp.text


def test_compose_rejects_too_many_words(client, compose_ok):
    resp = client.post(COMPOSE_URL, json={"words": [f"w{i}" for i in range(21)]})
    assert resp.status_code == 422
    assert resp.json() == {"detail": "一次最多 20 个单词"}


def test_compose_accepts_max_word_length(client, compose_ok):
    resp = client.post(COMPOSE_URL, json={"words": ["a" * 40]})
    assert resp.status_code == 200, resp.text


def test_compose_rejects_long_word(client, compose_ok):
    resp = client.post(COMPOSE_URL, json={"words": ["ok", "b" * 41]})
    assert resp.status_code == 422
    assert resp.json() == {"detail": "单词不能超过 40 个字符：" + "b" * 20 + "…"}


def test_word_limits_follow_config(client, compose_ok, monkeypatch):
    monkeypatch.setattr(settings, "compose_max_words", 2)
    monkeypatch.setattr(settings, "compose_max_word_length", 5)
    assert client.post(COMPOSE_URL, json={"words": ["a", "b", "c"]}).json() == {"detail": "一次最多 2 个单词"}
    assert client.post(COMPOSE_URL, json={"words": ["abcdef"]}).json() == {"detail": "单词不能超过 5 个字符：abcdef"}
