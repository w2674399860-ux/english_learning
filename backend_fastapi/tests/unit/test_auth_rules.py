"""账号规则（纯函数）、凭证生成、生产哈希参数、鉴权覆盖（路由清点）。不连数据库。"""
import re

import pytest
from fastapi.routing import APIRoute

import app.auth.passwords as passwords
from app.auth.dependencies import get_current_user
from app.auth.passwords import AuthRuleError, validate_new_password, validate_username
from app.auth.tokens import hash_token, new_token
from main import app

# ---- 用户名 -----------------------------------------------------------------

@pytest.mark.parametrize("raw, normalized", [
    ("alice", "alice"), ("Alice_01", "alice_01"), ("ABC", "abc"), ("a" * 20, "a" * 20), ("___", "___"),
])
def test_valid_usernames_are_lowercased(raw, normalized):
    assert validate_username(raw) == normalized


@pytest.mark.parametrize("raw", [
    "", "ab", "a" * 21, "bad-name", "with space", " alice", "alice ", "名字中文",
    "аlice",  # 第一个字母是西里尔字母 а
    "ａｌｉｃｅ",  # 全角
    "alice\n", "al.ice", "al@ice",
])
def test_invalid_usernames_are_rejected(raw):
    with pytest.raises(AuthRuleError) as exc:
        validate_username(raw)
    assert exc.value.status_code == 422
    assert exc.value.detail == "用户名需为 3~20 位字母、数字或下划线"


# ---- 密码 -------------------------------------------------------------------

@pytest.mark.parametrize("password", ["river-stone-42", "a" * 8 + "1", "长一点的中文密码也可以", "x" * 128])
def test_valid_passwords(password):
    validate_new_password(password, username="alice")


@pytest.mark.parametrize("password, detail", [
    ("short7!", "密码至少 8 位"),
    ("", "密码至少 8 位"),
    ("x" * 129, "密码不能超过 128 位"),
    ("alice_01", "密码不能与用户名相同"),
    ("ALICE_01", "密码不能与用户名相同"),
    ("12345678", "密码过于简单，请换一个"),
    ("Password", "密码过于简单，请换一个"),
    ("qwertyuiop", "密码过于简单，请换一个"),
])
def test_invalid_passwords(password, detail):
    with pytest.raises(AuthRuleError) as exc:
        validate_new_password(password, username="alice_01")
    assert exc.value.status_code == 422
    assert exc.value.detail == detail


def test_common_password_list_only_has_passwords_of_valid_length():
    """短于 8 位的已被长度规则拒绝，黑名单里放它们没有意义。"""
    assert passwords.COMMON_PASSWORDS
    assert all(len(p) >= 8 for p in passwords.COMMON_PASSWORDS)
    assert all(p == p.lower() for p in passwords.COMMON_PASSWORDS)


def test_production_hasher_parameters():
    ph = passwords.make_hasher()
    assert (ph.type.name, ph.time_cost, ph.memory_cost, ph.parallelism) == ("ID", 3, 65536, 4)
    assert ph.hash("x" * 10).startswith("$argon2id$v=19$m=65536,t=3,p=4$")


def test_hash_concurrency_limit():
    assert passwords.MAX_CONCURRENT_HASHES == 4


# ---- 凭证 -------------------------------------------------------------------

def test_tokens_are_random_urlsafe_and_long():
    tokens = {new_token() for _ in range(100)}
    assert len(tokens) == 100
    assert all(re.fullmatch(r"[A-Za-z0-9_-]{43}", t) for t in tokens)


def test_token_hash_is_sha256_hex():
    assert hash_token("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"


# ---- 鉴权覆盖：路由清点 -------------------------------------------------------

PUBLIC_ROUTES = {
    ("GET", "/health"),
    ("POST", "/api/v1/auth/register"),
    ("POST", "/api/v1/auth/login"),
    ("GET", "/{full_path:path}"),
    # 接口文档：API_DOCS_ENABLED 关闭时不注册这些路由（测试中开启）
    ("GET", "/docs"), ("HEAD", "/docs"),
    ("GET", "/docs/oauth2-redirect"), ("HEAD", "/docs/oauth2-redirect"),
    ("GET", "/redoc"), ("HEAD", "/redoc"),
    ("GET", "/openapi.json"), ("HEAD", "/openapi.json"),
}


def _depends_on(dependant, target) -> bool:
    return any(d.call is target or _depends_on(d, target) for d in dependant.dependencies)


def _all_routes():
    for route in app.routes:
        for method in getattr(route, "methods", None) or []:
            yield method, route.path, route


def test_every_non_public_route_requires_login():
    unprotected = []
    for method, path, route in _all_routes():
        if (method, path) in PUBLIC_ROUTES:
            continue
        if not isinstance(route, APIRoute) or not _depends_on(route.dependant, get_current_user):
            unprotected.append(f"{method} {path}")
    assert unprotected == []


def test_public_routes_do_not_require_login():
    for method, path, route in _all_routes():
        if (method, path) in PUBLIC_ROUTES and isinstance(route, APIRoute):
            assert not _depends_on(route.dependant, get_current_user), f"{method} {path}"


def test_legacy_story_routes_are_gone():
    assert not [p for _, p, _ in _all_routes() if p.startswith("/api/v1/story")]


def test_expected_business_routes_exist():
    routes = {(m, p) for m, p, _ in _all_routes()}
    for expected in [
        ("POST", "/api/v1/ocr/recognize"), ("POST", "/api/v1/learn/compose"),
        ("POST", "/api/v1/history/save"), ("GET", "/api/v1/history/records"),
        ("GET", "/api/v1/history/records/{record_id}"), ("PUT", "/api/v1/history/records/{record_id}"),
        ("DELETE", "/api/v1/history/records/{record_id}"),
        ("POST", "/api/v1/auth/logout"), ("GET", "/api/v1/auth/me"), ("POST", "/api/v1/auth/change-password"),
    ]:
        assert expected in routes, expected


# ---- 接口文档开关 -------------------------------------------------------------

def test_docs_disabled_by_default_in_settings():
    from app.core.config import Settings

    assert Settings.model_fields["api_docs_enabled"].default is False


def test_docs_options():
    from fastapi import FastAPI
    from fastapi.testclient import TestClient

    from main import docs_options

    assert docs_options(True) == {}
    hidden = FastAPI(**docs_options(False))
    with TestClient(hidden) as c:
        for path in ("/docs", "/redoc", "/openapi.json"):
            assert c.get(path).status_code == 404
