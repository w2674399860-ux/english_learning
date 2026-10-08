"""日志配置（E-2）：格式、UTC 时间戳、输出到标准输出、级别配置、第三方日志降噪。"""
import io
import logging
import re
import sys

import pytest
from pydantic import ValidationError

from app.core.config import Settings
from app.core.logging import configure_logging, logging_config

LINE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z WARNING app\.auth: login failed for username='alice'$")


@pytest.fixture
def restore_logging():
    """dictConfig 会改全局状态；测试后恢复为 main.py 导入时的配置。"""
    yield
    from app.core.config import settings

    configure_logging(settings.log_level)


def test_format_utc_timestamp_and_stdout(monkeypatch, restore_logging):
    out = io.StringIO()
    monkeypatch.setattr(sys, "stdout", out)
    configure_logging("info")  # 不区分大小写；ext://sys.stdout 在配置时解析
    logging.getLogger("app.auth").warning("login failed for username=%r", "alice")
    logging.getLogger("app.auth").debug("not shown at INFO")
    lines = out.getvalue().splitlines()
    assert len(lines) == 1
    assert LINE.match(lines[0]), lines[0]


def test_uvicorn_logs_use_the_same_handler(monkeypatch, restore_logging):
    out = io.StringIO()
    monkeypatch.setattr(sys, "stdout", out)
    configure_logging("INFO")
    logging.getLogger("uvicorn.access").info('127.0.0.1:5000 - "GET /health HTTP/1.1" 200')
    assert re.search(r"Z INFO uvicorn\.access: 127\.0\.0\.1:5000", out.getvalue())


def test_third_party_loggers_are_quiet_even_at_debug():
    loggers = logging_config("DEBUG")["loggers"]
    # SQL 与参数、每次上游请求的地址都不进日志
    for name in ("sqlalchemy.engine", "httpx", "httpcore", "asyncmy"):
        assert loggers[name]["level"] == "WARNING", name


def test_log_level_setting(monkeypatch):
    monkeypatch.setenv("LOG_LEVEL", "warning")
    assert Settings(_env_file=None).log_level == "WARNING"
    monkeypatch.delenv("LOG_LEVEL")
    assert Settings(_env_file=None).log_level == "INFO"
    monkeypatch.setenv("LOG_LEVEL", "verbose")
    with pytest.raises(ValidationError, match="LOG_LEVEL"):
        Settings(_env_file=None)
