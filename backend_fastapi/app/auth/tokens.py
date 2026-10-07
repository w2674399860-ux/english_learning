"""登录凭证：32 字节随机数（URL 安全的 base64，43 个字符）。数据库只存 SHA-256。

凭证熵足够高，用 SHA-256 即可，不需要密码那样的慢哈希（docs/数据库设计方案.md 4.2）。
"""
import hashlib
import secrets


def new_token() -> str:
    return secrets.token_urlsafe(32)


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()
