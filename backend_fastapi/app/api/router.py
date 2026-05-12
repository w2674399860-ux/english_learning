from fastapi import APIRouter

from . import ocr, story, history

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(ocr.router, prefix="/ocr", tags=["OCR"])
api_router.include_router(story.router, prefix="/story", tags=["Story"])
api_router.include_router(history.router, prefix="/history", tags=["History"])
