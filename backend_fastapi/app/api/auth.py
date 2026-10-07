"""账号接口。public_router 不需要登录（注册、登录）；router 需要登录，由 app/api/router.py 统一挂鉴权依赖。"""
from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser, get_current_user
from app.auth.service import AuthService
from app.db.session import get_session
from app.models.user import User
from app.schemas.auth import AuthOut, ChangePasswordRequest, LoginRequest, RegisterRequest, TokenOut, UserOut

public_router = APIRouter()
router = APIRouter()


def get_auth_service(session: AsyncSession = Depends(get_session)) -> AuthService:
    return AuthService(session)


def _client_ip(request: Request) -> str:
    # 本阶段取连接地址，不信任 X-Forwarded-For（部署到反向代理后在 S-5 / 上线清单中调整）
    return request.client.host if request.client else "unknown"


@public_router.post("/register", response_model=AuthOut, status_code=201)
async def register(body: RegisterRequest, request: Request, auth: AuthService = Depends(get_auth_service)):
    user, issued = await auth.register(body.username, body.password, _client_ip(request))
    return AuthOut.build(user, issued)


@public_router.post("/login", response_model=AuthOut)
async def login(body: LoginRequest, request: Request, auth: AuthService = Depends(get_auth_service)):
    user, issued = await auth.login(body.username, body.password, _client_ip(request))
    return AuthOut.build(user, issued)


@router.post("/logout", status_code=204)
async def logout(
    user: CurrentUser = Depends(get_current_user), auth: AuthService = Depends(get_auth_service)
):
    await auth.logout(user.session_id)
    return Response(status_code=204)


@router.get("/me", response_model=UserOut)
async def me(user: CurrentUser = Depends(get_current_user), session: AsyncSession = Depends(get_session)):
    return UserOut.from_user(await session.get(User, user.id))


@router.post("/change-password", response_model=TokenOut)
async def change_password(
    body: ChangePasswordRequest,
    user: CurrentUser = Depends(get_current_user),
    auth: AuthService = Depends(get_auth_service),
):
    issued = await auth.change_password(user.id, body.old_password, body.new_password)
    return TokenOut.from_issued(issued)
