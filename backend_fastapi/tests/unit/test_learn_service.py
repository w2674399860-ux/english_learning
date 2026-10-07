"""LearnService.compose：写短文 → 挖空的编排与降级传递。"""
import json

import httpx
import pytest
from conftest import DEEPSEEK_BASE, deepseek_reply

from app.services.ai_service import AIServiceError
from app.services.learn_service import LearnService

STORY = {"english": "A cat reads a book.", "chinese": "一只猫 (cat) 读书 (book)。"}
BLANKS = {"english_blank": "A ___ reads a ___.", "chinese_blank": "一只 ___ (cat) 读 ___ (book)。"}


def sequence(*steps):
    """按调用顺序依次使用处理函数；步骤可以是 dict（作为模型输出）或 httpx 异常类型。"""
    steps = list(steps)

    def handler(request: httpx.Request):
        step = steps.pop(0)
        if isinstance(step, dict):
            return deepseek_reply(json.dumps(step, ensure_ascii=False))
        raise step("simulated", request=request)

    return handler


@pytest.mark.parametrize("fallback", [False, True])
async def test_compose_success_makes_two_calls(upstream, make_ai_service, fallback):
    upstream.on(DEEPSEEK_BASE, sequence(STORY, BLANKS))
    result = await LearnService(make_ai_service(fallback=fallback)).compose(["cat", "book"], "advanced")

    assert result == {**STORY, **BLANKS, "degraded": False, "reason": None}
    story_req, blank_req = upstream.calls(DEEPSEEK_BASE)
    assert "Use complex grammar and advanced vocabulary." in story_req.content.decode()
    blank_prompt = json.loads(blank_req.content)["messages"][-1]["content"]
    assert STORY["english"] in blank_prompt
    assert "cat, book" in blank_prompt


async def test_story_degraded_skips_second_call(upstream, make_ai_service):
    upstream.on(DEEPSEEK_BASE, sequence(httpx.ReadTimeout))
    result = await LearnService(make_ai_service(fallback=True)).compose(["cat"], "intermediate")

    assert len(upstream.calls(DEEPSEEK_BASE)) == 1
    assert result["degraded"] is True
    assert result["reason"] == "ai_timeout"
    assert result["english"] == "The quick brown fox jumps over the lazy dog."
    assert result["english_blank"] == "The ___ cat ___ over the wall."


async def test_fill_blank_degraded_only(upstream, make_ai_service):
    upstream.on(DEEPSEEK_BASE, sequence(STORY, httpx.ConnectError))
    result = await LearnService(make_ai_service(fallback=True)).compose(["cat"], "intermediate")

    assert len(upstream.calls(DEEPSEEK_BASE)) == 2
    assert result["english"] == STORY["english"]
    assert result["english_blank"] == "The ___ cat ___ over the wall."
    assert result["degraded"] is True
    assert result["reason"] == "ai_unavailable"


async def test_not_configured_degrades_without_calls(upstream, make_ai_service):
    result = await LearnService(make_ai_service(api_key="", fallback=True)).compose(["cat"], "beginner")
    assert upstream.requests == []
    assert result["degraded"] is True and result["reason"] == "ai_not_configured"


async def test_story_failure_raises_in_production(upstream, make_ai_service):
    upstream.on(DEEPSEEK_BASE, sequence(httpx.ConnectError))
    with pytest.raises(AIServiceError) as exc:
        await LearnService(make_ai_service(fallback=False)).compose(["cat"], "intermediate")
    assert exc.value.reason == "ai_unavailable"
    assert len(upstream.calls(DEEPSEEK_BASE)) == 1


async def test_fill_blank_failure_raises_in_production(upstream, make_ai_service):
    upstream.on(DEEPSEEK_BASE, sequence(STORY, httpx.ReadTimeout))
    with pytest.raises(AIServiceError) as exc:
        await LearnService(make_ai_service(fallback=False)).compose(["cat"], "intermediate")
    assert exc.value.reason == "ai_timeout"
    assert len(upstream.calls(DEEPSEEK_BASE)) == 2
