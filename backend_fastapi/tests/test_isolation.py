"""证明测试设施本身有效：不读真实配置、连不出网络、不碰开发数据库。"""
import socket

import httpx
import pytest
from conftest import DEEPSEEK_BASE, OCR_BASE, TEST_API_KEY, TEST_DATABASE_URL, _check_test_db_url
from sqlalchemy.engine import make_url

from app.core.config import settings


def test_settings_come_from_test_environment():
    assert settings.deepseek_api_key == TEST_API_KEY
    assert settings.deepseek_api_base == DEEPSEEK_BASE
    assert settings.ocr_service_url == OCR_BASE
    assert settings.ocr_mode == "docker"
    assert settings.ai_fallback_enabled is False


@pytest.mark.parametrize("address", [("127.0.0.1", 3306), ("127.0.0.1", 8866), ("93.184.216.34", 443)])
def test_raw_socket_connect_is_blocked(address):
    with pytest.raises(RuntimeError, match="must not open network connections"):
        socket.create_connection(address, timeout=1)


def test_dns_lookup_is_blocked():
    with pytest.raises(RuntimeError, match="must not open network connections"):
        socket.getaddrinfo("api.deepseek.com", 443)


async def test_unmocked_async_request_fails_the_test():
    with pytest.raises(pytest.fail.Exception, match="unexpected outbound request"):
        async with httpx.AsyncClient() as client:
            await client.get("https://api.deepseek.com/v1/models")


def test_database_url_points_to_test_db_only():
    """DATABASE_URL 在测试进程中被覆盖为测试库地址（或为空），开发库永远连不上。"""
    assert settings.database_url == TEST_DATABASE_URL
    if TEST_DATABASE_URL:
        url = make_url(TEST_DATABASE_URL)
        assert url.database == "english_learning_test"
        assert url.port not in (None, 3306)


@pytest.mark.parametrize("url, reason", [
    ("mysql+asyncmy://u:p@127.0.0.1:3307/english_learning", "database must be"),
    ("mysql+asyncmy://u:p@127.0.0.1:3306/english_learning_test", "3306"),
    ("mysql+asyncmy://u:p@localhost/english_learning_test", "3306"),
])
def test_unsafe_test_database_urls_are_rejected(url, reason):
    assert reason in _check_test_db_url(url)
    assert "p@" not in _check_test_db_url(url)


def test_safe_test_database_url_is_accepted():
    assert _check_test_db_url("mysql+asyncmy://u:p@127.0.0.1:3307/english_learning_test") is None
