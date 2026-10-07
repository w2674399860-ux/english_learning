from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_session
from app.models.history import HistoryModel
from app.schemas.history import RecordOut, RecordPage, SaveRecordRequest, UpdateRecordRequest

router = APIRouter()

# 输入上限（CLAUDE.md 第 9 节 S3 与 D-1 方案），超限返回 422
MAX_PAGE = 10_000
MAX_PAGE_SIZE = 50
MAX_SEARCH_LENGTH = 100


def get_history_model(session: AsyncSession = Depends(get_session)) -> HistoryModel:
    return HistoryModel(session)


@router.post("/save")
async def save_record(request: SaveRecordRequest, history: HistoryModel = Depends(get_history_model)):
    record_id = await history.save(request)
    return {"id": record_id, "message": "Record saved successfully"}


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
        raise HTTPException(status_code=404, detail="Record not found")
    return RecordOut.from_record(record)


@router.put("/records/{record_id}")
async def update_record(
    record_id: int, request: UpdateRecordRequest, history: HistoryModel = Depends(get_history_model)
):
    success = await history.update(record_id, request)
    if not success:
        raise HTTPException(status_code=404, detail="Record not found")
    return {"message": "Record updated successfully"}


@router.delete("/records/{record_id}")
async def delete_record(record_id: int, history: HistoryModel = Depends(get_history_model)):
    success = await history.delete(record_id)
    if not success:
        raise HTTPException(status_code=404, detail="Record not found")
    return {"message": "Record deleted successfully"}
