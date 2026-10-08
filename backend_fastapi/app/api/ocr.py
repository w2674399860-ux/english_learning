from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from typing import List
from app.api.errors import OCR_UNAVAILABLE_DETAIL
from app.ratelimit.dependencies import limit_per_user
from app.schemas.common import DegradableResponse
from app.services.ocr_service import OCRService, OCRServiceError

router = APIRouter()
ocr_service = OCRService()


class OcrResponse(DegradableResponse):
    words: List[str]


# 图片大小上限由 app/core/body_limit.py 在中间件中检查（早于鉴权，超限 413）
@router.post("/recognize", response_model=OcrResponse, dependencies=[Depends(limit_per_user("ocr"))])
async def recognize_text(file: UploadFile = File(...)):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="只能上传图片文件")

    image_data = await file.read()
    try:
        words, reason = await ocr_service.recognize(image_data)
    except OCRServiceError as e:
        raise HTTPException(status_code=503, detail=OCR_UNAVAILABLE_DETAIL) from e

    return OcrResponse(words=words, degraded=reason is not None, reason=reason)
