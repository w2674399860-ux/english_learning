"""第一段收尾自查的修复（不连数据库）。

- P1：参数校验错误（422）不回显请求中的原值（密码等）
- P2：保存记录、修改备注的字段长度上限，超长返回 422 而不是数据库报错 500
- P3：数据库报错信息中不带 SQL 参数
"""
import pytest

from app.db.session import make_engine
from app.schemas import history as history_schemas

SECRET = "S3CRET-pass-word"


# ---- P1 --------------------------------------------------------------------------

@pytest.mark.parametrize("url, body", [
    ("/api/v1/auth/login", {"username": "alice", "password": SECRET + "x" * 1100}),  # 超长
    ("/api/v1/auth/login", {"username": "alice", "password": 12345678}),  # 类型错误
    ("/api/v1/auth/login", {"password": SECRET}),  # 缺字段：错误项的 input 是整个请求体
    ("/api/v1/auth/register", {"username": ["x"], "password": SECRET}),
    ("/api/v1/auth/register", {"password": SECRET}),
    ("/api/v1/auth/change-password", {"old_password": SECRET, "new_password": 87654321}),
    ("/api/v1/auth/change-password", {"old_password": SECRET}),
])
def test_validation_errors_do_not_echo_input(client, url, body):
    resp = client.post(url, json=body)
    assert resp.status_code == 422
    assert SECRET not in resp.text
    assert "12345678" not in resp.text and "87654321" not in resp.text
    for item in resp.json()["detail"]:
        assert set(item) == {"type", "loc", "msg"}


def test_validation_error_structure_is_kept(client):
    resp = client.post("/api/v1/learn/compose", json={"words": ["cat"], "difficulty": "expert"})
    assert resp.status_code == 422
    [item] = resp.json()["detail"]
    assert item["type"] == "literal_error"
    assert item["loc"] == ["body", "difficulty"]
    assert item["msg"]


def test_invalid_json_body_does_not_echo(client):
    resp = client.post("/api/v1/auth/login", content=b'{"username": "a", "password": "' + SECRET.encode() + b'"',
                       headers={"Content-Type": "application/json"})
    assert resp.status_code == 422
    assert SECRET not in resp.text


def test_query_param_errors_do_not_echo(client):
    resp = client.get("/api/v1/history/records", params={"page": SECRET})
    assert resp.status_code == 422
    assert SECRET not in resp.text


# ---- P2 --------------------------------------------------------------------------

BASE = {
    "image_url": "a.png", "words": ["cat"], "english_story": "s", "chinese_translation": "t",
    "english_blank": "b", "chinese_blank": "c",
}
TEXT_FIELDS = ["english_story", "chinese_translation", "english_blank", "chinese_blank"]


def test_limits_fit_columns():
    # image_name VARCHAR(255)；TEXT 最多 65535 字节，utf8mb4 每字符最多 4 字节
    assert history_schemas.MAX_IMAGE_NAME_LENGTH == 255
    assert history_schemas.MAX_TEXT_LENGTH * 4 <= 65535
    assert history_schemas.MAX_NOTES_LENGTH * 4 <= 65535


@pytest.mark.parametrize("field, limit", [("image_url", 255)] + [(f, 16000) for f in TEXT_FIELDS])
def test_save_request_field_limits(field, limit):
    history_schemas.SaveRecordRequest(**{**BASE, field: "字" * limit})
    with pytest.raises(ValueError):
        history_schemas.SaveRecordRequest(**{**BASE, field: "字" * (limit + 1)})


def test_update_request_notes_limit():
    history_schemas.UpdateRecordRequest(notes="字" * 2000)
    with pytest.raises(ValueError):
        history_schemas.UpdateRecordRequest(notes="字" * 2001)


@pytest.mark.parametrize("field", ["image_url"] + TEXT_FIELDS)
def test_oversized_save_is_422_not_500(client, field):
    """超长在请求校验阶段就被拒绝，不会到数据库（client 不连库也能验证）。"""
    resp = client.post("/api/v1/history/save", json={**BASE, field: "a" * 16001})
    assert resp.status_code == 422
    assert resp.json()["detail"][0]["loc"] == ["body", field]


def test_oversized_notes_is_422_not_500(client):
    resp = client.put("/api/v1/history/records/1", json={"notes": "n" * 2001})
    assert resp.status_code == 422
    assert resp.json()["detail"][0]["loc"] == ["body", "notes"]


# ---- P3 --------------------------------------------------------------------------

def test_engine_hides_sql_parameters():
    engine = make_engine("mysql+asyncmy://u:p@127.0.0.1:3307/english_learning_test")
    assert engine.sync_engine.hide_parameters is True
