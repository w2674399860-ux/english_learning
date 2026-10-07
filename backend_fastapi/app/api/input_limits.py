"""词表输入上限（S-5）。超限返回 422 与字符串 detail（pydantic 校验的 detail 是数组，前端无法直接展示）。"""
from fastapi import HTTPException

from app.core.config import settings

_PREVIEW_CHARS = 20


def check_word_list(words: list[str]) -> None:
    if len(words) > settings.compose_max_words:
        raise HTTPException(status_code=422, detail=f"一次最多 {settings.compose_max_words} 个单词")
    for word in words:
        if len(word) > settings.compose_max_word_length:
            preview = word if len(word) <= _PREVIEW_CHARS else word[:_PREVIEW_CHARS] + "…"
            raise HTTPException(
                status_code=422,
                detail=f"单词不能超过 {settings.compose_max_word_length} 个字符：{preview}",
            )
