"""请求体大小上限（S-5），纯 ASGI 中间件。

FastAPI 在执行依赖项（含鉴权）之前就会把整个请求体读完（multipart 还会写临时文件），
所以大小检查必须放在中间件里，才能在收下超大请求体之前拒绝：
- 有 Content-Length：超限直接 413，不读请求体
- 分块传输：边收边数，超限时抛 413（FastAPI 解析请求体时会原样抛出 HTTPException）
只作用于 /api/ 下的接口；上传接口用 MAX_UPLOAD_BYTES，其余用 MAX_REQUEST_BYTES。
"""
import json

from fastapi import HTTPException

from app.core.config import settings

UPLOAD_PATHS = {"/api/v1/ocr/recognize"}
REQUEST_TOO_LARGE = "请求内容过大"


def format_size(size: int) -> str:
    mb, kb = 1024 * 1024, 1024
    if size >= mb:
        return f"{size / mb:.1f}".removesuffix(".0") + " MB"
    if size >= kb:
        return f"{size / kb:.1f}".removesuffix(".0") + " KB"
    return f"{size} 字节"


def _limit_for(path: str) -> tuple[int, str]:
    if path in UPLOAD_PATHS:
        return settings.max_upload_bytes, f"图片不能超过 {format_size(settings.max_upload_bytes)}"
    return settings.max_request_bytes, REQUEST_TOO_LARGE


class BodyTooLarge(HTTPException):
    def __init__(self, detail: str):
        super().__init__(status_code=413, detail=detail)


class BodySizeLimitMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or not scope["path"].startswith("/api/"):
            await self.app(scope, receive, send)
            return

        limit, detail = _limit_for(scope["path"])
        declared = dict(scope["headers"]).get(b"content-length")
        if declared is not None and declared.isdigit() and int(declared) > limit:
            await _reject(send, detail)
            return

        received = 0
        response_started = False

        async def limited_receive():
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > limit:
                    raise BodyTooLarge(detail)
            return message

        async def tracking_send(message):
            nonlocal response_started
            if message["type"] == "http.response.start":
                response_started = True
            await send(message)

        try:
            await self.app(scope, limited_receive, tracking_send)
        except BodyTooLarge:
            # 正常情况下 FastAPI 已把它转成 413 响应；只有在路由之外读请求体时才会到这里
            if response_started:
                raise
            await _reject(send, detail)


async def _reject(send, detail: str) -> None:
    body = json.dumps({"detail": detail}, ensure_ascii=False).encode("utf-8")
    await send({
        "type": "http.response.start",
        "status": 413,
        "headers": [(b"content-type", b"application/json"), (b"content-length", str(len(body)).encode())],
    })
    await send({"type": "http.response.body", "body": body})
