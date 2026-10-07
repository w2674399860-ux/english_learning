from pydantic import BaseModel, Field

from app.schemas.common import to_utc_iso

# 只限制请求体大小；用户名与密码的业务规则在 app/auth/passwords.py 中校验，返回中文 detail
_MAX_FIELD = 1024


class RegisterRequest(BaseModel):
    username: str = Field(max_length=64)
    password: str = Field(max_length=_MAX_FIELD)


class LoginRequest(BaseModel):
    username: str = Field(max_length=64)
    password: str = Field(max_length=_MAX_FIELD)


class ChangePasswordRequest(BaseModel):
    old_password: str = Field(max_length=_MAX_FIELD)
    new_password: str = Field(max_length=_MAX_FIELD)


class UserOut(BaseModel):
    id: int
    username: str
    created_at: str

    @classmethod
    def from_user(cls, user) -> "UserOut":
        return cls(id=user.id, username=user.username, created_at=to_utc_iso(user.created_at))


class TokenOut(BaseModel):
    token: str
    token_type: str = "bearer"
    expires_at: str

    @classmethod
    def from_issued(cls, issued) -> "TokenOut":
        return cls(token=issued.token, expires_at=to_utc_iso(issued.expires_at))


class AuthOut(TokenOut):
    user: UserOut

    @classmethod
    def build(cls, user, issued) -> "AuthOut":
        return cls(token=issued.token, expires_at=to_utc_iso(issued.expires_at), user=UserOut.from_user(user))
