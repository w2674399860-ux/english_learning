from fastapi import APIRouter, UploadFile, File, HTTPException
from typing import List
from app.api.errors import OCR_UNAVAILABLE_DETAIL
from app.schemas.common import DegradableResponse
from app.services.ocr_service import OCRService, OCRServiceError

router = APIRouter()
ocr_service = OCRService()


class OcrResponse(DegradableResponse):
    words: List[str]


@router.post("/recognize", response_model=OcrResponse)
async def recognize_text(file: UploadFile = File(...)):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are allowed")

    image_data = await file.read()
    try:
        words, reason = await ocr_service.recognize(image_data)
    except OCRServiceError as e:
        raise HTTPException(status_code=503, detail=OCR_UNAVAILABLE_DETAIL) from e

    return OcrResponse(words=words, degraded=reason is not None, reason=reason)
