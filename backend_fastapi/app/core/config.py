from pydantic_settings import BaseSettings
from typing import Literal, Optional


class Settings(BaseSettings):
    # DeepSeek API
    deepseek_api_key: str = ""
    deepseek_api_base: str = "https://api.deepseek.com"
    # AI 失败时是否回落 mock（响应带 degraded/reason）。默认关闭：失败直接报错。
    # 仅本地开发在 .env 中打开。
    ai_fallback_enabled: bool = False

    # Database（MySQL 8.4，见 docs/数据库设计方案.md）。无默认值：未配置时首次访问数据库即报错，
    # 不会悄悄连到别的库。格式：mysql+asyncmy://<用户>:<密码>@127.0.0.1:3307/english_learning?charset=utf8mb4
    database_url: str = ""
    # 只给测试与 `alembic -x target=test` 使用，库名必须是 english_learning_test
    test_database_url: str = ""

    # Server
    server_host: str = "0.0.0.0"
    server_port: int = 8000
    debug: bool = True

    # OCR Service
    ocr_service_url: str = "http://localhost:8866"
    # "docker": 失败返回 503（默认，生产）；"auto": 失败回落 mock 并标记 degraded（本地开发）；
    # "mock": 始终返回示例词，同样标记 degraded
    ocr_mode: Literal["docker", "mock", "auto"] = "docker"

    # CORS
    frontend_url: str = "http://localhost:3000"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
