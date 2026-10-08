import asyncio
import contextlib
import logging
import os
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from app.core.config import settings
from app.core.logging import configure_logging
from app.api.router import api_router
from app.core.body_limit import BodySizeLimitMiddleware
from app.db.session import dispose_engine

# 先于其他模块记日志之前配置（E-2）：统一格式、UTC 时间戳、输出到标准输出
configure_logging(settings.log_level)
logger = logging.getLogger("app")

SESSION_CLEANUP_INTERVAL_SECONDS = 24 * 60 * 60


async def _cleanup_once() -> None:
    """清理过期会话与过期限流计数（S-5）。两项互不影响，失败不影响服务启动。"""
    from app.auth.service import AuthService
    from app.db.session import get_engine, get_session
    from app.ratelimit import limiter

    for name, job in (
        ("session", lambda s: AuthService(s).cleanup_sessions()),
        ("rate limit counter", lambda s: limiter.cleanup(s)),
    ):
        try:
            get_engine()
            async for session in get_session():
                removed = await job(session)
                logger.info("%s cleanup: removed %d expired rows", name, removed)
        except Exception as e:
            logger.warning("%s cleanup failed: %s", name, type(e).__name__)


async def _cleanup_forever() -> None:
    while True:
        await _cleanup_once()
        await asyncio.sleep(SESSION_CLEANUP_INTERVAL_SECONDS)


@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(_cleanup_forever()) if settings.session_cleanup_enabled else None
    yield
    if task is not None:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task
    await dispose_engine()


def cors_options(origins: list[str]) -> dict:
    """CORS 白名单（S-3a）。凭证只走 Authorization 头、不用 Cookie，所以不开 allow_credentials。

    方法与请求头只放行前端实际用到的；新增请求头时要同步加到 allow_headers。
    暴露 Retry-After，跨域时前端才能读到 429 的等待时间（S-5）。
    """
    return {
        "allow_origins": origins,
        "allow_credentials": False,
        "allow_methods": ["GET", "POST", "PUT", "DELETE"],
        "allow_headers": ["Authorization", "Content-Type"],
        "expose_headers": ["Retry-After"],
        "max_age": 600,
    }


def warn_deprecated_settings() -> None:
    if settings.frontend_url is not None:
        logger.warning("FRONTEND_URL is deprecated and has no effect; use CORS_ALLOW_ORIGINS and remove it from .env")


def docs_options(enabled: bool) -> dict:
    """API_DOCS_ENABLED 关闭时不注册 /docs、/redoc、/openapi.json（生产默认关闭）。"""
    if enabled:
        return {}
    return {"docs_url": None, "redoc_url": None, "openapi_url": None}


app = FastAPI(
    title="AI English Learning App",
    description="Backend API for AI-powered English learning application",
    version="1.0.0",
    lifespan=lifespan,
    **docs_options(settings.api_docs_enabled),
)

# 请求体大小上限（S-5）：先于路由与鉴权。加在 CORS 之前，使 413 响应也带 CORS 头
app.add_middleware(BodySizeLimitMiddleware)
app.add_middleware(CORSMiddleware, **cors_options(settings.cors_origins))
warn_deprecated_settings()

app.include_router(api_router)


@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """参数校验错误（422）：只返回 type / loc / msg。

    FastAPI 默认在每条错误里带 input（请求中的原值）与 ctx，会把密码等原样回显（第一段安全自查 P1）。
    """
    errors = [{"type": e["type"], "loc": list(e["loc"]), "msg": e["msg"]} for e in exc.errors()]
    return JSONResponse(status_code=422, content={"detail": errors})


@app.get("/health")
async def health_check():
    return {"status": "ok", "version": "1.0.0"}


# Serve Flutter web build
static_dir = os.path.join(os.path.dirname(__file__), "static")


def _resolve_static_path(full_path: str) -> str | None:
    """把请求路径解析为 static_dir 内的真实路径；越出 static_dir 时返回 None。

    realpath 会解析 ..、符号链接与绝对路径；normcase 统一 Windows 的大小写与斜杠。
    盘符不同时 commonpath 抛 ValueError，视为越界。路径含 NUL 时 realpath 不抛错，
    照常做越界判断；目录内的这类路径随后 isfile 为 False，回落 index.html。
    """
    try:
        root = os.path.realpath(static_dir)
        target = os.path.realpath(os.path.join(root, full_path))
        if os.path.commonpath([os.path.normcase(root), os.path.normcase(target)]) != os.path.normcase(root):
            return None
    except ValueError:
        return None
    return target


@app.get("/{full_path:path}")
async def serve_flutter(full_path: str):
    file_path = _resolve_static_path(full_path)
    if file_path is None:
        raise HTTPException(status_code=404, detail="Not Found")
    if os.path.isfile(file_path):
        return FileResponse(file_path)

    index_path = os.path.join(static_dir, "index.html")
    if os.path.exists(index_path):
        return FileResponse(index_path)

    return {"message": "AI English Learning API"}


def run() -> None:
    uvicorn.run(
        "main:app",
        host=settings.server_host,
        port=settings.server_port,
        reload=settings.debug,
        # 不信任 X-Forwarded-For（uvicorn 默认信任来自 127.0.0.1 的代理头）。
        # 部署到反向代理后改为 proxy_headers=True 并设置 forwarded_allow_ips=<代理地址>（CLAUDE.md 第 10 节）
        proxy_headers=False,
    )


if __name__ == "__main__":
    run()
