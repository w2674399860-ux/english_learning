from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List
from app.services.ai_service import AIService

router = APIRouter()
ai_service = AIService()


class StoryRequest(BaseModel):
    words: List[str]
    difficulty: str = "intermediate"


class StoryResponse(BaseModel):
    english: str
    chinese: str


class FillBlankRequest(BaseModel):
    english: str
    chinese: str
    words: List[str] = []


class FillBlankResponse(BaseModel):
    english_blank: str
    chinese_blank: str


@router.post("/generate", response_model=StoryResponse)
async def generate_story(request: StoryRequest):
    if not request.words:
        raise HTTPException(status_code=400, detail="Words list cannot be empty")

    result = await ai_service.generate_story(request.words, request.difficulty)
    return result


@router.post("/fill-blank", response_model=FillBlankResponse)
async def generate_fill_blank(request: FillBlankRequest):
    result = await ai_service.generate_fill_blank(
        request.english, request.chinese, words=request.words
    )
    return result
