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


def index_columns(table: str) -> dict[str, list[str]]:
    rows = query(
        "SELECT index_name, column_name FROM information_schema.statistics "
        "WHERE table_schema = DATABASE() AND table_name = :t ORDER BY index_name, seq_in_index",
        t=table,
    )
    result: dict[str, list[str]] = {}
    for name, col in rows:
        result.setdefault(name, []).append(col)
    return result


def head_revision():
    return ScriptDirectory.from_config(alembic_config()).get_current_head()


def test_upgrade_head_twice_is_noop(migrated_test_db):
    cfg = alembic_config()
    command.upgrade(cfg, "head")
    command.upgrade(cfg, "head")
    assert current_revision() == [head_revision()]
    assert head_revision() == "0003"


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
        "image_name", "created_at", "updated_at", "user_id",
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
    assert cols["user_id"][:2] == ("bigint unsigned", "YES")  # 旧记录可为空（A-2）


def test_table_charset_engine_and_index(migrated_test_db):
    [(engine, collation)] = query(
        "SELECT engine, table_collation FROM information_schema.tables "
        "WHERE table_schema = DATABASE() AND table_name = 'learning_records'"
    )
    assert engine == "InnoDB"
    assert collation == "utf8mb4_0900_ai_ci"
    assert index_columns("learning_records") == {
        "PRIMARY": ["id"],
        "idx_records_user_created": ["user_id", "created_at", "id"],
        "idx_records_user_fav": ["user_id", "is_favorite"],
    }


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


# ---- A-2：users / sessions / learning_records.user_id -----------------------

def columns(table: str) -> dict[str, tuple]:
    rows = query(
        "SELECT column_name, column_type, is_nullable, column_default, character_set_name, collation_name "
        "FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = :t "
        "ORDER BY ordinal_position",
        t=table,
    )
    return {r[0]: r[1:] for r in rows}


def foreign_keys(table: str) -> set[tuple]:
    rows = query(
        "SELECT k.column_name, k.referenced_table_name, k.referenced_column_name, r.delete_rule "
        "FROM information_schema.key_column_usage k "
        "JOIN information_schema.referential_constraints r "
        "  ON r.constraint_schema = k.constraint_schema AND r.constraint_name = k.constraint_name "
        "WHERE k.table_schema = DATABASE() AND k.table_name = :t",
        t=table,
    )
    return {tuple(r) for r in rows}


def test_users_table(migrated_test_db):
    cols = columns("users")
    assert list(cols) == [
        "id", "username", "password_hash", "is_active", "password_changed_at",
        "last_login_at", "created_at", "updated_at",
    ]
    assert cols["username"][:2] == ("varchar(20)", "NO")
    assert cols["password_hash"][:2] == ("varchar(255)", "NO")
    assert cols["is_active"][:3] == ("tinyint(1)", "NO", "1")
    assert index_columns("users") == {"PRIMARY": ["id"], "uk_users_username": ["username"]}


def test_sessions_table(migrated_test_db):
    cols = columns("sessions")
    assert list(cols) == ["id", "user_id", "token_hash", "created_at", "expires_at", "revoked_at", "last_used_at"]
    assert cols["token_hash"][:2] == ("char(64)", "NO")
    assert cols["token_hash"][3:] == ("ascii", "ascii_bin")
    assert cols["revoked_at"][1] == "YES"
    assert index_columns("sessions") == {
        "PRIMARY": ["id"],
        "uk_sessions_token_hash": ["token_hash"],
        "idx_sessions_user": ["user_id"],
        "idx_sessions_expires": ["expires_at"],
    }


def test_foreign_keys_cascade(migrated_test_db):
    assert foreign_keys("sessions") == {("user_id", "users", "id", "CASCADE")}
    assert foreign_keys("learning_records") == {("user_id", "users", "id", "CASCADE")}


# 超过 20 位由 VARCHAR(20) 拒绝（严格模式 Data too long），这里只测 CHECK 约束
@pytest.mark.parametrize("username", ["Alice", "ab", "bad-name", "with space", "café"])
def test_username_check_constraint(clean_db, username):
    async def run():
        engine = make_test_engine()
        try:
            async with engine.begin() as conn:
                await conn.execute(
                    text("INSERT INTO users (username, password_hash) VALUES (:u, 'x')"), {"u": username}
                )
        finally:
            await engine.dispose()

    with pytest.raises(DBAPIError, match="check constraint|Check constraint"):
        asyncio.run(run())


# ---- S-5：rate_limit_counters ---------------------------------------------------

def test_rate_limit_counters_table(migrated_test_db):
    cols = columns("rate_limit_counters")
    assert list(cols) == ["scope", "subject", "window_start", "count"]
    assert cols["scope"][:2] == ("varchar(32)", "NO")
    assert cols["subject"][:2] == ("varchar(64)", "NO")
    assert cols["scope"][3:] == cols["subject"][3:] == ("ascii", "ascii_bin")
    assert cols["window_start"][:2] == ("datetime", "NO")
    assert cols["count"][:3] == ("int unsigned", "NO", "0")
    assert index_columns("rate_limit_counters") == {
        "PRIMARY": ["scope", "subject", "window_start"],
        "idx_rl_window": ["window_start"],
    }
    assert foreign_keys("rate_limit_counters") == set()


def test_downgrade_one_step_drops_only_rate_limit_counters(migrated_test_db):
    cfg = alembic_config()
    command.downgrade(cfg, "0002")
    assert query("SHOW TABLES LIKE 'rate_limit_counters'") == []
    assert len(query("SHOW TABLES LIKE 'sessions'")) == 1
    command.upgrade(cfg, "head")
    assert current_revision() == ["0003"]
