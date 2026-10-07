from fastapi import APIRouter, Depends

from app.auth.dependencies import get_current_user

from . import auth, history, learn, ocr

# 除注册、登录外，所有 /api/v1 接口默认需要登录；新增路由组也挂在 protected 下。
# tests/unit/test_auth_rules.py 会清点全部路由，漏挂鉴权会让测试失败。
protected = [Depends(get_current_user)]

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.public_router, prefix="/auth", tags=["Auth"])
api_router.include_router(auth.router, prefix="/auth", tags=["Auth"], dependencies=protected)
api_router.include_router(ocr.router, prefix="/ocr", tags=["OCR"], dependencies=protected)
api_router.include_router(history.router, prefix="/history", tags=["History"], dependencies=protected)
api_router.include_router(learn.router, prefix="/learn", tags=["Learn"], dependencies=protected)
