"""S-5 限流接口测试（连测试库）。

- 额度改成 2 次、窗口 60 秒；限流用的时钟冻结在窗口中间，"窗口过后恢复"直接拨钟，不用等待
- 不同客户端 IP 用 httpx.ASGITransport(client=(ip, port)) 模拟（conftest 打桩的 AsyncClient 只走 MockTransport，
  这里用原始的 httpx.AsyncClient）
"""
import asyncio
import logging
from datetime import datetime, timedelta

import httpx
import pytest
from conftest import DEFAULT_PASSWORD, OCR_BASE, _RealAsyncClient, bearer, raiser, register, tiny_png
from sqlalchemy import select

from app.auth import passwords
from app.core.config import settings
from app.models.rate_limit import RateLimitCounter
from app.ratelimit import limiter
from main import app as fastapi_app

OCR_URL = "/api/v1/ocr/recognize"
COMPOSE_URL = "/api/v1/learn/compose"
LOGIN_URL = "/api/v1/auth/login"
REGISTER_URL = "/api/v1/auth/register"
FROZEN = datetime(2026, 10, 7, 12, 0, 30)  # 60 秒窗口内还剩 30 秒


class Clock:
    def __init__(self, now: datetime):
        self.now = now

    def advance(self, seconds: int):
        self.now += timedelta(seconds=seconds)


@pytest.fixture
def clock(monkeypatch):
    c = Clock(FROZEN)
    monkeypatch.setattr(limiter, "clock", lambda: c.now)
    return c


@pytest.fixture
def limits(monkeypatch, clock):
    """打开限流；所有规则先放宽到 1000 次 / 60 秒，测试再单独收紧某一条。"""
    monkeypatch.setattr(settings, "rate_limit_enabled", True)
    for scope, (limit_attr, window_attr) in limiter.RULE_SETTINGS.items():
        monkeypatch.setattr(settings, limit_attr, 1000)
        monkeypatch.setattr(settings, window_attr, 60)

    def set_limit(scope: str, limit: int, window: int = 60):
        limit_attr, window_attr = limiter.RULE_SETTINGS[scope]
        monkeypatch.setattr(settings, limit_attr, limit)
        monkeypatch.setattr(settings, window_attr, window)

    return set_limit


@pytest.fixture
def compose_ok(upstream, use_ai):
    use_ai(fallback=True, api_key="")  # 回落示例故事，不访问网络


def ip_client(ip: str, **kwargs) -> httpx.AsyncClient:
    transport = httpx.ASGITransport(app=fastapi_app, client=(ip, 50000))
    return _RealAsyncClient(transport=transport, base_url="http://testserver", **kwargs)


def upload(client):
    return client.post(OCR_URL, files={"file": ("a.png", tiny_png(), "image/png")})


async def counters(db_session, *scopes: str) -> dict[tuple[str, str], int]:
    """当前计数；给出 scopes 时只看这些规则（测试里注册用户也会计入 register）。"""
    rows = (await db_session.execute(select(RateLimitCounter))).scalars().all()
    return {(r.scope, r.subject): r.count for r in rows if not scopes or r.scope in scopes}


# ---- 超限 429 ------------------------------------------------------------------

def test_ocr_over_quota_is_429_with_retry_after(alice_client, limits, use_ocr):
    limits("ocr", 2)
    use_ocr("mock")
    assert [upload(alice_client).status_code for _ in range(2)] == [200, 200]
    resp = upload(alice_client)
    assert resp.status_code == 429
    assert resp.headers["Retry-After"] == "30"
    assert resp.json() == {"detail": "识别次数已用完（每分钟 2 次），请 1 分钟后再试"}


def test_compose_over_quota_is_429(alice_client, limits, compose_ok):
    limits("compose", 2, window=86400)
    for _ in range(2):
        assert alice_client.post(COMPOSE_URL, json={"words": ["cat"]}).status_code == 200
    resp = alice_client.post(COMPOSE_URL, json={"words": ["cat"]})
    assert resp.status_code == 429
    # 12:00:30 UTC，到 UTC 次日 0 点还有 43170 秒
    assert resp.headers["Retry-After"] == "43170"
    assert resp.json() == {"detail": "生成次数已用完（每天 2 次），请约 12 小时后再试"}


def test_429_takes_precedence_over_validation_errors(alice_client, limits, compose_ok):
    limits("compose", 1)
    assert alice_client.post(COMPOSE_URL, json={"words": ["cat"]}).status_code == 200
    assert alice_client.post(COMPOSE_URL, json={"words": "not-a-list"}).status_code == 429


# ---- 窗口过后恢复 ----------------------------------------------------------------

async def test_quota_recovers_after_window(alice_client, limits, use_ocr, clock, db_session):
    limits("ocr", 2)
    use_ocr("mock")
    statuses = [upload(alice_client).status_code for _ in range(3)]
    assert statuses == [200, 200, 429]

    clock.advance(29)  # 仍在同一窗口
    assert upload(alice_client).status_code == 429
    clock.advance(1)  # 12:01:00，新窗口
    assert upload(alice_client).status_code == 200

    rows = (await db_session.execute(select(RateLimitCounter.window_start, RateLimitCounter.count)
                                     .order_by(RateLimitCounter.window_start))).all()
    assert [tuple(r) for r in rows] == [(datetime(2026, 10, 7, 12, 0), 4), (datetime(2026, 10, 7, 12, 1), 1)]


# ---- 不同用户互不影响；同一用户换 IP 仍受用户额度限制 ---------------------------------

def test_users_do_not_share_quota(db_client, limits, use_ocr):
    limits("ocr", 2)
    use_ocr("mock")
    alice = bearer(register(db_client, "alice")["token"])
    bob = bearer(register(db_client, "bob")["token"])
    png = {"file": ("a.png", tiny_png(), "image/png")}
    assert [db_client.post(OCR_URL, files=png, headers=alice).status_code for _ in range(3)] == [200, 200, 429]
    assert db_client.post(OCR_URL, files=png, headers=bob).status_code == 200


async def test_same_user_on_different_ips_shares_user_quota(db_client, limits, use_ocr, db_session):
    limits("ocr", 2)
    use_ocr("mock")
    token = register(db_client, "alice")["token"]
    statuses = []
    for ip in ("203.0.113.1", "203.0.113.2", "2001:db8::9"):
        async with ip_client(ip, headers=bearer(token)) as c:
            statuses.append((await upload(c)).status_code)
    assert statuses == [200, 200, 429]
    user_id = db_client.get("/api/v1/auth/me", headers=bearer(token)).json()["id"]
    assert await counters(db_session, "ocr") == {("ocr", f"u:{user_id}"): 3}


# ---- 登录 / 注册按 IP --------------------------------------------------------------

async def test_login_is_limited_per_ip(db_client, limits):
    limits("login", 2)
    register(db_client, "alice")
    good = {"username": "alice", "password": DEFAULT_PASSWORD}
    bad = {"username": "alice", "password": "wrong-password-1"}
    async with ip_client("203.0.113.1") as a, ip_client("203.0.113.2") as b:
        # 成功与失败都计入
        assert (await a.post(LOGIN_URL, json=bad)).status_code == 401
        assert (await a.post(LOGIN_URL, json=good)).status_code == 200
        resp = await a.post(LOGIN_URL, json=good)
        assert resp.status_code == 429
        assert resp.headers["Retry-After"] == "30"
        assert resp.json() == {"detail": "登录尝试过于频繁（每分钟 2 次），请 1 分钟后再试"}
        # 另一个 IP 不受影响
        assert (await b.post(LOGIN_URL, json=good)).status_code == 200


async def test_login_limit_is_checked_before_password_hashing(db_client, limits, monkeypatch):
    limits("login", 2)
    register(db_client, "alice")
    calls = []
    real_verify, real_dummy = passwords.verify_password, passwords.verify_against_dummy

    async def spy_verify(*args, **kwargs):
        calls.append("verify")
        return await real_verify(*args, **kwargs)

    async def spy_dummy(*args, **kwargs):
        calls.append("dummy")
        return await real_dummy(*args, **kwargs)

    monkeypatch.setattr(passwords, "verify_password", spy_verify)
    monkeypatch.setattr(passwords, "verify_against_dummy", spy_dummy)
    async with ip_client("203.0.113.1") as c:
        await c.post(LOGIN_URL, json={"username": "alice", "password": "wrong-password-1"})
        await c.post(LOGIN_URL, json={"username": "ghost", "password": "wrong-password-1"})
        assert "verify" in calls and "dummy" in calls  # 额度内：用户存在与不存在都做哈希
        before = list(calls)
        for user in ("alice", "ghost"):
            resp = await c.post(LOGIN_URL, json={"username": user, "password": "wrong-password-1"})
            assert resp.status_code == 429
    assert calls == before  # 超限后不再做任何哈希计算


async def test_register_is_limited_per_ip(db_client, limits):
    limits("register", 2)
    async with ip_client("203.0.113.1") as a, ip_client("203.0.113.2") as b:
        # 规则校验失败（弱密码 422）也计入
        assert (await a.post(REGISTER_URL, json={"username": "u1", "password": "short"})).status_code == 422
        assert (await a.post(REGISTER_URL, json={"username": "user1", "password": DEFAULT_PASSWORD})).status_code == 201
        resp = await a.post(REGISTER_URL, json={"username": "user2", "password": DEFAULT_PASSWORD})
        assert resp.status_code == 429
        assert resp.json()["detail"] == "注册过于频繁（每分钟 2 次），请 1 分钟后再试"
        assert (await b.post(REGISTER_URL, json={"username": "user2", "password": DEFAULT_PASSWORD})).status_code == 201


async def test_forwarded_headers_are_not_trusted(db_client, limits, db_session):
    limits("login", 2)
    statuses = []
    async with ip_client("203.0.113.1") as c:
        for i in range(3):
            resp = await c.post(
                LOGIN_URL, json={"username": "ghost", "password": "wrong-password-1"},
                headers={"X-Forwarded-For": f"198.51.100.{i}", "X-Real-IP": f"198.51.100.{i}"},
            )
            statuses.append(resp.status_code)
    assert statuses == [401, 401, 429]
    assert await counters(db_session) == {("login", "ip:203.0.113.1"): 3}


async def test_change_password_is_limited_per_user(alice_client, limits, monkeypatch, db_session):
    """持有凭证的人不能无限次猜当前密码：超限后不再做哈希计算。"""
    limits("change_password", 2)
    calls = []
    real_verify = passwords.verify_password

    async def spy_verify(*args, **kwargs):
        calls.append(1)
        return await real_verify(*args, **kwargs)

    monkeypatch.setattr(passwords, "verify_password", spy_verify)
    body = {"old_password": "wrong-password-1", "new_password": "brand-new-pass-7"}
    url = "/api/v1/auth/change-password"
    assert [alice_client.post(url, json=body).status_code for _ in range(2)] == [400, 400]
    resp = alice_client.post(url, json=body)
    assert resp.status_code == 429
    assert resp.json() == {"detail": "修改密码尝试过于频繁（每分钟 2 次），请 1 分钟后再试"}
    assert resp.headers["Retry-After"] == "30"
    assert len(calls) == 2
    # 正确的原密码同样被挡住；当前凭证仍有效
    ok = {"old_password": DEFAULT_PASSWORD, "new_password": "brand-new-pass-7"}
    assert alice_client.post(url, json=ok).status_code == 429
    assert alice_client.get("/api/v1/auth/me").status_code == 200
    user = f"u:{alice_client.user['id']}"
    assert await counters(db_session, "change_password") == {("change_password", user): 4}


# ---- 计入规则（S2） -----------------------------------------------------------------

async def test_failed_and_degraded_requests_are_counted(alice_client, limits, use_ocr, upstream, use_ai, db_session):
    limits("ocr", 3)
    upstream.on(OCR_BASE, raiser(httpx.ConnectError))
    use_ocr("docker")
    assert upload(alice_client).status_code == 503  # OCR 不可用
    use_ocr("mock")
    resp = upload(alice_client)
    assert resp.status_code == 200 and resp.json()["degraded"] is True  # 降级
    bad = alice_client.post(OCR_URL, files={"file": ("a.txt", b"x", "text/plain")})
    assert bad.status_code == 400  # 非图片
    assert upload(alice_client).status_code == 429

    limits("compose", 2)
    use_ai(fallback=False, api_key="")
    assert alice_client.post(COMPOSE_URL, json={"words": ["cat"], "difficulty": "expert"}).status_code == 422
    assert alice_client.post(COMPOSE_URL, json={"words": ["cat"]}).status_code == 503  # AI 未配置
    assert alice_client.post(COMPOSE_URL, json={"words": ["cat"]}).status_code == 429

    user = f"u:{alice_client.user['id']}"
    assert await counters(db_session) == {("ocr", user): 4, ("compose", user): 3}


async def test_unauthenticated_requests_are_not_counted(db_client, limits, use_ocr, db_session):
    limits("ocr", 1)
    use_ocr("mock")
    for _ in range(3):
        assert upload(db_client).status_code == 401
        assert db_client.post(COMPOSE_URL, json={"words": ["cat"]}, headers=bearer("bogus")).status_code == 401
    assert await counters(db_session) == {}


# ---- 并发 ---------------------------------------------------------------------------

async def test_concurrent_requests_are_counted_exactly(db_client, limits, compose_ok, db_session):
    limits("compose", 5)
    token = register(db_client, "alice")["token"]
    async with ip_client("203.0.113.1", headers=bearer(token)) as c:
        responses = await asyncio.gather(*[c.post(COMPOSE_URL, json={"words": ["cat"]}) for _ in range(10)])
    statuses = sorted(r.status_code for r in responses)
    assert statuses == [200] * 5 + [429] * 5
    assert list((await counters(db_session, "compose")).values()) == [10]


# ---- 日志与开关 ------------------------------------------------------------------------

def test_429_is_logged_without_credentials(alice_client, limits, use_ocr, caplog):
    limits("ocr", 1)
    use_ocr("mock")
    upload(alice_client)
    with caplog.at_level(logging.WARNING, logger="app.ratelimit"):
        assert upload(alice_client).status_code == 429
    token = alice_client.headers["Authorization"].removeprefix("Bearer ")
    assert "rate limit exceeded: scope=ocr" in caplog.text
    assert token not in caplog.text


async def test_disabled_limiter_allows_everything(alice_client, limits, use_ocr, monkeypatch, db_session):
    limits("ocr", 1)
    monkeypatch.setattr(settings, "rate_limit_enabled", False)
    use_ocr("mock")
    assert [upload(alice_client).status_code for _ in range(3)] == [200, 200, 200]
    assert await counters(db_session) == {}


# ---- 保存记录的词表上限（与生成一致） ----------------------------------------------------

SAVE_PAYLOAD = {
    "image_url": "a.png", "english_story": "s", "chinese_translation": "t",
    "english_blank": "b", "chinese_blank": "c",
}


@pytest.mark.parametrize("words, status, detail", [
    ([f"w{i}" for i in range(20)], 200, None),
    ([f"w{i}" for i in range(21)], 422, "一次最多 20 个单词"),
    (["a" * 40], 200, None),
    (["a" * 41], 422, "单词不能超过 40 个字符：" + "a" * 20 + "…"),
])
def test_save_record_word_limits(alice_client, words, status, detail):
    resp = alice_client.post("/api/v1/history/save", json={**SAVE_PAYLOAD, "words": words})
    assert resp.status_code == status, resp.text
    if detail:
        assert resp.json() == {"detail": detail}
