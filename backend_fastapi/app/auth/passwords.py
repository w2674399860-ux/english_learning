"""用户名与密码规则（纯函数，前端照此实现同样的校验）、密码哈希。

哈希用 argon2id（argon2-cffi 默认参数，即 RFC 9106 低内存配置：t=3, m=64 MiB, p=4）。
哈希在线程池中执行，不阻塞事件循环；同时进行的哈希数量受限，避免大量登录请求耗尽内存。
"""
import re
import threading

import anyio
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from fastapi import HTTPException

USERNAME_PATTERN = re.compile(r"[A-Za-z0-9_]{3,20}")  # 显式列出 ASCII 字符，排除 Unicode 形近字
PASSWORD_MIN_LENGTH = 8
PASSWORD_MAX_LENGTH = 128
MAX_CONCURRENT_HASHES = 4

USERNAME_RULE = "用户名需为 3–20 位字母、数字或下划线"

# 常见弱密码（不区分大小写）。短于 8 位的已被长度规则拒绝，不列入
COMMON_PASSWORDS = frozenset({
    "12345678", "123456789", "1234567890", "12345678910", "123123123", "11111111", "111111111",
    "00000000", "88888888", "66666666", "87654321", "98765432", "11223344", "12341234", "123qweasd",
    "password", "password1", "password12", "password123", "passw0rd", "p@ssw0rd", "p@ssword",
    "qwertyui", "qwertyuiop", "qwerty123", "qwerty12", "1qaz2wsx", "1q2w3e4r", "1q2w3e4r5t",
    "zaq12wsx", "asdfghjk", "asdfghjkl", "asdf1234", "zxcvbnm1", "zxcvbnm123", "abcd1234",
    "abc12345", "abcdefgh", "a1234567", "aa123456", "a123456789", "iloveyou", "iloveyou1",
    "woaini520", "woaini1314", "5201314520", "13145201314", "baseball", "football", "sunshine",
    "princess", "superman", "starwars", "whatever", "trustno1", "welcome1", "letmein1",
    "admin123", "administrator", "changeme", "computer", "internet", "monkey123", "dragon123",
    "michael1", "jennifer", "qazwsxedc", "qweasdzxc", "1234qwer", "qwer1234", "q1w2e3r4",
    "q1w2e3r4t5", "987654321", "147258369", "159357456", "123654789", "741852963",
    "english1", "english123", "learning", "student1", "student123",
})


class AuthRuleError(HTTPException):
    """规则不满足：422，detail 为中文。"""

    def __init__(self, detail: str):
        super().__init__(status_code=422, detail=detail)


def validate_username(raw) -> str:
    """校验格式并返回规范化（小写）的用户名。"""
    if not isinstance(raw, str) or not USERNAME_PATTERN.fullmatch(raw):
        raise AuthRuleError(USERNAME_RULE)
    return raw.lower()


def normalize_login_username(raw) -> str | None:
    """登录用：格式合法时返回小写用户名，否则返回 None（调用方按"用户不存在"处理）。"""
    try:
        return validate_username(raw)
    except AuthRuleError:
        return None


def validate_new_password(password, username: str) -> None:
    """注册、改密码、管理员重置密码共用的密码规则。不强制复杂度（CLAUDE.md 第 9 节 A2）。"""
    if not isinstance(password, str) or len(password) < PASSWORD_MIN_LENGTH:
        raise AuthRuleError(f"密码至少 {PASSWORD_MIN_LENGTH} 位")
    if len(password) > PASSWORD_MAX_LENGTH:
        raise AuthRuleError(f"密码不能超过 {PASSWORD_MAX_LENGTH} 位")
    if password.lower() == username.lower():
        raise AuthRuleError("密码不能与用户名相同")
    if password.lower() in COMMON_PASSWORDS:
        raise AuthRuleError("密码过于简单，请换一个")


# ---- 哈希 -------------------------------------------------------------------

def make_hasher() -> PasswordHasher:
    return PasswordHasher()


password_hasher = make_hasher()
_hash_slots = threading.BoundedSemaphore(MAX_CONCURRENT_HASHES)
_dummy_hashes: dict[int, str] = {}


def _hash_sync(hasher: PasswordHasher, password: str) -> str:
    with _hash_slots:
        return hasher.hash(password)


def _verify_sync(hasher: PasswordHasher, password_hash: str, password: str) -> tuple[bool, bool]:
    with _hash_slots:
        try:
            hasher.verify(password_hash, password)
        except (VerifyMismatchError, VerificationError, InvalidHashError):
            return False, False
        return True, hasher.check_needs_rehash(password_hash)


async def hash_password(password: str) -> str:
    return await anyio.to_thread.run_sync(_hash_sync, password_hasher, password)


async def verify_password(password_hash: str, password: str) -> tuple[bool, bool]:
    """返回 (是否匹配, 是否需要按当前参数重新哈希)。"""
    return await anyio.to_thread.run_sync(_verify_sync, password_hasher, password_hash, password)


async def verify_against_dummy(password: str) -> None:
    """用户不存在时也做一次同样代价的校验，避免通过响应时间判断用户名是否存在。"""
    hasher = password_hasher
    dummy = _dummy_hashes.get(id(hasher))
    if dummy is None:
        dummy = await anyio.to_thread.run_sync(_hash_sync, hasher, "dummy-password-for-timing")
        _dummy_hashes[id(hasher)] = dummy
    await verify_password(dummy, password)
