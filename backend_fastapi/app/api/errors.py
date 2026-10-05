from fastapi import HTTPException
from app.services.ai_service import AIServiceError

# AI 失败 reason → (HTTP 状态码, 面向用户的 detail)。技术细节只写日志，不进 detail。
AI_ERRORS = {
    "ai_not_configured": (503, "AI service is not configured."),
    "ai_unavailable": (503, "AI service is unavailable. Please try again later."),
    "ai_timeout": (504, "AI service timed out. Please try again."),
    "ai_upstream_error": (502, "AI service returned an error. Please try again later."),
    "ai_parse_failed": (502, "AI returned an invalid response. Please try again."),
}

OCR_UNAVAILABLE_DETAIL = "OCR service is unavailable. Please try again later."


def ai_http_error(e: AIServiceError) -> HTTPException:
    status_code, detail = AI_ERRORS.get(e.reason, (502, "AI service error. Please try again later."))
    return HTTPException(status_code=status_code, detail=detail)
