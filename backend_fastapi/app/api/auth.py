"""账号接口。public_router 不需要登录（注册、登录）；router 需要登录，由 app/api/router.py 统一挂鉴权依赖。"""
from fastapi import APIRouter, Depends, Request, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser, get_current_user
from app.auth.service import AuthService
from app.db.session import get_session
from app.models.user import User
from app.ratelimit.dependencies import limit_per_ip, limit_per_user
from app.ratelimit.limiter import client_ip
from app.schemas.auth import AuthOut, ChangePasswordRequest, LoginRequest, RegisterRequest, TokenOut, UserOut

public_router = APIRouter()
router = APIRouter()


def get_auth_service(session: AsyncSession = Depends(get_session)) -> AuthService:
    return AuthService(session)


# 登录、注册按 IP 限流（S-5），在密码哈希之前计数
@public_router.post(
    "/register", response_model=AuthOut, status_code=201, dependencies=[Depends(limit_per_ip("register"))]
)
async def register(body: RegisterRequest, request: Request, auth: AuthService = Depends(get_auth_service)):
    user, issued = await auth.register(body.username, body.password, client_ip(request))
    return AuthOut.build(user, issued)


@public_router.post("/login", response_model=AuthOut, dependencies=[Depends(limit_per_ip("login"))])
async def login(body: LoginRequest, request: Request, auth: AuthService = Depends(get_auth_service)):
    user, issued = await auth.login(body.username, body.password, client_ip(request))
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


# 按用户限流，在校验原密码（哈希计算）之前计数
@router.post(
    "/change-password", response_model=TokenOut, dependencies=[Depends(limit_per_user("change_password"))]
)
async def change_password(
    body: ChangePasswordRequest,
    user: CurrentUser = Depends(get_current_user),
    auth: AuthService = Depends(get_auth_service),
):
    issued = await auth.change_password(user.id, body.old_password, body.new_password)
    return TokenOut.from_issued(issued)
