from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.input_limits import check_word_list
from app.auth.dependencies import CurrentUser, get_current_user
from app.core.config import settings
from app.db.session import get_session
from app.models.history import HistoryModel
from app.schemas.history import RecordOut, RecordPage, SaveRecordRequest, UpdateRecordRequest

router = APIRouter()

# 输入上限（CLAUDE.md 第 9 节 S3 与 D-1 方案），超限返回 422。page_size 上限可配置（HISTORY_MAX_PAGE_SIZE）
MAX_PAGE = 10_000
MAX_PAGE_SIZE = settings.history_max_page_size
MAX_SEARCH_LENGTH = 100


def get_history_model(
    user: CurrentUser = Depends(get_current_user), session: AsyncSession = Depends(get_session)
) -> HistoryModel:
    """当前用户的历史记录访问对象。user_id 只来自校验后的凭证。"""
    return HistoryModel(session, user.id)


@router.post("/save")
async def save_record(request: SaveRecordRequest, history: HistoryModel = Depends(get_history_model)):
    check_word_list(request.words)
    record_id = await history.save(request)
    return {"id": record_id, "message": "已保存"}


@router.get("/records", response_model=RecordPage)
async def get_records(
    page: int = Query(1, ge=1, le=MAX_PAGE),
    page_size: int = Query(20, ge=1, le=MAX_PAGE_SIZE),
    search: str = Query("", max_length=MAX_SEARCH_LENGTH),
    history: HistoryModel = Depends(get_history_model),
):
    records, total = await history.get_list(page=page, page_size=page_size, search=search)
    return RecordPage(
        records=[RecordOut.from_record(r) for r in records],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/records/{record_id}", response_model=RecordOut)
async def get_record(record_id: int, history: HistoryModel = Depends(get_history_model)):
    record = await history.get_by_id(record_id)
    if not record:
        raise HTTPException(status_code=404, detail="记录不存在")
    return RecordOut.from_record(record)


@router.put("/records/{record_id}")
async def update_record(
    record_id: int, request: UpdateRecordRequest, history: HistoryModel = Depends(get_history_model)
):
    success = await history.update(record_id, request)
    if not success:
        raise HTTPException(status_code=404, detail="记录不存在")
    return {"message": "已更新"}


@router.delete("/records/{record_id}")
async def delete_record(record_id: int, history: HistoryModel = Depends(get_history_model)):
    success = await history.delete(record_id)
    if not success:
        raise HTTPException(status_code=404, detail="记录不存在")
    return {"message": "已删除"}
