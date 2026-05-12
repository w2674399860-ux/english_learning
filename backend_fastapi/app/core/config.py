from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # DeepSeek API
    deepseek_api_key: str = ""
    deepseek_api_base: str = "https://api.deepseek.com"

    # Database
    database_url: str = "sqlite:///./data/english_learning.db"

    # Server
    server_host: str = "0.0.0.0"
    server_port: int = 8000
    debug: bool = True

    # OCR Service
    ocr_service_url: str = "http://localhost:8866"
    ocr_mode: str = "auto"  # "docker", "mock", or "auto" (try docker, fallback to mock)

    # CORS
    frontend_url: str = "http://localhost:3000"

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
