from fastapi import APIRouter, UploadFile, File, HTTPException
from app.services.ocr_service import OCRService, OCRServiceError

router = APIRouter()
ocr_service = OCRService()


@router.post("/recognize")
async def recognize_text(file: UploadFile = File(...)):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are allowed")

    image_data = await file.read()
    try:
        result = await ocr_service.recognize(image_data)
    except OCRServiceError as e:
        raise HTTPException(status_code=503, detail=str(e))

    return {"words": result}
