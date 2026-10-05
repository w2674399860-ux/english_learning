from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
from app.api.errors import ai_http_error
from app.schemas.common import DegradableResponse
from app.services.ai_service import AIService, AIServiceError

router = APIRouter()
ai_service = AIService()


class StoryRequest(BaseModel):
    words: List[str]
    difficulty: str = "intermediate"


class StoryResponse(DegradableResponse):
    english: str
    chinese: str


class FillBlankRequest(BaseModel):
    english: str
    chinese: str
    words: List[str] = []


class FillBlankResponse(DegradableResponse):
    english_blank: str
    chinese_blank: str


# 已废弃：前端改用 POST /api/v1/learn/compose。第二阶段收尾时再决定是否删除。
@router.post("/generate", response_model=StoryResponse, deprecated=True)
async def generate_story(request: StoryRequest):
    """已废弃：请改用 POST /api/v1/learn/compose。第二阶段收尾时再决定是否删除。"""
    if not request.words:
        raise HTTPException(status_code=400, detail="Words list cannot be empty")

    try:
        return await ai_service.generate_story(request.words, request.difficulty)
    except AIServiceError as e:
        raise ai_http_error(e) from e


# 已废弃：前端改用 POST /api/v1/learn/compose。第二阶段收尾时再决定是否删除。
@router.post("/fill-blank", response_model=FillBlankResponse, deprecated=True)
async def generate_fill_blank(request: FillBlankRequest):
    """已废弃：请改用 POST /api/v1/learn/compose。第二阶段收尾时再决定是否删除。"""
    try:
        return await ai_service.generate_fill_blank(
            request.english, request.chinese, words=request.words
        )
    except AIServiceError as e:
        raise ai_http_error(e) from e
