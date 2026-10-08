"""账号业务：注册、登录、登出、改密码、管理员操作、过期会话清理。

日志只记用户名与客户端 IP，永不记录密码、凭证或哈希。
"""
import logging
from datetime import datetime, timedelta

from fastapi import HTTPException
from sqlalchemy import delete, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import passwords
from app.auth.tokens import hash_token, new_token
from app.core.config import settings
from app.models.user import User, UserSession
from app.schemas.common import utcnow

logger = logging.getLogger("app.auth")

INVALID_CREDENTIALS = "用户名或密码错误"
ACCOUNT_DISABLED = "账号已停用，请联系管理员"
USERNAME_TAKEN = "用户名已被注册"
WRONG_OLD_PASSWORD = "当前密码不正确"
SAME_PASSWORD = "新密码不能与当前密码相同"

# 过期或已撤销超过这个时长的会话会被清理
SESSION_RETENTION = timedelta(days=7)


class IssuedToken:
    def __init__(self, token: str, expires_at: datetime):
        self.token = token
        self.expires_at = expires_at


class AuthService:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def _issue_session(self, user_id: int, now: datetime) -> IssuedToken:
        token = new_token()
        expires_at = now + timedelta(days=settings.session_ttl_days)
        self.session.add(UserSession(
            user_id=user_id, token_hash=hash_token(token), created_at=now, expires_at=expires_at,
        ))
        return IssuedToken(token, expires_at)

    async def _revoke_all(self, user_id: int, now: datetime) -> None:
        await self.session.execute(
            update(UserSession)
            .where(UserSession.user_id == user_id, UserSession.revoked_at.is_(None))
            .values(revoked_at=now)
        )

    async def register(self, username: str, password: str, client_ip: str) -> tuple[User, IssuedToken]:
        name = passwords.validate_username(username)
        passwords.validate_new_password(password, name)
        if await self.session.scalar(select(User.id).where(User.username == name)) is not None:
            logger.warning("register conflict for username=%r from %s", name, client_ip)
            raise HTTPException(status_code=409, detail=USERNAME_TAKEN)

        user = User(username=name, password_hash=await passwords.hash_password(password))
        self.session.add(user)
        try:
            await self.session.flush()
        except IntegrityError:  # 并发注册同名：以唯一索引为准
            await self.session.rollback()
            logger.warning("register conflict for username=%r from %s", name, client_ip)
            raise HTTPException(status_code=409, detail=USERNAME_TAKEN)

        now = utcnow()
        user.last_login_at = now
        issued = await self._issue_session(user.id, now)
        await self.session.commit()
        logger.info("user registered: username=%r id=%s", name, user.id)
        return user, issued

    async def login(self, username: str, password: str, client_ip: str) -> tuple[User, IssuedToken]:
        name = passwords.normalize_login_username(username)
        user = None
        if name is not None:
            user = await self.session.scalar(select(User).where(User.username == name))
        if user is None:
            await passwords.verify_against_dummy(password)
            logger.warning("login failed for username=%r from %s", name or "<invalid>", client_ip)
            raise HTTPException(status_code=401, detail=INVALID_CREDENTIALS)

        ok, needs_rehash = await passwords.verify_password(user.password_hash, password)
        if not ok:
            logger.warning("login failed for username=%r from %s", name, client_ip)
            raise HTTPException(status_code=401, detail=INVALID_CREDENTIALS)
        if not user.is_active:
            logger.warning("login refused for disabled username=%r from %s", name, client_ip)
            raise HTTPException(status_code=403, detail=ACCOUNT_DISABLED)

        if needs_rehash:
            user.password_hash = await passwords.hash_password(password)
        now = utcnow()
        user.last_login_at = now
        issued = await self._issue_session(user.id, now)
        await self.session.commit()
        return user, issued

    async def logout(self, session_id: int) -> None:
        await self.session.execute(
            update(UserSession)
            .where(UserSession.id == session_id, UserSession.revoked_at.is_(None))
            .values(revoked_at=utcnow())
        )
        await self.session.commit()

    async def change_password(self, user_id: int, old_password: str, new_password: str) -> IssuedToken:
        user = await self.session.get(User, user_id)
        ok, _ = await passwords.verify_password(user.password_hash, old_password)
        if not ok:
            raise HTTPException(status_code=400, detail=WRONG_OLD_PASSWORD)
        passwords.validate_new_password(new_password, user.username)
        if new_password == old_password:
            raise passwords.AuthRuleError(SAME_PASSWORD)

        now = utcnow()
        user.password_hash = await passwords.hash_password(new_password)
        user.password_changed_at = now
        await self._revoke_all(user.id, now)
        issued = await self._issue_session(user.id, now)
        await self.session.commit()
        logger.info("password changed: username=%r", user.username)
        return issued

    # ---- 管理员（scripts/admin.py）--------------------------------------------

    async def admin_reset_password(self, user: User, new_password: str) -> None:
        passwords.validate_new_password(new_password, user.username)
        now = utcnow()
        user.password_hash = await passwords.hash_password(new_password)
        user.password_changed_at = now
        await self._revoke_all(user.id, now)
        await self.session.commit()

    async def admin_set_active(self, user: User, active: bool) -> None:
        user.is_active = active
        if not active:
            await self._revoke_all(user.id, utcnow())
        await self.session.commit()

    # ---- 清理 -------------------------------------------------------------------

    def _expired_condition(self, now: datetime):
        cutoff = now - SESSION_RETENTION
        return or_(UserSession.expires_at < cutoff, UserSession.revoked_at < cutoff)

    async def count_expired_sessions(self) -> int:
        from sqlalchemy import func

        return await self.session.scalar(
            select(func.count()).select_from(UserSession).where(self._expired_condition(utcnow()))
        )

    async def cleanup_sessions(self) -> int:
        result = await self.session.execute(delete(UserSession).where(self._expired_condition(utcnow())))
        await self.session.commit()
        return result.rowcount
