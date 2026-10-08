"""鉴权与数据隔离（连测试库）：未登录 401；用户 A 读不到、改不了、删不掉、搜不到 B 的记录。"""
import pytest
from conftest import bearer, register

H = "/api/v1/history"

RECORD = {
    "image_url": "b.jpg",
    "words": ["zephyr"],
    "english_story": "Bob wrote about a zephyr.",
    "chinese_translation": "鲍勃写了一阵和风 (zephyr)。",
    "english_blank": "Bob wrote about a ___.",
    "chinese_blank": "鲍勃写了一阵 ___ (zephyr)。",
}

BUSINESS_ENDPOINTS = [
    ("post", "/api/v1/ocr/recognize"),
    ("post", "/api/v1/learn/compose"),
    ("post", f"{H}/save"),
    ("get", f"{H}/records"),
    ("get", f"{H}/records/1"),
    ("put", f"{H}/records/1"),
    ("delete", f"{H}/records/1"),
    ("post", "/api/v1/auth/logout"),
    ("get", "/api/v1/auth/me"),
    ("post", "/api/v1/auth/change-password"),
]


@pytest.mark.parametrize("method, path", BUSINESS_ENDPOINTS)
def test_business_endpoints_require_login(db_client, upstream, method, path):
    resp = getattr(db_client, method)(path)
    assert resp.status_code == 401
    assert resp.json() == {"detail": "请先登录"}
    assert resp.headers["www-authenticate"] == "Bearer"
    assert upstream.requests == []  # 没有调用 OCR / DeepSeek


@pytest.mark.parametrize("method, path", BUSINESS_ENDPOINTS)
def test_business_endpoints_reject_invalid_token(db_client, method, path):
    resp = getattr(db_client, method)(path, headers=bearer("not-a-valid-token"))
    assert resp.status_code == 401
    assert resp.json() == {"detail": "登录已失效，请重新登录"}


def test_public_endpoints_need_no_login(db_client):
    assert db_client.get("/health").status_code == 200
    assert db_client.get("/").status_code == 200


@pytest.fixture
def two_users(db_client):
    alice = register(db_client, "alice")
    bob = register(db_client, "bob")
    resp = db_client.post(f"{H}/save", json=RECORD, headers=bearer(bob["token"]))
    assert resp.status_code == 200
    return {"alice": bearer(alice["token"]), "bob": bearer(bob["token"]), "bob_record": resp.json()["id"]}


def test_user_cannot_read_update_or_delete_others_record(db_client, two_users):
    a, rid = two_users["alice"], two_users["bob_record"]

    for resp in (
        db_client.get(f"{H}/records/{rid}", headers=a),
        db_client.put(f"{H}/records/{rid}", headers=a, json={"is_favorite": True, "notes": "hijack"}),
        db_client.delete(f"{H}/records/{rid}", headers=a),
    ):
        assert resp.status_code == 404
        assert resp.json() == {"detail": "记录不存在"}

    rec = db_client.get(f"{H}/records/{rid}", headers=two_users["bob"]).json()
    assert rec["is_favorite"] == 0 and rec["notes"] is None


def test_user_cannot_list_or_search_others_records(db_client, two_users):
    a = two_users["alice"]
    for params in ({}, {"search": "zephyr"}, {"search": "Bob"}):
        body = db_client.get(f"{H}/records", headers=a, params=params).json()
        assert body["total"] == 0 and body["records"] == []
    assert db_client.get(f"{H}/records", headers=two_users["bob"]).json()["total"] == 1


def test_user_id_from_request_is_ignored(db_client, two_users):
    """user_id 只来自服务端校验后的凭证；请求体和查询参数里的 user_id 一律无效。"""
    a, b = two_users["alice"], two_users["bob"]
    bob_id = db_client.get("/api/v1/auth/me", headers=b).json()["id"]

    resp = db_client.post(f"{H}/save", headers=a, json={**RECORD, "english_story": "alice's", "user_id": bob_id})
    assert resp.status_code == 200
    assert db_client.get(f"{H}/records", headers=b).json()["total"] == 1  # 没有写到 bob 名下
    assert db_client.get(f"{H}/records", headers=a, params={"user_id": bob_id}).json()["total"] == 1
    assert db_client.get(f"{H}/records/{two_users['bob_record']}", headers=a,
                         params={"user_id": bob_id}).status_code == 404
