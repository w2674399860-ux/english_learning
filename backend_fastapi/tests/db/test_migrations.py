"""Alembic 迁移：可重复执行、表结构符合设计、可回退（只在测试库上）。

这些测试是同步函数：alembic 的 env.py 内部用 asyncio.run，不能在运行中的事件循环里调用。
"""
import asyncio

import pytest
from alembic import command
from alembic.script import ScriptDirectory
from conftest import alembic_config, make_test_engine
from sqlalchemy import text
from sqlalchemy.exc import DBAPIError


def query(sql: str, **params):
    async def run():
        engine = make_test_engine()
        try:
            async with engine.connect() as conn:
                return (await conn.execute(text(sql), params)).all()
        finally:
            await engine.dispose()

    return asyncio.run(run())


def current_revision():
    rows = query("SELECT version_num FROM alembic_version")
    return [r[0] for r in rows]


def head_revision():
    return ScriptDirectory.from_config(alembic_config()).get_current_head()


def test_upgrade_head_twice_is_noop(migrated_test_db):
    cfg = alembic_config()
    command.upgrade(cfg, "head")
    command.upgrade(cfg, "head")
    assert current_revision() == [head_revision()]
    assert head_revision() == "0001"


def test_learning_records_columns(migrated_test_db):
    rows = query(
        "SELECT column_name, column_type, is_nullable, column_default, extra "
        "FROM information_schema.columns "
        "WHERE table_schema = DATABASE() AND table_name = 'learning_records' "
        "ORDER BY ordinal_position"
    )
    cols = {r[0]: r[1:] for r in rows}
    assert list(cols) == [
        "id", "words", "difficulty", "english_story", "chinese_translation",
        "english_blank", "chinese_blank", "is_favorite", "notes", "is_degraded",
        "image_name", "created_at", "updated_at",
    ]
    assert cols["id"][0] == "bigint unsigned" and "auto_increment" in cols["id"][3]
    assert cols["words"][:2] == ("json", "NO")
    assert cols["difficulty"][:3] == ("varchar(16)", "NO", "intermediate")
    for name in ("english_story", "chinese_translation", "english_blank", "chinese_blank"):
        assert cols[name][:2] == ("text", "NO")
    assert cols["is_favorite"][:3] == ("tinyint(1)", "NO", "0")
    assert cols["is_degraded"][:3] == ("tinyint(1)", "NO", "0")
    assert cols["notes"][:2] == ("text", "YES")
    assert cols["image_name"][:2] == ("varchar(255)", "YES")
    assert cols["created_at"][:3] == ("datetime(3)", "NO", "CURRENT_TIMESTAMP(3)")
    assert cols["updated_at"][:3] == ("datetime(3)", "NO", "CURRENT_TIMESTAMP(3)")
    assert "on update CURRENT_TIMESTAMP(3)" in cols["updated_at"][3]
    assert "user_id" not in cols  # A-2 再加


def test_table_charset_engine_and_index(migrated_test_db):
    [(engine, collation)] = query(
        "SELECT engine, table_collation FROM information_schema.tables "
        "WHERE table_schema = DATABASE() AND table_name = 'learning_records'"
    )
    assert engine == "InnoDB"
    assert collation == "utf8mb4_0900_ai_ci"
    index_cols = query(
        "SELECT column_name FROM information_schema.statistics "
        "WHERE table_schema = DATABASE() AND table_name = 'learning_records' "
        "AND index_name = 'idx_records_created' ORDER BY seq_in_index"
    )
    assert [r[0] for r in index_cols] == ["created_at", "id"]


def test_difficulty_check_constraint_is_enforced(clean_db):
    async def run():
        engine = make_test_engine()
        try:
            async with engine.begin() as conn:
                await conn.execute(text(
                    "INSERT INTO learning_records (words, difficulty, english_story, chinese_translation, "
                    "english_blank, chinese_blank) VALUES ('[]', 'expert', 'a', 'b', 'c', 'd')"
                ))
        finally:
            await engine.dispose()

    with pytest.raises(DBAPIError, match="check constraint|Check constraint"):
        asyncio.run(run())


def test_downgrade_then_upgrade_roundtrip_on_test_db(migrated_test_db):
    cfg = alembic_config()
    command.downgrade(cfg, "base")
    assert query("SHOW TABLES LIKE 'learning_records'") == []
    command.upgrade(cfg, "head")
    assert current_revision() == [head_revision()]
    assert len(query("SHOW TABLES LIKE 'learning_records'")) == 1

