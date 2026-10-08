from fastapi import HTTPException
from app.services.ai_service import AIServiceError

# AI 失败 reason → (HTTP 状态码, 面向用户的 detail)。技术细节只写日志，不进 detail。
AI_ERRORS = {
    "ai_not_configured": (503, "生成服务未配置，请联系管理员"),
    "ai_unavailable": (503, "生成服务暂时不可用，请稍后再试"),
    "ai_timeout": (504, "生成超时，请重试"),
    "ai_upstream_error": (502, "生成服务出错，请稍后再试"),
    "ai_parse_failed": (502, "生成结果有误，请重试"),
}

OCR_UNAVAILABLE_DETAIL = "识别服务暂时不可用，请稍后再试"


def ai_http_error(e: AIServiceError) -> HTTPException:
    status_code, detail = AI_ERRORS.get(e.reason, (502, "生成服务出错，请稍后再试"))
    return HTTPException(status_code=status_code, detail=detail)
