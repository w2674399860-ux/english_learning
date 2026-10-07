import asyncio
import contextlib
import logging
import os
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from app.core.config import settings
from app.api.router import api_router
from app.db.session import dispose_engine

logger = logging.getLogger("app")

SESSION_CLEANUP_INTERVAL_SECONDS = 24 * 60 * 60


async def _cleanup_sessions_once() -> None:
    from app.auth.service import AuthService
    from app.db.session import get_engine, get_session

    try:
        get_engine()
        async for session in get_session():
            removed = await AuthService(session).cleanup_sessions()
            logger.info("session cleanup: removed %d expired/revoked sessions", removed)
    except Exception as e:  # 清理失败不影响服务启动
        logger.warning("session cleanup failed: %s", type(e).__name__)


async def _cleanup_sessions_forever() -> None:
    while True:
        await _cleanup_sessions_once()
        await asyncio.sleep(SESSION_CLEANUP_INTERVAL_SECONDS)


@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(_cleanup_sessions_forever()) if settings.session_cleanup_enabled else None
    yield
    if task is not None:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task
    await dispose_engine()


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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    max_age=0,
)

app.include_router(api_router)


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


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=settings.server_host,
        port=settings.server_port,
        reload=settings.debug,
    )
