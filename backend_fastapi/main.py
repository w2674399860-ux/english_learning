import os
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from app.core.config import settings
from app.api.router import api_router

app = FastAPI(
    title="AI English Learning App",
    description="Backend API for AI-powered English learning application",
    version="1.0.0",
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


@app.get("/{full_path:path}")
async def serve_flutter(full_path: str):
    file_path = os.path.join(static_dir, full_path)
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
