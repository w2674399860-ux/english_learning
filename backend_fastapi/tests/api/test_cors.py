"""S-3a CORS 白名单（不连数据库）。

conftest 把 CORS_ALLOW_ORIGINS 设为 ALLOWED（在导入 main 之前），这里对真实的 app 验证；
"默认为空"用 main.cors_options 在一个新的 FastAPI 应用上验证。
"""
import logging

import pytest
from conftest import CORS_TEST_ORIGIN
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.testclient import TestClient
from pydantic import ValidationError

import main
from app.core.config import Settings, settings
from app.ratelimit import limiter

ALLOWED = CORS_TEST_ORIGIN
DISALLOWED = "http://evil.example"
COMPOSE_URL = "/api/v1/learn/compose"
OCR_URL = "/api/v1/ocr/recognize"


def preflight(client, origin, method="POST", headers="authorization,content-type", url=COMPOSE_URL):
    return client.options(url, headers={
        "Origin": origin,
        "Access-Control-Request-Method": method,
        "Access-Control-Request-Headers": headers,
    })


def acao(resp):
    return resp.headers.get("access-control-allow-origin")


# ---- 白名单内 / 外 -------------------------------------------------------------

def test_preflight_from_allowed_origin(client):
    resp = preflight(client, ALLOWED)
    assert resp.status_code == 200
    assert acao(resp) == ALLOWED
    assert resp.headers["access-control-allow-methods"] == "GET, POST, PUT, DELETE"
    assert set(resp.headers["access-control-allow-headers"].lower().split(", ")) >= {"authorization", "content-type"}
    assert resp.headers["access-control-max-age"] == "600"
    assert "access-control-allow-credentials" not in resp.headers


def test_preflight_from_disallowed_origin(client):
    resp = preflight(client, DISALLOWED)
    assert resp.status_code == 400
    assert acao(resp) is None
    assert not [h for h in resp.headers if h.startswith("access-control-allow-origin")]


def test_simple_request_from_allowed_origin(client):
    resp = client.get("/health", headers={"Origin": ALLOWED})
    assert resp.status_code == 200
    assert acao(resp) == ALLOWED
    assert resp.headers["access-control-expose-headers"] == "Retry-After"
    assert "access-control-allow-credentials" not in resp.headers


def test_simple_request_from_disallowed_origin_gets_no_cors_headers(client):
    """服务端照常处理（CORS 不是访问控制），但浏览器拿不到响应。"""
    resp = client.get("/health", headers={"Origin": DISALLOWED})
    assert resp.status_code == 200
    assert acao(resp) is None


@pytest.mark.parametrize("origin", [
    ALLOWED + "/", ALLOWED.replace("http://", "https://"), ALLOWED.replace("5000", "5001"), "null",
])
def test_origin_must_match_exactly(client, origin):
    assert preflight(client, origin).status_code == 400


@pytest.mark.parametrize("method, headers", [("PATCH", "content-type"), ("POST", "x-custom")])
def test_methods_and_headers_outside_allow_list_are_rejected(client, method, headers):
    assert preflight(client, ALLOWED, method=method, headers=headers).status_code == 400


@pytest.mark.parametrize("method", ["GET", "POST", "PUT", "DELETE"])
def test_used_methods_are_allowed(client, method):
    assert preflight(client, ALLOWED, method=method, headers="authorization").status_code == 200


# ---- 错误响应同样带 CORS 头（前端能读到 detail 与 Retry-After） -------------------------

def test_429_carries_cors_and_exposes_retry_after(client, monkeypatch):
    async def always_429(session, scope, subject):
        raise HTTPException(429, detail="too many", headers={"Retry-After": "42"})

    monkeypatch.setattr(limiter, "enforce", always_429)
    resp = client.post(COMPOSE_URL, json={"words": ["cat"]}, headers={"Origin": ALLOWED})
    assert resp.status_code == 429
    assert acao(resp) == ALLOWED
    assert resp.headers["retry-after"] == "42"
    assert resp.headers["access-control-expose-headers"] == "Retry-After"


def test_413_carries_cors(client, monkeypatch):
    monkeypatch.setattr(settings, "max_request_bytes", 10)
    resp = client.post(COMPOSE_URL, json={"words": ["a" * 50]}, headers={"Origin": ALLOWED})
    assert resp.status_code == 413
    assert acao(resp) == ALLOWED


# ---- 默认为空 --------------------------------------------------------------------

def test_default_allows_no_origin():
    assert Settings.model_fields["cors_allow_origins"].default == ""
    assert Settings(cors_allow_origins="").cors_origins == []

    app = FastAPI()
    app.add_middleware(CORSMiddleware, **main.cors_options([]))

    @app.get("/ping")
    def ping():
        return {}

    with TestClient(app) as c:
        assert preflight(c, ALLOWED, url="/ping", method="GET").status_code == 400
        assert acao(c.get("/ping", headers={"Origin": ALLOWED})) is None


def test_cors_options():
    assert main.cors_options(["http://a.test"]) == {
        "allow_origins": ["http://a.test"],
        "allow_credentials": False,
        "allow_methods": ["GET", "POST", "PUT", "DELETE"],
        "allow_headers": ["Authorization", "Content-Type"],
        "expose_headers": ["Retry-After"],
        "max_age": 600,
    }


# ---- 配置解析与校验 ------------------------------------------------------------------

@pytest.mark.parametrize("raw, parsed", [
    ("http://localhost:5000", ["http://localhost:5000"]),
    (" http://localhost:5000 , http://127.0.0.1:5000 ,", ["http://localhost:5000", "http://127.0.0.1:5000"]),
    ("https://app.example.com", ["https://app.example.com"]),
    ("http://[::1]:5000", ["http://[::1]:5000"]),
    ("HTTP://LocalHost:5000", ["http://localhost:5000"]),
    ("http://localhost:5000,http://localhost:5000", ["http://localhost:5000"]),
])
def test_cors_origins_parsing(raw, parsed):
    assert Settings(cors_allow_origins=raw).cors_origins == parsed


@pytest.mark.parametrize("raw", [
    "*", "http://*.example.com", "http://localhost:5000/", "http://localhost:5000/app",
    "http://localhost:5000?x=1", "ftp://localhost", "localhost:5000", "http://", "http://u:p@localhost",
    "http://localhost:99999", "http://local host",
])
def test_invalid_cors_origins_are_rejected(raw):
    with pytest.raises(ValidationError) as exc:
        Settings(cors_allow_origins=raw)
    assert "CORS_ALLOW_ORIGINS" in str(exc.value)


# ---- FRONTEND_URL 已废弃 ---------------------------------------------------------------

def test_frontend_url_is_deprecated(monkeypatch, caplog):
    monkeypatch.setattr(settings, "frontend_url", "http://localhost:3000")
    with caplog.at_level(logging.WARNING, logger="app"):
        main.warn_deprecated_settings()
    assert "FRONTEND_URL" in caplog.text and "CORS_ALLOW_ORIGINS" in caplog.text


def test_no_warning_when_frontend_url_unset(monkeypatch, caplog):
    monkeypatch.setattr(settings, "frontend_url", None)
    with caplog.at_level(logging.WARNING, logger="app"):
        main.warn_deprecated_settings()
    assert caplog.text == ""
