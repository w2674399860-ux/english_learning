from sqlalchemy import CHAR, cast, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.learning_record import LearningRecord
from app.schemas.history import SaveRecordRequest, UpdateRecordRequest


class HistoryModel:
    """学习记录的数据访问。每个请求一个实例，会话由 FastAPI 依赖项注入。"""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def save(self, request: SaveRecordRequest) -> int:
        record = LearningRecord(
            image_name=request.image_url,
            words=request.words,
            difficulty=request.difficulty,
            is_degraded=request.is_degraded,
            english_story=request.english_story,
            chinese_translation=request.chinese_translation,
            english_blank=request.english_blank,
            chinese_blank=request.chinese_blank,
        )
        self.session.add(record)
        await self.session.commit()
        return record.id

    async def get_list(
        self, page: int = 1, page_size: int = 20, search: str = ""
    ) -> tuple[list[LearningRecord], int]:
        stmt = select(LearningRecord)
        term = search.strip()
        if term:
            # autoescape：把 / % _ 转义并加 ESCAPE '/'，用户输入按字面匹配；值走参数绑定。
            # CAST(JSON AS CHAR) 的排序规则跟随连接的排序规则（连接若为 utf8mb4_bin 就区分大小写）；
            # 显式指定，让搜索行为不依赖连接配置，与短文列一致。
            stmt = stmt.where(or_(
                LearningRecord.english_story.contains(term, autoescape=True),
                cast(LearningRecord.words, CHAR)
                .collate("utf8mb4_0900_ai_ci")
                .contains(term, autoescape=True),
            ))

        total = await self.session.scalar(select(func.count()).select_from(stmt.subquery()))
        rows = await self.session.scalars(
            stmt.order_by(LearningRecord.created_at.desc(), LearningRecord.id.desc())
            .limit(page_size)
            .offset((page - 1) * page_size)
        )
        return list(rows), total

    async def get_by_id(self, record_id: int) -> LearningRecord | None:
        return await self.session.get(LearningRecord, record_id)

    async def update(self, record_id: int, request: UpdateRecordRequest) -> bool:
        if request.is_favorite is None and request.notes is None:
            return False
        record = await self.session.get(LearningRecord, record_id)
        if record is None:
            return False
        if request.is_favorite is not None:
            record.is_favorite = request.is_favorite
        if request.notes is not None:
            record.notes = request.notes
        await self.session.commit()
        return True

    async def delete(self, record_id: int) -> bool:
        record = await self.session.get(LearningRecord, record_id)
        if record is None:
            return False
        await self.session.delete(record)
        await self.session.commit()
        return True
