"""POST /api/v1/learn/compose：正常、降级、报错、参数校验。"""
import json

import httpx
import pytest
from conftest import DEEPSEEK_BASE, deepseek_reply, raiser

URL = "/api/v1/learn/compose"
STORY = {"english": "A cat reads a book.", "chinese": "一只猫 (cat) 读书 (book)。"}
BLANKS = {"english_blank": "A ___ reads a ___.", "chinese_blank": "一只 ___ (cat) 读 ___ (book)。"}
FIELDS = {"english", "chinese", "english_blank", "chinese_blank", "degraded", "reason"}


def story_then_blanks():
    replies = [STORY, BLANKS]
    return lambda request: deepseek_reply(json.dumps(replies.pop(0), ensure_ascii=False))


# reason → (上游处理函数, HTTP 状态码, detail)；api_key=None 表示用默认测试 Key
ERRORS = {
    "ai_not_configured": (None, 503, "AI service is not configured."),
    "ai_unavailable": (raiser(httpx.ConnectError), 503, "AI service is unavailable. Please try again later."),
    "ai_timeout": (raiser(httpx.ReadTimeout), 504, "AI service timed out. Please try again."),
    "ai_upstream_error": (lambda r: httpx.Response(500), 502, "AI service returned an error. Please try again later."),
    "ai_parse_failed": (lambda r: deepseek_reply("not json"), 502, "AI returned an invalid response. Please try again."),
}


def setup_failure(upstream, use_ai, reason, fallback):
    handler = ERRORS[reason][0]
    if handler is None:
        use_ai(api_key="", fallback=fallback)
    else:
        upstream.on(DEEPSEEK_BASE, handler)
        use_ai(fallback=fallback)


# ---- 正常 -------------------------------------------------------------------

def test_compose_success(client, upstream, use_ai):
    use_ai(fallback=False)
    upstream.on(DEEPSEEK_BASE, story_then_blanks())

    resp = client.post(URL, json={"words": ["cat", "book"], "difficulty": "beginner"})

    assert resp.status_code == 200
    body = resp.json()
    assert set(body) == FIELDS
    assert body == {**STORY, **BLANKS, "degraded": False, "reason": None}
    assert len(upstream.calls(DEEPSEEK_BASE)) == 2


def test_difficulty_defaults_to_intermediate(client, upstream, use_ai):
    use_ai()
    upstream.on(DEEPSEEK_BASE, story_then_blanks())
    resp = client.post(URL, json={"words": ["cat"]})
    assert resp.status_code == 200
    story_req = upstream.calls(DEEPSEEK_BASE)[0]
    assert "Use a mix of tenses and moderate vocabulary." in story_req.content.decode()


# ---- 降级（开关打开）--------------------------------------------------------

@pytest.mark.parametrize("reason", ERRORS)
def test_compose_degraded_returns_200(client, upstream, use_ai, reason):
    setup_failure(upstream, use_ai, reason, fallback=True)

    resp = client.post(URL, json={"words": ["cat"], "difficulty": "intermediate"})

    assert resp.status_code == 200
    body = resp.json()
    assert set(body) == FIELDS
    assert body["degraded"] is True
    assert body["reason"] == reason
    assert body["english"] == "The quick brown fox jumps over the lazy dog."


# ---- 报错（开关关闭）--------------------------------------------------------

@pytest.mark.parametrize("reason", ERRORS)
def test_compose_error_maps_to_status(client, upstream, use_ai, reason):
    setup_failure(upstream, use_ai, reason, fallback=False)
    _, status, detail = ERRORS[reason]

    resp = client.post(URL, json={"words": ["cat"], "difficulty": "intermediate"})

    assert resp.status_code == status
    assert resp.json() == {"detail": detail}
    # 技术细节只进日志，不进响应
    for leak in ("Error", "simulated", "deepseek.test", "Traceback", reason):
        assert leak not in resp.text


def test_fill_blank_step_failure_maps_to_status(client, upstream, use_ai):
    use_ai(fallback=False)
    replies = [lambda r: deepseek_reply(json.dumps(STORY)), raiser(httpx.ReadTimeout)]
    upstream.on(DEEPSEEK_BASE, lambda request: replies.pop(0)(request))

    resp = client.post(URL, json={"words": ["cat"]})

    assert resp.status_code == 504
    assert len(upstream.calls(DEEPSEEK_BASE)) == 2


# ---- 参数校验 ---------------------------------------------------------------

@pytest.mark.parametrize("payload", [
    {"words": ["cat"], "difficulty": "expert"},
    {"words": ["cat"], "difficulty": "Beginner"},
    {"words": ["cat"], "difficulty": None},
    {"difficulty": "beginner"},
    {"words": "cat"},
    {"words": [1, 2]},
])
def test_invalid_payload_is_422(client, upstream, use_ai, payload):
    use_ai()
    resp = client.post(URL, json=payload)
    assert resp.status_code == 422
    assert upstream.requests == []


def test_empty_words_is_400(client, upstream, use_ai):
    use_ai()
    resp = client.post(URL, json={"words": []})
    assert resp.status_code == 400
    assert resp.json() == {"detail": "Words list cannot be empty"}
    assert upstream.requests == []
