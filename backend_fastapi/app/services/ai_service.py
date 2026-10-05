import json
import logging
import re
import httpx
from app.core.config import settings

logger = logging.getLogger(__name__)

_FENCE_RE = re.compile(r"^```[A-Za-z]*\s*\n?(.*?)\n?\s*```$", re.DOTALL)
_OBJECT_RE = re.compile(r"\{.*\}", re.DOTALL)

_DEEPSEEK_TIMEOUT = httpx.Timeout(60.0, connect=10.0)

_MOCK_FILL_BLANK = {
    "english_blank": "The ___ cat ___ over the wall.",
    "chinese_blank": "那只 ___ (cat) ___ (jumped) 过了那堵 ___ (wall)。",
}


class AIParseError(Exception):
    """模型输出无法解析为所需的 JSON 对象。交给降级逻辑处理，不直接 500。"""


def _summary(content, limit: int = 200) -> str:
    text = repr(content)
    return text if len(text) <= limit else text[:limit] + "..."


def parse_ai_json(content, required_keys: tuple[str, ...]) -> dict:
    """解析模型输出：先剥离代码围栏，失败再用正则提取第一个 {...} 片段。

    解析失败、结果不是对象、或必需字段缺失 / 不是字符串时抛 AIParseError。
    """
    if not isinstance(content, str):
        raise AIParseError(f"content is not a string: {type(content).__name__}")

    text = content.strip()
    fenced = _FENCE_RE.match(text)
    if fenced:
        text = fenced.group(1).strip()

    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        match = _OBJECT_RE.search(text)
        if not match:
            raise AIParseError("no JSON object found")
        try:
            data = json.loads(match.group(0))
        except json.JSONDecodeError as e:
            raise AIParseError(f"invalid JSON: {e.msg}")

    if not isinstance(data, dict):
        raise AIParseError(f"expected a JSON object, got {type(data).__name__}")

    bad = [k for k in required_keys if not isinstance(data.get(k), str)]
    if bad:
        raise AIParseError(f"missing or non-string fields: {', '.join(bad)}")
    return data


class AIServiceError(Exception):
    """AI 调用失败。reason 取值：ai_not_configured / ai_unavailable / ai_timeout /
    ai_upstream_error / ai_parse_failed，由路由层映射为 HTTP 状态码。"""

    def __init__(self, reason: str, message: str = ""):
        super().__init__(message or reason)
        self.reason = reason


def _with_degradation(data: dict, reason: str | None) -> dict:
    return {**data, "degraded": reason is not None, "reason": reason}


class AIService:
    def __init__(self):
        self.api_key = settings.deepseek_api_key
        self.api_base = settings.deepseek_api_base
        self.model = "deepseek-chat"
        self.fallback_enabled = settings.ai_fallback_enabled
        if self.fallback_enabled:
            logger.warning(
                "AI fallback is ENABLED (ai_fallback_enabled=true): AI failures return "
                "mock responses marked degraded. Do not use this in production."
            )

    def _configured(self) -> bool:
        return bool(self.api_key) and self.api_key not in (
            "your_deepseek_api_key_here", "sk-your_deepseek_api_key_here",
        )

    async def _call_deepseek(self, messages: list) -> str:
        """调用 DeepSeek 并返回模型输出文本。任何失败都抛 AIServiceError，不在这里降级。"""
        if not self._configured():
            raise AIServiceError("ai_not_configured", "DeepSeek API key is not configured")

        try:
            # 单次调用 60 秒：/learn/compose 串行两次约 120 秒，须小于前端 receiveTimeout（180 秒）
            async with httpx.AsyncClient(timeout=_DEEPSEEK_TIMEOUT) as client:
                response = await client.post(
                    f"{self.api_base}/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": self.model,
                        "messages": messages,
                        "temperature": 0.7,
                        "max_tokens": 2000,
                    },
                )
                response.raise_for_status()
        except httpx.TimeoutException as e:
            raise AIServiceError("ai_timeout", f"{type(e).__name__}: {e}") from e
        except httpx.HTTPStatusError as e:
            raise AIServiceError(
                "ai_upstream_error", f"upstream returned HTTP {e.response.status_code}"
            ) from e
        except httpx.TransportError as e:
            raise AIServiceError("ai_unavailable", f"{type(e).__name__}: {e}") from e

        try:
            return response.json()["choices"][0]["message"]["content"]
        except (ValueError, KeyError, IndexError, TypeError) as e:
            raise AIServiceError(
                "ai_parse_failed", f"unexpected response envelope ({type(e).__name__}: {e})"
            ) from e

    async def _complete_json(self, messages: list, required_keys: tuple[str, ...]) -> tuple[dict, str | None]:
        """返回 (结果, 降级 reason)，未降级时 reason 为 None。

        失败时：降级开关打开 → 回落 mock 并返回 reason；关闭 → 抛 AIServiceError。
        """
        try:
            content = await self._call_deepseek(messages)
            try:
                return parse_ai_json(content, required_keys), None
            except AIParseError as e:
                raise AIServiceError("ai_parse_failed", f"{e}; content={_summary(content)}") from e
        except AIServiceError as e:
            if not self.fallback_enabled:
                logger.error("AI call failed [%s]: %s", e.reason, e)
                raise
            logger.warning("AI call failed [%s]: %s; falling back to mock response", e.reason, e)
            return parse_ai_json(self._mock_response(messages), required_keys), e.reason

    def _mock_response(self, messages: list) -> str:
        prompt = messages[-1]["content"] if messages else ""
        if any(kw in prompt.lower() for kw in ["fill in the blank", "fill-in-the-blank", "填空", "fill blank"]):
            return json.dumps(_MOCK_FILL_BLANK)
        else:
            return json.dumps({
                "english": "The quick brown fox jumps over the lazy dog.",
                "chinese": "敏捷的 (quick) 棕色 (brown) 狐狸 (fox) 跳过了 (jumps over) 懒洋洋的 (lazy) 狗 (dog)。",
            })

    def mock_fill_blank(self, reason: str) -> dict:
        """不调用 AI，直接返回带降级标记的 mock 填空。供 /learn/compose 在写短文已降级时跳过第二次调用。"""
        return _with_degradation(dict(_MOCK_FILL_BLANK), reason)

    async def generate_story(self, words: list[str], difficulty: str = "intermediate") -> dict:
        difficulty_prompts = {
            "beginner": "Use simple present tense and basic vocabulary.",
            "intermediate": "Use a mix of tenses and moderate vocabulary.",
            "advanced": "Use complex grammar and advanced vocabulary.",
        }
        prompt = (
            f"Create a short English story using ALL of these words: {', '.join(words)}.\n"
            f"Difficulty: {difficulty_prompts.get(difficulty, difficulty_prompts['intermediate'])}\n"
            "Then translate the story to Chinese.\n"
            "IMPORTANT: In the Chinese translation, for each vocabulary word listed above, "
            "include the original English word in parentheses immediately after its Chinese "
            "equivalent. For example, if a vocabulary word is 'apple', write '苹果 (apple)' "
            "instead of just '苹果'. If the same word appears multiple times, include the "
            "parenthetical at least on its first occurrence.\n"
            "Return ONLY a JSON object with keys 'english' and 'chinese'."
        )

        messages = [
            {"role": "system", "content": "You are an English teacher. Always respond in valid JSON."},
            {"role": "user", "content": prompt},
        ]
        data, reason = await self._complete_json(messages, ("english", "chinese"))
        return _with_degradation(data, reason)

    async def generate_fill_blank(self, english: str, chinese: str, words: list[str] = None) -> dict:
        words_instruction = ""
        if words:
            words_instruction = (
                f"3. The EXACT words to blank out are: {', '.join(words)}.\n"
                "Every single one of these words MUST be replaced with '___' wherever they appear "
                "in the English text (including different grammatical forms like plurals or past tense), "
                "and their corresponding translations must be blanked in the Chinese text.\n"
            )

        prompt = (
            f"Based on this English text:\n{english}\n\n"
            f"And its Chinese translation:\n{chinese}\n\n"
            "Create fill-in-the-blank exercises:\n"
            "1. Replace ALL specified words with '___' in the English text\n"
            "2. Replace corresponding words with '___' in the Chinese text\n"
            f"{words_instruction}"
            "Make sure EVERY specified word is blanked out on every occurrence.\n"
            "Return ONLY a JSON object with keys 'english_blank' and 'chinese_blank'."
        )

        messages = [
            {"role": "system", "content": "You are an English teacher. Always respond in valid JSON."},
            {"role": "user", "content": prompt},
        ]
        data, reason = await self._complete_json(messages, ("english_blank", "chinese_blank"))
        return _with_degradation(data, reason)
