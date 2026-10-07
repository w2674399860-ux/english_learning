from pydantic import Field
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

    # 账号（A-2）
    # 登录凭证有效期（天），从登录时起算，不随使用顺延
    session_ttl_days: int = 30
    # 是否启动时与每 24 小时清理过期 / 已撤销超过 7 天的会话，以及超过 2 天的限流计数（S-5）
    session_cleanup_enabled: bool = True
    # 是否提供 /docs、/redoc、/openapi.json。默认关闭（生产）；本地开发在 .env 中打开
    api_docs_enabled: bool = False

    # 防滥用限流（S-5）。计数存 rate_limit_counters 表，窗口按 UTC 对齐（按天的额度在 UTC 0 点重置）。
    # 窗口不超过 1 天：过期计数保留 2 天后清理。
    rate_limit_enabled: bool = True
    rate_limit_ocr_per_user: int = Field(60, ge=1)
    rate_limit_ocr_window_seconds: int = Field(86400, ge=1, le=86400)
    rate_limit_compose_per_user: int = Field(30, ge=1)
    rate_limit_compose_window_seconds: int = Field(86400, ge=1, le=86400)
    rate_limit_login_per_ip: int = Field(10, ge=1)
    rate_limit_login_window_seconds: int = Field(600, ge=1, le=86400)
    rate_limit_register_per_ip: int = Field(5, ge=1)
    rate_limit_register_window_seconds: int = Field(3600, ge=1, le=86400)

    # 输入上限（S-5）：生成与保存记录的词表超限返回 422；请求体超限返回 413
    compose_max_words: int = Field(20, ge=1)
    compose_max_word_length: int = Field(40, ge=1)
    max_upload_bytes: int = Field(10 * 1024 * 1024, ge=1)  # /ocr/recognize 整个请求体
    max_request_bytes: int = Field(1024 * 1024, ge=1)  # 其他 /api/ 接口
    history_max_page_size: int = Field(50, ge=1)

    # CORS
    frontend_url: str = "http://localhost:3000"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
