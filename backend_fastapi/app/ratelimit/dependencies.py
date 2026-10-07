"""限流依赖项，挂在路由上：鉴权之后、业务之前计数（CLAUDE.md 第 9 节 S2）。

- 按用户：依赖 get_current_user（同一请求内 FastAPI 缓存结果，不会重复查库）。未登录在鉴权处 401，不计数
- 按 IP：用于登录、注册，在密码哈希之前计数
- 依赖先于请求体校验执行：参数错误（422）同样计数；已超限时返回 429
"""
from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import CurrentUser, get_current_user
from app.db.session import get_session
from app.ratelimit import limiter


def limit_per_user(scope: str):
    async def rate_limit_user(
        user: CurrentUser = Depends(get_current_user), session: AsyncSession = Depends(get_session)
    ) -> None:
        await limiter.enforce(session, scope, limiter.user_subject(user.id))

    rate_limit_user.rate_limit_scope = scope
    rate_limit_user.rate_limit_kind = "user"
    return rate_limit_user


def limit_per_ip(scope: str):
    async def rate_limit_ip(request: Request, session: AsyncSession = Depends(get_session)) -> None:
        await limiter.enforce(session, scope, limiter.ip_subject(request))

    rate_limit_ip.rate_limit_scope = scope
    rate_limit_ip.rate_limit_kind = "ip"
    return rate_limit_ip
