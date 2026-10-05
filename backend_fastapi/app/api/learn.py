from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Literal
from app.api.errors import ai_http_error
from app.schemas.common import DegradableResponse
from app.services.ai_service import AIService, AIServiceError
from app.services.learn_service import LearnService

router = APIRouter()
learn_service = LearnService(AIService())


class ComposeRequest(BaseModel):
    words: List[str]
    difficulty: Literal["beginner", "intermediate", "advanced"] = "intermediate"


class ComposeResponse(DegradableResponse):
    english: str
    chinese: str
    english_blank: str
    chinese_blank: str


@router.post("/compose", response_model=ComposeResponse)
async def compose(request: ComposeRequest):
    """用确认后的词表一次生成短文、中译与中英文填空。"""
    if not request.words:
        raise HTTPException(status_code=400, detail="Words list cannot be empty")

    try:
        return await learn_service.compose(request.words, request.difficulty)
    except AIServiceError as e:
        raise ai_http_error(e) from e
