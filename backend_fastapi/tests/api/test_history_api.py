"""/api/v1/history/*（MySQL）：增删改查、参数校验、响应结构与前端兼容（以 alice 登录）。"""
import re

import pytest

BASE = "/api/v1/history"
ISO_UTC = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$")

PAYLOAD = {
    "image_url": "photo.jpg",
    "words": ["apple", "library"],
    "english_story": "I read a book about an apple in the library.",
    "chinese_translation": "我在图书馆 (library) 读了一本关于苹果 (apple) 的书。",
    "english_blank": "I read a book about an ___ in the ___.",
    "chinese_blank": "我在 ___ (library) 读了一本关于 ___ (apple) 的书。",
}


def save(client, **overrides):
    resp = client.post(f"{BASE}/save", json={**PAYLOAD, **overrides})
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


# ---- 增删改查 ---------------------------------------------------------------

def test_crud_roundtrip(alice_client):
    resp = alice_client.post(f"{BASE}/save", json=PAYLOAD)
    assert resp.status_code == 200
    assert resp.json() == {"id": resp.json()["id"], "message": "已保存"}
    rec_id = resp.json()["id"]

    rec = alice_client.get(f"{BASE}/records/{rec_id}").json()
    assert rec["english_story"] == PAYLOAD["english_story"]

    resp = alice_client.put(f"{BASE}/records/{rec_id}", json={"is_favorite": True, "notes": "复习"})
    assert resp.status_code == 200
    rec = alice_client.get(f"{BASE}/records/{rec_id}").json()
    assert rec["is_favorite"] == 1 and rec["notes"] == "复习"

    assert alice_client.delete(f"{BASE}/records/{rec_id}").status_code == 200
    assert alice_client.get(f"{BASE}/records/{rec_id}").status_code == 404


def test_response_shape_is_frontend_compatible(alice_client):
    """前端 LearningRecord.fromJson 读 image_url、整数 is_favorite、字符串 created_at（D-1 兼容层）。"""
    rec_id = save(alice_client)
    rec = alice_client.get(f"{BASE}/records/{rec_id}").json()
    assert set(rec) == {
        "id", "image_url", "words", "difficulty", "is_degraded", "english_story",
        "chinese_translation", "english_blank", "chinese_blank", "is_favorite",
        "notes", "created_at", "updated_at",
    }
    assert rec["image_url"] == "photo.jpg"
    assert rec["is_favorite"] == 0 and type(rec["is_favorite"]) is int
    assert rec["is_degraded"] is False
    assert rec["difficulty"] == "intermediate"
    assert rec["words"] == ["apple", "library"]
    assert ISO_UTC.match(rec["created_at"]), rec["created_at"]
    assert ISO_UTC.match(rec["updated_at"]), rec["updated_at"]

    listing = alice_client.get(f"{BASE}/records").json()
    assert set(listing) == {"records", "total", "page", "page_size"}
    assert listing["records"][0] == rec


def test_save_accepts_optional_difficulty_and_degraded(alice_client):
    rec_id = save(alice_client, difficulty="beginner", is_degraded=True)
    rec = alice_client.get(f"{BASE}/records/{rec_id}").json()
    assert rec["difficulty"] == "beginner" and rec["is_degraded"] is True


@pytest.mark.parametrize("overrides", [{"difficulty": "expert"}, {"words": "apple"}, {"english_story": None}])
def test_save_invalid_payload_is_422(alice_client, overrides):
    assert alice_client.post(f"{BASE}/save", json={**PAYLOAD, **overrides}).status_code == 422


# ---- 列表：分页、搜索、参数校验 ---------------------------------------------

def test_list_pagination(alice_client):
    ids = [save(alice_client, english_story=f"story {i}") for i in range(5)]
    body = alice_client.get(f"{BASE}/records", params={"page": 2, "page_size": 2}).json()
    assert body["total"] == 5 and body["page"] == 2 and body["page_size"] == 2
    assert [r["id"] for r in body["records"]] == sorted(ids, reverse=True)[2:4]


@pytest.mark.parametrize("term, expected", [("_", "snake_case"), ("%", "100% sure")])
def test_list_search_wildcards_are_literal(alice_client, term, expected):
    for story in ("snake_case", "100% sure", "plain text"):
        save(alice_client, english_story=story)
    body = alice_client.get(f"{BASE}/records", params={"search": term}).json()
    assert body["total"] == 1
    assert body["records"][0]["english_story"] == expected


@pytest.mark.parametrize("params", [
    {"page": 0}, {"page": -1}, {"page": "a"}, {"page": 10_001},
    {"page_size": 0}, {"page_size": 51}, {"page_size": "x"},
    {"search": "a" * 101},
])
def test_list_invalid_params_are_422(alice_client, params):
    assert alice_client.get(f"{BASE}/records", params=params).status_code == 422


@pytest.mark.parametrize("params", [{"page": 10_000}, {"page_size": 50}, {"page_size": 1}, {"search": "a" * 100}])
def test_list_boundary_params_are_ok(alice_client, params):
    assert alice_client.get(f"{BASE}/records", params=params).status_code == 200


# ---- 不存在的记录 -----------------------------------------------------------

@pytest.mark.parametrize("method", ["get", "delete"])
def test_missing_record_is_404(alice_client, method):
    resp = getattr(alice_client, method)(f"{BASE}/records/999999")
    assert resp.status_code == 404
    assert resp.json() == {"detail": "记录不存在"}


def test_update_missing_record_is_404(alice_client):
    resp = alice_client.put(f"{BASE}/records/999999", json={"is_favorite": True})
    assert resp.status_code == 404
