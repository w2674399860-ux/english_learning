import json
import httpx
from app.core.config import settings


class AIService:
    def __init__(self):
        self.api_key = settings.deepseek_api_key
        self.api_base = settings.deepseek_api_base
        self.model = "deepseek-chat"

    async def _call_deepseek(self, messages: list) -> str:
        if not self.api_key or self.api_key == "your_deepseek_api_key_here":
            return self._mock_response(messages)

        async with httpx.AsyncClient(timeout=120.0) as client:
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
            data = response.json()
            return data["choices"][0]["message"]["content"]

    def _mock_response(self, messages: list) -> str:
        prompt = messages[-1]["content"] if messages else ""
        if any(kw in prompt.lower() for kw in ["fill in the blank", "fill-in-the-blank", "填空", "fill blank"]):
            return json.dumps({
                "english_blank": "The ___ cat ___ over the wall.",
                "chinese_blank": "那只 ___ (cat) ___ (jumped) 过了那堵 ___ (wall)。",
            })
        else:
            return json.dumps({
                "english": "The quick brown fox jumps over the lazy dog.",
                "chinese": "敏捷的 (quick) 棕色 (brown) 狐狸 (fox) 跳过了 (jumps over) 懒洋洋的 (lazy) 狗 (dog)。",
            })

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

        content = await self._call_deepseek([
            {"role": "system", "content": "You are an English teacher. Always respond in valid JSON."},
            {"role": "user", "content": prompt},
        ])

        return json.loads(content)

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

        content = await self._call_deepseek([
            {"role": "system", "content": "You are an English teacher. Always respond in valid JSON."},
            {"role": "user", "content": prompt},
        ])

        return json.loads(content)
