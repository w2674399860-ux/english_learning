import re
from typing import Literal, Optional

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings

from app.core.logging import LOG_LEVELS

# scheme://主机[:端口]；主机为域名 / IPv4 或带方括号的 IPv6
_ORIGIN_RE = re.compile(r"^(https?)://(\[[0-9a-f:.]+\]|[a-z0-9.-]+)(?::(\d{1,5}))?$", re.IGNORECASE)


def parse_cors_origins(raw: str) -> list[str]:
    """逗号分隔的来源 → 去重后的列表（转小写）。不合格时抛 ValueError，指出是哪一项。

    浏览器发出的 Origin 只有 scheme://主机[:端口]，带路径或结尾 / 的写法永远匹配不上，所以直接拒绝；不支持 *。
    """
    origins: list[str] = []
    for item in (part.strip() for part in raw.split(",")):
        if not item:
            continue
        match = _ORIGIN_RE.match(item)
        if not match or (match.group(3) and int(match.group(3)) > 65535):
            raise ValueError(
                f"CORS_ALLOW_ORIGINS 中的 {item!r} 不合法：格式为 http(s)://主机[:端口]，"
                "不带路径和结尾的 /，不支持 *"
            )
        origin = item.lower()
        if origin not in origins:
            origins.append(origin)
    return origins


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
    # 日志级别（E-2）：DEBUG / INFO / WARNING / ERROR，不区分大小写
    log_level: str = "INFO"

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
    # 修改密码：按用户，防止持有凭证的人反复猜原密码（第一段安全自查 P4）
    rate_limit_change_password_per_user: int = Field(10, ge=1)
    rate_limit_change_password_window_seconds: int = Field(3600, ge=1, le=86400)

    # 输入上限（S-5）：生成与保存记录的词表超限返回 422；请求体超限返回 413
    compose_max_words: int = Field(20, ge=1)
    compose_max_word_length: int = Field(40, ge=1)
    max_upload_bytes: int = Field(10 * 1024 * 1024, ge=1)  # /ocr/recognize 整个请求体
    max_request_bytes: int = Field(1024 * 1024, ge=1)  # 其他 /api/ 接口
    history_max_page_size: int = Field(50, ge=1)

    # CORS 白名单（S-3a）：逗号分隔，默认为空 = 不允许任何跨域来源。
    # 生产环境 Web 由后端同源托管、移动端 App 不受 CORS 限制，都不需要；本地 flutter run -d chrome 时在 .env 中设置
    cors_allow_origins: str = ""
    # 已废弃（从未生效）：保留字段只为兼容仍写着它的 .env（未定义的键会让启动失败），启动时警告；收尾时删除
    frontend_url: Optional[str] = None

    @field_validator("cors_allow_origins")
    @classmethod
    def _validate_cors_allow_origins(cls, value: str) -> str:
        parse_cors_origins(value)
        return value

    @field_validator("log_level")
    @classmethod
    def _validate_log_level(cls, value: str) -> str:
        level = value.strip().upper()
        if level not in LOG_LEVELS:
            raise ValueError(f"LOG_LEVEL 必须是 {' / '.join(LOG_LEVELS)} 之一")
        return level

    @property
    def cors_origins(self) -> list[str]:
        return parse_cors_origins(self.cors_allow_origins)

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
