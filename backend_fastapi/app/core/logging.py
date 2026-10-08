"""日志配置（E-2）：统一格式、UTC 时间戳、输出到标准输出。

在 main.py 导入时调用，本地直跑（含 --reload）与容器中都生效。
日志中不出现密码与凭证：业务代码只记用户名、IP、用户 id、reason；凭证只在 Authorization 头中，
访问日志不记请求头；SQL 与参数不打印（sqlalchemy.engine 固定 WARNING，engine 另设 hide_parameters）。
"""
import logging
import logging.config
import time

LOG_FORMAT = "%(asctime)s %(levelname)s %(name)s: %(message)s"
LOG_LEVELS = ("DEBUG", "INFO", "WARNING", "ERROR")


class UTCFormatter(logging.Formatter):
    """时间戳统一为 UTC（与数据库一致），形如 2026-10-08T03:12:45.123Z。"""

    converter = time.gmtime

    def formatTime(self, record: logging.LogRecord, datefmt: str | None = None) -> str:
        return time.strftime("%Y-%m-%dT%H:%M:%S", self.converter(record.created)) + f".{int(record.msecs):03d}Z"


def logging_config(level: str) -> dict:
    return {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {"default": {"()": UTCFormatter, "format": LOG_FORMAT}},
        "handlers": {
            "stdout": {
                "class": "logging.StreamHandler",
                "stream": "ext://sys.stdout",
                "formatter": "default",
            },
        },
        "root": {"level": level, "handlers": ["stdout"]},
        "loggers": {
            # uvicorn 自带的处理器去掉，统一交给 root 输出
            "uvicorn": {"handlers": [], "propagate": True},
            "uvicorn.error": {"handlers": [], "propagate": True},
            "uvicorn.access": {"handlers": [], "propagate": True},
            # 第三方只看 WARNING 及以上：不打印 SQL，不打印每次 DeepSeek / OCR 请求
            "sqlalchemy.engine": {"level": "WARNING"},
            "httpx": {"level": "WARNING"},
            "httpcore": {"level": "WARNING"},
            "asyncmy": {"level": "WARNING"},
        },
    }


def configure_logging(level: str) -> None:
    logging.config.dictConfig(logging_config(level.upper()))
