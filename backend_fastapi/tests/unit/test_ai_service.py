"""AIService：调用 DeepSeek、失败分类、降级与报错两种模式、日志脱敏。"""
import json
import logging

import httpx
import pytest
from conftest import DEEPSEEK_BASE, TEST_API_KEY, deepseek_reply, raiser

from app.services.ai_service import AIServiceError

STORY_JSON = json.dumps({"english": "A cat reads a book.", "chinese": "一只猫 (cat) 读书 (book)。"})
BLANK_JSON = json.dumps({"english_blank": "A ___ reads a ___.", "chinese_blank": "一只 ___ (cat) 读 ___ (book)。"})


def ok(content):
    return lambda request: deepseek_reply(content)


# (处理函数, 期望 reason)：第二阶段 A-3 临时脚本的失败类型
FAILURES = {
    "read_timeout": (raiser(httpx.ReadTimeout), "ai_timeout"),
    "connect_timeout": (raiser(httpx.ConnectTimeout), "ai_timeout"),
    "connect_error": (raiser(httpx.ConnectError), "ai_unavailable"),
    "read_error": (raiser(httpx.ReadError), "ai_unavailable"),
    "http_500": (lambda r: httpx.Response(500, text="boom"), "ai_upstream_error"),
    "http_401": (lambda r: httpx.Response(401, json={"error": "invalid key"}), "ai_upstream_error"),
    "envelope_not_json": (lambda r: httpx.Response(200, text="<html>gateway</html>"), "ai_parse_failed"),
    "envelope_no_choices": (lambda r: httpx.Response(200, json={"id": "x"}), "ai_parse_failed"),
    "envelope_empty_choices": (lambda r: httpx.Response(200, json={"choices": []}), "ai_parse_failed"),
    "content_not_json": (ok("I'm sorry, I can't do that."), "ai_parse_failed"),
    "content_missing_field": (ok('{"english": "only english"}'), "ai_parse_failed"),
}


# ---- 正常路径 ---------------------------------------------------------------

async def test_generate_story_success(upstream, make_ai_service):
    upstream.on(DEEPSEEK_BASE, ok(f"```json\n{STORY_JSON}\n```"))
    service = make_ai_service()

    result = await service.generate_story(["cat", "book"], "beginner")

    assert result == {**json.loads(STORY_JSON), "degraded": False, "reason": None}
    [request] = upstream.calls(DEEPSEEK_BASE)
    assert request.url.path == "/v1/chat/completions"
    assert request.headers["Authorization"] == f"Bearer {TEST_API_KEY}"
    body = json.loads(request.content)
    assert body["model"] == "deepseek-chat"
    prompt = body["messages"][-1]["content"]
    assert "cat, book" in prompt
    assert "Use simple present tense and basic vocabulary." in prompt


@pytest.mark.parametrize("difficulty, phrase", [
    ("beginner", "Use simple present tense and basic vocabulary."),
    ("intermediate", "Use a mix of tenses and moderate vocabulary."),
    ("advanced", "Use complex grammar and advanced vocabulary."),
])
async def test_difficulty_reaches_prompt(upstream, make_ai_service, difficulty, phrase):
    upstream.on(DEEPSEEK_BASE, ok(STORY_JSON))
    await make_ai_service().generate_story(["cat"], difficulty)
    [request] = upstream.calls(DEEPSEEK_BASE)
    assert phrase in json.loads(request.content)["messages"][-1]["content"]


async def test_generate_fill_blank_success(upstream, make_ai_service):
    upstream.on(DEEPSEEK_BASE, ok(BLANK_JSON))
    result = await make_ai_service().generate_fill_blank("A cat reads a book.", "……", ["cat", "book"])
    assert result == {**json.loads(BLANK_JSON), "degraded": False, "reason": None}
    prompt = json.loads(upstream.calls(DEEPSEEK_BASE)[0].content)["messages"][-1]["content"]
    assert "The EXACT words to blank out are: cat, book." in prompt


# ---- 未配置 -----------------------------------------------------------------

@pytest.mark.parametrize("api_key", ["", "your_deepseek_api_key_here", "sk-your_deepseek_api_key_here"])
async def test_not_configured_raises_without_request(upstream, make_ai_service, api_key):
    service = make_ai_service(api_key=api_key, fallback=False)
    with pytest.raises(AIServiceError) as exc:
        await service.generate_story(["cat"])
    assert exc.value.reason == "ai_not_configured"
    assert upstream.requests == []


@pytest.mark.parametrize("api_key", ["", "sk-your_deepseek_api_key_here"])
async def test_not_configured_degrades_without_request(upstream, make_ai_service, api_key):
    service = make_ai_service(api_key=api_key, fallback=True)
    result = await service.generate_story(["cat"])
    assert result["degraded"] is True
    assert result["reason"] == "ai_not_configured"
    assert result["english"] == "The quick brown fox jumps over the lazy dog."
    assert upstream.requests == []


# ---- 失败类型 × 降级开关 ----------------------------------------------------

@pytest.mark.parametrize("case", FAILURES)
async def test_failure_raises_when_fallback_disabled(upstream, make_ai_service, caplog, case):
    handler, reason = FAILURES[case]
    upstream.on(DEEPSEEK_BASE, handler)
    service = make_ai_service(fallback=False)

    with caplog.at_level(logging.WARNING, logger="app.services.ai_service"):
        with pytest.raises(AIServiceError) as exc:
            await service.generate_story(["cat"])

    assert exc.value.reason == reason
    records = [r for r in caplog.records if r.name == "app.services.ai_service"]
    assert [r.levelno for r in records] == [logging.ERROR]
    assert reason in records[0].getMessage()


@pytest.mark.parametrize("case", FAILURES)
async def test_failure_degrades_when_fallback_enabled(upstream, make_ai_service, caplog, case):
    handler, reason = FAILURES[case]
    upstream.on(DEEPSEEK_BASE, handler)
    service = make_ai_service(fallback=True)

    with caplog.at_level(logging.WARNING, logger="app.services.ai_service"):
        result = await service.generate_story(["cat"])

    assert result["degraded"] is True
    assert result["reason"] == reason
    assert result["english"] == "The quick brown fox jumps over the lazy dog."
    assert "chinese" in result
    levels = [r.levelno for r in caplog.records if "AI call failed" in r.getMessage()]
    assert levels == [logging.WARNING]


async def test_fill_blank_degrades_to_fill_blank_mock(upstream, make_ai_service):
    upstream.on(DEEPSEEK_BASE, raiser(httpx.ConnectError))
    result = await make_ai_service(fallback=True).generate_fill_blank("A cat.", "一只猫。", ["cat"])
    assert result["degraded"] is True
    assert result["reason"] == "ai_unavailable"
    assert result["english_blank"] == "The ___ cat ___ over the wall."
    assert "chinese_blank" in result


def test_mock_fill_blank_carries_reason(make_ai_service):
    result = make_ai_service().mock_fill_blank("ai_timeout")
    assert result["degraded"] is True and result["reason"] == "ai_timeout"
    assert set(result) == {"english_blank", "chinese_blank", "degraded", "reason"}


# ---- 日志脱敏 ---------------------------------------------------------------

@pytest.mark.parametrize("fallback", [False, True])
@pytest.mark.parametrize("case", FAILURES)
async def test_logs_never_contain_credentials(upstream, make_ai_service, caplog, case, fallback):
    handler, _ = FAILURES[case]
    upstream.on(DEEPSEEK_BASE, handler)
    service = make_ai_service(fallback=fallback)

    with caplog.at_level(logging.DEBUG):
        try:
            await service.generate_story(["cat"])
        except AIServiceError:
            pass

    text = caplog.text
    assert TEST_API_KEY not in text
    assert "Bearer" not in text
    assert "Authorization" not in text
