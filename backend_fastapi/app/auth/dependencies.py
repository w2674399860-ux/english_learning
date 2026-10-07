"""鉴权依赖项。鉴权逻辑只在这里，路由不各自手写校验。

凭证只从 Authorization: Bearer 头读取，不接受 URL 查询参数或 Cookie。
用户身份只来自这里校验后的凭证，永不信任请求体或查询参数里的 user_id。
"""
from dataclasses import dataclass
from datetime import timedelta

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.tokens import hash_token
from app.db.session import get_session
from app.models.user import User, UserSession
from app.schemas.common import utcnow

NOT_LOGGED_IN = "请先登录"
SESSION_INVALID = "登录已失效，请重新登录"
LAST_USED_UPDATE_INTERVAL = timedelta(hours=1)

bearer_scheme = HTTPBearer(auto_error=False, description="登录或注册返回的 token")


@dataclass(frozen=True)
class CurrentUser:
    id: int
    username: str
    session_id: int


def unauthorized(detail: str) -> HTTPException:
    return HTTPException(status_code=401, detail=detail, headers={"WWW-Authenticate": "Bearer"})


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    session: AsyncSession = Depends(get_session),
) -> CurrentUser:
    if credentials is None or not credentials.credentials:
        raise unauthorized(NOT_LOGGED_IN)

    now = utcnow()
    row = (
        await session.execute(
            select(UserSession, User)
            .join(User, UserSession.user_id == User.id)
            .where(
                UserSession.token_hash == hash_token(credentials.credentials),
                UserSession.revoked_at.is_(None),
                UserSession.expires_at > now,
                User.is_active.is_(True),
                or_(User.password_changed_at.is_(None), UserSession.created_at >= User.password_changed_at),
            )
        )
    ).first()
    if row is None:
        raise unauthorized(SESSION_INVALID)

    user_session, user = row
    if user_session.last_used_at is None or now - user_session.last_used_at >= LAST_USED_UPDATE_INTERVAL:
        await session.execute(
            update(UserSession).where(UserSession.id == user_session.id).values(last_used_at=now)
        )
        await session.commit()
    return CurrentUser(id=user.id, username=user.username, session_id=user_session.id)
