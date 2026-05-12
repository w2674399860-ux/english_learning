from fastapi import APIRouter, HTTPException
from app.schemas.history import SaveRecordRequest, UpdateRecordRequest
from app.models.history import HistoryModel

router = APIRouter()
history_model = HistoryModel()


@router.post("/save")
async def save_record(request: SaveRecordRequest):
    record_id = await history_model.save(request)
    return {"id": record_id, "message": "Record saved successfully"}


@router.get("/records")
async def get_records(page: int = 1, page_size: int = 20, search: str = ""):
    records, total = await history_model.get_list(
        page=page, page_size=page_size, search=search
    )
    return {"records": records, "total": total, "page": page, "page_size": page_size}


@router.get("/records/{record_id}")
async def get_record(record_id: int):
    record = await history_model.get_by_id(record_id)
    if not record:
        raise HTTPException(status_code=404, detail="Record not found")
    return record


@router.put("/records/{record_id}")
async def update_record(record_id: int, request: UpdateRecordRequest):
    success = await history_model.update(record_id, request)
    if not success:
        raise HTTPException(status_code=404, detail="Record not found")
    return {"message": "Record updated successfully"}


@router.delete("/records/{record_id}")
async def delete_record(record_id: int):
    success = await history_model.delete(record_id)
    if not success:
        raise HTTPException(status_code=404, detail="Record not found")
    return {"message": "Record deleted successfully"}
