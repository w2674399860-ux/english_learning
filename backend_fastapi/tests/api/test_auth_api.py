"""/api/v1/auth/*（连测试库）：注册、登录、登出、当前用户、改密码，以及凭证的整个生命周期。"""
import asyncio
import logging
import re
from datetime import datetime, timedelta, timezone

import pytest
from conftest import DEFAULT_PASSWORD, bearer, make_test_engine, register
from sqlalchemy import text

import app.auth.passwords as passwords

AUTH = "/api/v1/auth"
ISO_UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$")


def sql(statement: str, **params):
    async def run():
        engine = make_test_engine()
        try:
            async with engine.begin() as conn:
                result = await conn.execute(text(statement), params)
                return result.all() if result.returns_rows else None
        finally:
            await engine.dispose()

    return asyncio.run(run())


def login(client, username, password=DEFAULT_PASSWORD):
    return client.post(f"{AUTH}/login", json={"username": username, "password": password})


def me(client, token):
    return client.get(f"{AUTH}/me", headers=bearer(token))


# ---- 注册 -------------------------------------------------------------------

def test_register_returns_token_and_logs_in(db_client):
    body = register(db_client, "Alice_01")
    assert set(body) == {"token", "token_type", "expires_at", "user"}
    assert body["token_type"] == "bearer"
    assert body["user"]["username"] == "alice_01"
    assert ISO_UTC.match(body["expires_at"]) and ISO_UTC.match(body["user"]["created_at"])

    expires = datetime.fromisoformat(body["expires_at"].replace("Z", "+00:00"))
    assert timedelta(days=29, hours=23) < expires - datetime.now(timezone.utc) <= timedelta(days=30)

    resp = me(db_client, body["token"])
    assert resp.status_code == 200
    assert resp.json() == body["user"]


@pytest.mark.parametrize("second", ["alice", "Alice", "ALICE"])
def test_duplicate_username_is_case_insensitive(db_client, second):
    register(db_client, "alice")
    resp = db_client.post(f"{AUTH}/register", json={"username": second, "password": DEFAULT_PASSWORD})
    assert resp.status_code == 409
    assert resp.json() == {"detail": "用户名已被注册"}


@pytest.mark.parametrize("payload, detail", [
    ({"username": "ab", "password": DEFAULT_PASSWORD}, "用户名需为 3~20 位字母、数字或下划线"),
    ({"username": "аlice", "password": DEFAULT_PASSWORD}, "用户名需为 3~20 位字母、数字或下划线"),
    ({"username": "alice", "password": "short"}, "密码至少 8 位"),
    ({"username": "alice", "password": "x" * 129}, "密码不能超过 128 位"),
    ({"username": "alice_pw", "password": "ALICE_PW"}, "密码不能与用户名相同"),
    ({"username": "alice", "password": "password123"}, "密码过于简单，请换一个"),
])
def test_register_rules(db_client, payload, detail):
    resp = db_client.post(f"{AUTH}/register", json=payload)
    assert resp.status_code == 422
    assert resp.json() == {"detail": detail}
    assert sql("SELECT COUNT(*) FROM users")[0][0] == 0


def test_register_ignores_user_supplied_fields(db_client):
    resp = db_client.post(
        f"{AUTH}/register",
        json={"username": "alice", "password": DEFAULT_PASSWORD, "is_active": False, "id": 999},
    )
    assert resp.status_code == 201
    assert resp.json()["user"]["id"] != 999
    assert sql("SELECT is_active FROM users WHERE username='alice'") == [(1,)]


# ---- 密码与凭证的存储 -------------------------------------------------------

def test_password_stored_as_argon2id_with_unique_salt(db_client):
    register(db_client, "alice")
    register(db_client, "bob")
    hashes = [r[0] for r in sql("SELECT password_hash FROM users ORDER BY id")]
    assert all(h.startswith("$argon2id$") for h in hashes)
    assert hashes[0] != hashes[1]
    assert all(DEFAULT_PASSWORD not in h for h in hashes)


def test_only_token_hash_is_stored(db_client):
    token = register(db_client, "alice")["token"]
    rows = sql("SELECT token_hash FROM sessions")
    assert len(rows) == 1
    assert rows[0][0] != token and len(rows[0][0]) == 64
    dump = str(sql("SELECT * FROM sessions")) + str(sql("SELECT * FROM users"))
    assert token not in dump


# ---- 登录 -------------------------------------------------------------------

def test_login_success_and_case_insensitive_username(db_client):
    register(db_client, "alice")
    resp = login(db_client, "ALICE")
    assert resp.status_code == 200
    body = resp.json()
    assert body["user"]["username"] == "alice"
    assert me(db_client, body["token"]).status_code == 200
    assert sql("SELECT last_login_at IS NOT NULL FROM users") == [(1,)]


def test_wrong_password_and_unknown_user_are_indistinguishable(db_client, monkeypatch):
    register(db_client, "alice")
    from argon2 import PasswordHasher

    calls = []

    class SpyHasher(PasswordHasher):  # PasswordHasher 用了 __slots__，不能直接替换实例方法
        def verify(self, hash_, password):
            calls.append(hash_)
            return super().verify(hash_, password)

    monkeypatch.setattr(passwords, "password_hasher", SpyHasher(time_cost=1, memory_cost=1024, parallelism=1))

    wrong = login(db_client, "alice", "wrong-password-1")
    unknown = login(db_client, "nobody_here", "wrong-password-1")
    malformed = login(db_client, "no such user!", "wrong-password-1")

    for resp in (wrong, unknown, malformed):
        assert resp.status_code == 401
        assert resp.json() == {"detail": "用户名或密码错误"}
    assert wrong.headers.get("www-authenticate") == unknown.headers.get("www-authenticate")
    # 用户不存在时也做了一次哈希校验（对着一个预先算好的假哈希）
    assert len(calls) == 3


def test_disabled_account_cannot_login(db_client):
    register(db_client, "alice")
    sql("UPDATE users SET is_active = 0 WHERE username = 'alice'")
    resp = login(db_client, "alice")
    assert resp.status_code == 403
    assert resp.json() == {"detail": "账号已停用，请联系管理员"}
    # 密码错误时仍然只说"用户名或密码错误"
    assert login(db_client, "alice", "wrong-password-1").status_code == 401


def test_login_rehashes_outdated_parameters(db_client, monkeypatch):
    from argon2 import PasswordHasher

    register(db_client, "alice")
    before = sql("SELECT password_hash FROM users")[0][0]
    monkeypatch.setattr(passwords, "password_hasher", PasswordHasher(time_cost=2, memory_cost=1024, parallelism=1))
    assert login(db_client, "alice").status_code == 200
    after = sql("SELECT password_hash FROM users")[0][0]
    assert after != before and "t=2" in after


# ---- 凭证失效 ---------------------------------------------------------------

def test_missing_or_malformed_credentials(db_client):
    assert db_client.get(f"{AUTH}/me").json() == {"detail": "请先登录"}
    for headers in ({"Authorization": "Basic abc"}, {"Authorization": "Bearer"}, {"Authorization": "token"}):
        resp = db_client.get(f"{AUTH}/me", headers=headers)
        assert resp.status_code == 401
        assert resp.headers["www-authenticate"] == "Bearer"


@pytest.mark.parametrize("mutate", [lambda t: t + "x", lambda t: t[:-1], lambda t: t.upper(), lambda t: "x" * 43])
def test_tampered_token_is_rejected(db_client, mutate):
    token = register(db_client, "alice")["token"]
    resp = me(db_client, mutate(token))
    assert resp.status_code == 401
    assert resp.json() == {"detail": "登录已失效，请重新登录"}


def test_token_in_query_string_is_not_accepted(db_client):
    token = register(db_client, "alice")["token"]
    for name in ("token", "access_token", "authorization"):
        assert db_client.get(f"{AUTH}/me", params={name: token}).status_code == 401


def test_logout_revokes_only_current_session(db_client):
    first = register(db_client, "alice")["token"]
    second = login(db_client, "alice").json()["token"]

    resp = db_client.post(f"{AUTH}/logout", headers=bearer(first))
    assert resp.status_code == 204
    assert me(db_client, first).status_code == 401
    assert me(db_client, second).status_code == 200
    assert db_client.post(f"{AUTH}/logout", headers=bearer(first)).status_code == 401


def test_expired_session_is_rejected(db_client):
    token = register(db_client, "alice")["token"]
    sql("UPDATE sessions SET expires_at = UTC_TIMESTAMP(3) - INTERVAL 1 SECOND")
    resp = me(db_client, token)
    assert resp.status_code == 401
    assert resp.json() == {"detail": "登录已失效，请重新登录"}


def test_disabling_account_revokes_existing_tokens(db_client):
    token = register(db_client, "alice")["token"]
    sql("UPDATE users SET is_active = 0")
    assert me(db_client, token).status_code == 401


# ---- 改密码 -----------------------------------------------------------------

def test_change_password_revokes_all_old_tokens(db_client):
    first = register(db_client, "alice")["token"]
    second = login(db_client, "alice").json()["token"]

    resp = db_client.post(
        f"{AUTH}/change-password",
        headers=bearer(first),
        json={"old_password": DEFAULT_PASSWORD, "new_password": "brand-new-pass-7"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert set(body) == {"token", "token_type", "expires_at"}

    assert me(db_client, first).status_code == 401
    assert me(db_client, second).status_code == 401
    assert me(db_client, body["token"]).status_code == 200
    assert login(db_client, "alice").status_code == 401
    assert login(db_client, "alice", "brand-new-pass-7").status_code == 200


@pytest.mark.parametrize("payload, status, detail", [
    ({"old_password": "wrong-old-pass", "new_password": "brand-new-pass-7"}, 400, "原密码不正确"),
    ({"old_password": DEFAULT_PASSWORD, "new_password": DEFAULT_PASSWORD}, 422, "新密码不能与原密码相同"),
    ({"old_password": DEFAULT_PASSWORD, "new_password": "short"}, 422, "密码至少 8 位"),
    ({"old_password": DEFAULT_PASSWORD, "new_password": "alice"}, 422, "密码至少 8 位"),
    ({"old_password": DEFAULT_PASSWORD, "new_password": "qwerty123"}, 422, "密码过于简单，请换一个"),
])
def test_change_password_errors_keep_session(db_client, payload, status, detail):
    token = register(db_client, "alice")["token"]
    resp = db_client.post(f"{AUTH}/change-password", headers=bearer(token), json=payload)
    assert resp.status_code == status
    assert resp.json() == {"detail": detail}
    assert me(db_client, token).status_code == 200


# ---- 日志不泄密 ---------------------------------------------------------------

def test_logs_never_contain_passwords_or_tokens(db_client, caplog):
    with caplog.at_level(logging.DEBUG):
        token = register(db_client, "alice")["token"]
        login(db_client, "alice", "wrong-password-1")
        login(db_client, "ghost", "another-secret-9")
        db_client.post(
            f"{AUTH}/change-password",
            headers=bearer(token),
            json={"old_password": DEFAULT_PASSWORD, "new_password": "brand-new-pass-7"},
        )
        me(db_client, "forged-token-value")
    text_ = caplog.text
    for secret in (DEFAULT_PASSWORD, "wrong-password-1", "another-secret-9", "brand-new-pass-7", token,
                   "forged-token-value", "Bearer", "$argon2"):
        assert secret not in text_, secret
    assert "login failed" in text_
