"""证明测试设施本身有效：不读真实配置、连不出网络、不碰开发数据库。"""
import socket
from pathlib import Path

import httpx
import pytest
from conftest import BACKEND_DIR, DEEPSEEK_BASE, OCR_BASE, TEST_API_KEY

import app.models.history as history_model
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


def test_dev_database_is_not_used():
    dev_db = (BACKEND_DIR / "data" / "english_learning.db").resolve()
    assert Path(history_model.DB_PATH).resolve() != dev_db
