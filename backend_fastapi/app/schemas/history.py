from typing import Literal, Optional

from pydantic import BaseModel

from app.schemas.common import to_utc_iso

Difficulty = Literal["beginner", "intermediate", "advanced"]


class SaveRecordRequest(BaseModel):
    image_url: str
    words: list[str]
    english_story: str
    chinese_translation: str
    english_blank: str
    chinese_blank: str
    # D-1 新增，可选：前端到第二段才开始发送
    difficulty: Difficulty = "intermediate"
    is_degraded: bool = False


class UpdateRecordRequest(BaseModel):
    is_favorite: Optional[bool] = None
    notes: Optional[str] = None


class RecordOut(BaseModel):
    """历史记录响应。

    D-1 兼容层（U-12 前端改造时统一清理）：
    - 数据库列 image_name，接口仍叫 image_url
    - is_favorite 输出 0 / 1：前端用 `as int?` 读取，布尔值会让它抛异常
    """

    id: int
    image_url: Optional[str]
    words: list[str]
    difficulty: Difficulty
    is_degraded: bool
    english_story: str
    chinese_translation: str
    english_blank: str
    chinese_blank: str
    is_favorite: int
    notes: Optional[str]
    created_at: str
    updated_at: str

    @classmethod
    def from_record(cls, record) -> "RecordOut":
        return cls(
            id=record.id,
            image_url=record.image_name,
            words=record.words,
            difficulty=record.difficulty,
            is_degraded=record.is_degraded,
            english_story=record.english_story,
            chinese_translation=record.chinese_translation,
            english_blank=record.english_blank,
            chinese_blank=record.chinese_blank,
            is_favorite=1 if record.is_favorite else 0,
            notes=record.notes,
            created_at=to_utc_iso(record.created_at),
            updated_at=to_utc_iso(record.updated_at),
        )


class RecordPage(BaseModel):
    records: list[RecordOut]
    total: int
    page: int
    page_size: int
