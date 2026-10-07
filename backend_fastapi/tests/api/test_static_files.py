"""S-1：兜底静态路由的路径穿越与正常行为。

静态目录与哨兵文件都在 pytest 临时目录中创建，不涉及任何真实文件。

攻击请求不能用 TestClient 发：httpx 会先把 URL 里的 ../ 规范化掉，请求根本到不了应用。
这里直接调用 ASGI 应用，按 uvicorn 的方式构造 scope：raw_path 是原始字节，
path = urllib.parse.unquote(raw_path)（只解码一次）。
"""
import asyncio
import os
from urllib.parse import quote, unquote

import pytest

import main

SENTINEL = "S1-SENTINEL-6f1d2c"
INDEX_HTML = "<!doctype html><title>spa</title>"
APP_JS = "console.log('app');"


@pytest.fixture
def site(tmp_path, monkeypatch):
    """tmp/static 作为静态目录；tmp/secret/sentinel.txt 是静态目录之外的哨兵文件。"""
    static = tmp_path / "static"
    (static / "assets").mkdir(parents=True)
    (static / "index.html").write_text(INDEX_HTML, encoding="utf-8")
    (static / "main.dart.js").write_text(APP_JS, encoding="utf-8")
    (static / "assets" / "logo.txt").write_text("logo", encoding="utf-8")

    secret = tmp_path / "secret"
    secret.mkdir()
    sentinel = secret / "sentinel.txt"
    sentinel.write_text(SENTINEL, encoding="utf-8")
    # 与静态目录同名前缀的兄弟目录，用来检验"前缀匹配"式的错误校验
    (tmp_path / "static-evil").mkdir()
    (tmp_path / "static-evil" / "sentinel.txt").write_text(SENTINEL, encoding="utf-8")

    monkeypatch.setattr(main, "static_dir", str(static))
    return {"static": static, "sentinel": sentinel}


def raw_get(raw_path: str) -> tuple[int, bytes]:
    """以原始路径调用 ASGI 应用，返回 (状态码, 响应体)。"""
    raw = raw_path.encode("ascii")
    scope = {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": "GET",
        "scheme": "http",
        "path": unquote(raw_path),
        "raw_path": raw,
        "root_path": "",
        "query_string": b"",
        "headers": [(b"host", b"testserver")],
        "client": ("127.0.0.1", 50000),
        "server": ("testserver", 80),
    }
    status, body = 0, bytearray()

    async def receive():
        return {"type": "http.request", "body": b"", "more_body": False}

    async def send(message):
        nonlocal status
        if message["type"] == "http.response.start":
            status = message["status"]
        elif message["type"] == "http.response.body":
            body.extend(message.get("body", b""))

    asyncio.run(main.app(scope, receive, send))
    return status, bytes(body)


def attack_paths(sentinel_abs: str) -> dict[str, str]:
    fwd = sentinel_abs.replace("\\", "/")
    return {
        "dotdot_slash": "/../secret/sentinel.txt",
        "dotdot_deep": "/assets/../../secret/sentinel.txt",
        "dotdot_encoded_slash": "/..%2fsecret%2fsentinel.txt",
        "encoded_dots": "/%2e%2e/secret/sentinel.txt",
        "encoded_dots_upper": "/%2E%2E%2Fsecret%2Fsentinel.txt",
        "dotdot_encoded_backslash": "/..%5csecret%5csentinel.txt",
        "encoded_dots_backslash": "/%2e%2e%5csecret%5csentinel.txt",
        "double_encoded": "/%252e%252e/secret/sentinel.txt",
        "double_encoded_slash": "/..%252fsecret%252fsentinel.txt",
        "four_dots_double_slash": "/....//secret/sentinel.txt",
        "four_dots_backslash": "/....%5c%5csecret%5csentinel.txt",
        "sibling_prefix": "/../static-evil/sentinel.txt",
        "abs_path_encoded": "/" + quote(sentinel_abs, safe=""),
        "abs_path_forward_slash": "/" + quote(fwd, safe="/:"),
        "abs_path_lowercase_drive": "/" + quote(fwd[0].lower() + fwd[1:], safe="/:"),
        "abs_path_leading_slash": "//" + quote(fwd.lstrip("/"), safe="/:"),
    }


ATTACK_NAMES = list(attack_paths("C:\\x").keys())


@pytest.mark.parametrize("name", ATTACK_NAMES)
def test_traversal_does_not_leak_files_outside_static(site, name):
    raw_path = attack_paths(str(site["sentinel"]))[name]
    status, body = raw_get(raw_path)
    assert SENTINEL.encode() not in body, f"{name}: 读到了静态目录之外的哨兵文件"
    assert status != 500


@pytest.mark.parametrize("name", [
    "dotdot_slash", "dotdot_encoded_slash", "encoded_dots", "dotdot_encoded_backslash",
    "sibling_prefix", "abs_path_encoded", "abs_path_forward_slash", "abs_path_lowercase_drive",
])
def test_escaping_static_dir_returns_404(site, name):
    """确实越出静态目录的请求返回 404，而不是回落 index.html。"""
    status, body = raw_get(attack_paths(str(site["sentinel"]))[name])
    assert status == 404
    assert body == b'{"detail":"Not Found"}'


def test_dotdot_that_stays_inside_static_is_allowed(site):
    status, body = raw_get("/assets/../main.dart.js")
    assert status == 200
    assert body.decode() == APP_JS


@pytest.mark.skipif(os.name != "nt", reason="Windows 路径大小写不敏感")
@pytest.mark.parametrize("transform", [str.upper, str.lower])
def test_static_dir_case_mismatch_still_serves_files(site, monkeypatch, client, transform):
    """配置的 static_dir 与磁盘上的大小写不一致时，不能把正常文件误判为越界。"""
    monkeypatch.setattr(main, "static_dir", transform(str(site["static"])))
    resp = client.get("/main.dart.js")
    assert resp.status_code == 200
    assert resp.text == APP_JS
    status, body = raw_get("/../secret/sentinel.txt")
    assert status == 404 and SENTINEL.encode() not in body


def test_nul_byte_does_not_crash_or_leak(site):
    status, body = raw_get("/../secret/sentinel.txt%00.js")
    assert SENTINEL.encode() not in body
    assert status != 500


# ---- 正常行为 ---------------------------------------------------------------

def test_serves_static_file(site, client):
    resp = client.get("/main.dart.js")
    assert resp.status_code == 200
    assert resp.text == APP_JS


def test_serves_nested_static_file(site, client):
    resp = client.get("/assets/logo.txt")
    assert resp.status_code == 200
    assert resp.text == "logo"


@pytest.mark.parametrize("path", ["/", "/history", "/story/42", "/assets/missing.png"])
def test_unknown_path_falls_back_to_index(site, client, path):
    resp = client.get(path)
    assert resp.status_code == 200
    assert resp.text == INDEX_HTML


def test_directory_path_falls_back_to_index(site, client):
    resp = client.get("/assets")
    assert resp.status_code == 200
    assert resp.text == INDEX_HTML


def test_without_index_returns_api_message(tmp_path, monkeypatch, client):
    monkeypatch.setattr(main, "static_dir", str(tmp_path / "empty"))
    resp = client.get("/anything")
    assert resp.status_code == 200
    assert resp.json() == {"message": "AI English Learning API"}


# ---- 其他路由不受影响 -------------------------------------------------------

def test_health_unaffected(site, client):
    assert client.get("/health").json() == {"status": "ok", "version": "1.0.0"}


def test_docs_unaffected(site, client):
    resp = client.get("/docs")
    assert resp.status_code == 200
    assert "swagger-ui" in resp.text.lower()
    assert client.get("/openapi.json").json()["info"]["title"] == "AI English Learning App"


def test_api_routes_unaffected(site, client, use_ocr):
    use_ocr("mock")
    resp = client.post("/api/v1/ocr/recognize", files={"file": ("a.png", b"x", "image/png")})
    assert resp.status_code == 200
    assert resp.json()["reason"] == "ocr_mock"
    assert client.get("/api/v1/history/records/abc").status_code == 422


def test_api_wrong_method_is_swallowed_by_spa_fallback(site, client):
    """现有行为（清单外发现，未改）：兜底 GET 路由比"方法不匹配的 API 路由"优先，
    所以 GET 一个只接受 POST 的 API 路径，或不存在的 /api/v1 路径，返回的是 index.html 而不是 405 / 404。
    此用例固定现状，改变这一行为时需要同步修改。"""
    for path in ("/api/v1/learn/compose", "/api/v1/not-exist"):
        resp = client.get(path)
        assert resp.status_code == 200
        assert resp.text == INDEX_HTML
