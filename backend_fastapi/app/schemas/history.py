from pydantic import BaseModel
from typing import Optional


class SaveRecordRequest(BaseModel):
    image_url: str
    words: list[str]
    english_story: str
    chinese_translation: str
    english_blank: str
    chinese_blank: str


class UpdateRecordRequest(BaseModel):
    is_favorite: Optional[bool] = None
    notes: Optional[str] = None
