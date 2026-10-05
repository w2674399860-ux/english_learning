import logging
import time
from app.services.ai_service import AIService

logger = logging.getLogger(__name__)


class LearnService:
    """一次完成"写短文 → 挖空"。生产模式下任一步失败抛 AIServiceError，由路由映射为 HTTP 错误。"""

    def __init__(self, ai_service: AIService):
        self.ai = ai_service

    async def compose(self, words: list[str], difficulty: str) -> dict:
        started = time.perf_counter()
        story = await self.ai.generate_story(words, difficulty)
        story_seconds = time.perf_counter() - started

        if story["degraded"]:
            # 写短文已降级说明 AI 多半不可用：不再发第二次调用（超时场景下会再等一轮），
            # 也避免用真实 AI 去挖示例故事。
            blanks = self.ai.mock_fill_blank(story["reason"])
        else:
            blanks = await self.ai.generate_fill_blank(story["english"], story["chinese"], words)
        total_seconds = time.perf_counter() - started

        reason = story["reason"] or blanks["reason"]
        logger.info(
            "compose done: %d words, difficulty=%s, story=%.1fs, fill_blank=%.1fs, total=%.1fs, reason=%s",
            len(words), difficulty, story_seconds, total_seconds - story_seconds, total_seconds, reason,
        )
        return {
            "english": story["english"],
            "chinese": story["chinese"],
            "english_blank": blanks["english_blank"],
            "chinese_blank": blanks["chinese_blank"],
            "degraded": reason is not None,
            "reason": reason,
        }
