import sqlite3
import json
import os
from datetime import datetime
from typing import Optional
from app.schemas.history import SaveRecordRequest, UpdateRecordRequest

DB_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data")
DB_PATH = os.path.join(DB_DIR, "english_learning.db")


class HistoryModel:
    def __init__(self):
        os.makedirs(DB_DIR, exist_ok=True)
        self._init_db()

    def _get_connection(self):
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self):
        conn = self._get_connection()
        conn.execute("""
            CREATE TABLE IF NOT EXISTS learning_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                image_url TEXT,
                words TEXT,
                english_story TEXT,
                chinese_translation TEXT,
                english_blank TEXT,
                chinese_blank TEXT,
                is_favorite INTEGER DEFAULT 0,
                notes TEXT,
                created_at TEXT,
                updated_at TEXT
            )
        """)
        conn.commit()
        conn.close()

    async def save(self, request: SaveRecordRequest) -> int:
        now = datetime.now().isoformat()
        conn = self._get_connection()
        cursor = conn.execute(
            """INSERT INTO learning_records
               (image_url, words, english_story, chinese_translation,
                english_blank, chinese_blank, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                request.image_url,
                json.dumps(request.words, ensure_ascii=False),
                request.english_story,
                request.chinese_translation,
                request.english_blank,
                request.chinese_blank,
                now,
                now,
            ),
        )
        conn.commit()
        record_id = cursor.lastrowid
        conn.close()
        return record_id

    async def get_list(self, page: int = 1, page_size: int = 20, search: str = ""):
        conn = self._get_connection()
        offset = (page - 1) * page_size

        if search:
            where = "WHERE english_story LIKE ? OR words LIKE ?"
            params = [f"%{search}%", f"%{search}%"]
        else:
            where = ""
            params = []

        count_row = conn.execute(
            f"SELECT COUNT(*) as total FROM learning_records {where}", params
        ).fetchone()
        total = count_row["total"]

        rows = conn.execute(
            f"SELECT * FROM learning_records {where} ORDER BY created_at DESC LIMIT ? OFFSET ?",
            params + [page_size, offset],
        ).fetchall()

        records = [dict(row) for row in rows]
        for r in records:
            r["words"] = json.loads(r["words"])

        conn.close()
        return records, total

    async def get_by_id(self, record_id: int) -> Optional[dict]:
        conn = self._get_connection()
        row = conn.execute(
            "SELECT * FROM learning_records WHERE id = ?", (record_id,)
        ).fetchone()
        conn.close()

        if row:
            result = dict(row)
            result["words"] = json.loads(result["words"])
            return result
        return None

    async def update(self, record_id: int, request: UpdateRecordRequest) -> bool:
        conn = self._get_connection()
        updates = []
        params = []

        if request.is_favorite is not None:
            updates.append("is_favorite = ?")
            params.append(1 if request.is_favorite else 0)
        if request.notes is not None:
            updates.append("notes = ?")
            params.append(request.notes)

        if not updates:
            conn.close()
            return False

        updates.append("updated_at = ?")
        params.append(datetime.now().isoformat())
        params.append(record_id)

        cursor = conn.execute(
            f"UPDATE learning_records SET {', '.join(updates)} WHERE id = ?",
            params,
        )
        conn.commit()
        affected = cursor.rowcount
        conn.close()
        return affected > 0

    async def delete(self, record_id: int) -> bool:
        conn = self._get_connection()
        cursor = conn.execute(
            "DELETE FROM learning_records WHERE id = ?", (record_id,)
        )
        conn.commit()
        affected = cursor.rowcount
        conn.close()
        return affected > 0
