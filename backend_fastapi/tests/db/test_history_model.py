"""HistoryModel（MySQL）：增删改查、分页、搜索转义、时间、并发。"""
import asyncio
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.models.history import HistoryModel
from app.schemas.history import SaveRecordRequest, UpdateRecordRequest


def make_request(**overrides) -> SaveRecordRequest:
    data = {
        "image_url": "photo.jpg",
        "words": ["apple", "library"],
        "english_story": "I read a book about an apple in the library.",
        "chinese_translation": "我在图书馆 (library) 读了一本关于苹果 (apple) 的书。",
        "english_blank": "I read a book about an ___ in the ___.",
        "chinese_blank": "我在 ___ (library) 读了一本关于 ___ (apple) 的书。",
    }
    data.update(overrides)
    return SaveRecordRequest(**data)


@pytest.fixture
def history(db_session):
    return HistoryModel(db_session)


async def save_many(history, stories):
    return [await history.save(make_request(english_story=s, words=[f"w{i}"])) for i, s in enumerate(stories)]


# ---- save / get_by_id -------------------------------------------------------

async def test_save_and_read_back(history):
    emoji_story = "A happy cat 🐱 reads."
    record_id = await history.save(make_request(english_story=emoji_story, words=["cat", "café"]))
    assert isinstance(record_id, int) and record_id > 0

    rec = await history.get_by_id(record_id)
    assert rec.english_story == emoji_story
    assert rec.words == ["cat", "café"]
    assert rec.chinese_translation.startswith("我在图书馆")
    assert rec.image_name == "photo.jpg"
    assert rec.is_favorite is False
    assert rec.notes is None


async def test_defaults_for_new_optional_fields(history):
    rec = await history.get_by_id(await history.save(make_request()))
    assert rec.difficulty == "intermediate"
    assert rec.is_degraded is False


async def test_optional_fields_are_stored(history):
    rec_id = await history.save(make_request(difficulty="advanced", is_degraded=True))
    rec = await history.get_by_id(rec_id)
    assert rec.difficulty == "advanced"
    assert rec.is_degraded is True


async def test_created_at_is_utc_now(history):
    before = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(seconds=5)
    rec = await history.get_by_id(await history.save(make_request()))
    after = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(seconds=5)
    assert before <= rec.created_at <= after
    assert rec.created_at.microsecond % 1000 == 0  # DATETIME(3)：毫秒精度
    assert rec.updated_at == rec.created_at


async def test_get_missing_returns_none(history):
    assert await history.get_by_id(999_999) is None


# ---- get_list：分页与排序 ---------------------------------------------------

async def test_list_newest_first_with_id_tiebreak(history):
    ids = await save_many(history, [f"story {i}" for i in range(5)])
    records, total = await history.get_list(page=1, page_size=20, search="")
    assert total == 5
    assert [r.id for r in records] == sorted(ids, reverse=True)


async def test_pagination(history):
    ids = sorted(await save_many(history, [f"story {i}" for i in range(7)]), reverse=True)
    page1, total = await history.get_list(page=1, page_size=3, search="")
    page3, _ = await history.get_list(page=3, page_size=3, search="")
    beyond, total_beyond = await history.get_list(page=4, page_size=3, search="")
    assert total == 7 and total_beyond == 7
    assert [r.id for r in page1] == ids[:3]
    assert [r.id for r in page3] == ids[6:]
    assert beyond == []


# ---- get_list：搜索 ---------------------------------------------------------

async def test_search_matches_story_and_words(history):
    await history.save(make_request(english_story="The moon is bright.", words=["moon"]))
    await history.save(make_request(english_story="Nothing here.", words=["telescope"]))
    await history.save(make_request(english_story="Other text.", words=["sun"]))

    by_story, n1 = await history.get_list(page=1, page_size=20, search="bright")
    by_word, n2 = await history.get_list(page=1, page_size=20, search="telescope")
    assert n1 == 1 and by_story[0].english_story == "The moon is bright."
    assert n2 == 1 and by_word[0].words == ["telescope"]


@pytest.mark.parametrize("term", ["APPLE", "Apple", "apple"])
async def test_search_is_case_insensitive_for_story_and_words(history, term):
    await history.save(make_request(english_story="no fruit here", words=["Apple"]))
    await history.save(make_request(english_story="An apple a day.", words=["day"]))
    _, total = await history.get_list(page=1, page_size=20, search=term)
    assert total == 2


@pytest.mark.parametrize("term, expected", [
    ("%", "100% sure"),
    ("_", "snake_case words"),
    ("/", "either/or"),
    ("\\", "back\\slash"),
    ("'", "it's fine"),
])
async def test_search_wildcards_are_literal(history, term, expected):
    await save_many(history, ["100% sure", "snake_case words", "either/or", "back\\slash", "it's fine", "plain"])
    records, total = await history.get_list(page=1, page_size=20, search=term)
    assert total == 1
    assert records[0].english_story == expected


async def test_search_injection_text_is_literal(history):
    await save_many(history, ["one", "two"])
    _, total = await history.get_list(page=1, page_size=20, search="' OR 1=1 -- ")
    assert total == 0


async def test_search_does_not_match_chinese_translation(history):
    """固定现状：搜索只匹配英文短文与单词，不匹配中文翻译（清单外遗留问题）。"""
    await history.save(make_request())
    _, total = await history.get_list(page=1, page_size=20, search="图书馆")
    assert total == 0


async def test_blank_search_returns_all(history):
    await save_many(history, ["a", "b"])
    _, total = await history.get_list(page=1, page_size=20, search="   ")
    assert total == 2


# ---- update / delete --------------------------------------------------------

async def test_update_favorite_and_notes(history, db_session):
    rec_id = await history.save(make_request())
    original = (await history.get_by_id(rec_id)).updated_at
    await asyncio.sleep(0.01)

    assert await history.update(rec_id, UpdateRecordRequest(is_favorite=True, notes="复习")) is True
    db_session.expire_all()
    rec = await history.get_by_id(rec_id)
    assert rec.is_favorite is True
    assert rec.notes == "复习"
    assert rec.updated_at > original


async def test_update_with_no_fields_returns_false(history):
    rec_id = await history.save(make_request())
    assert await history.update(rec_id, UpdateRecordRequest()) is False


async def test_update_missing_returns_false(history):
    assert await history.update(999_999, UpdateRecordRequest(is_favorite=True)) is False


async def test_delete(history):
    rec_id = await history.save(make_request())
    assert await history.delete(rec_id) is True
    assert await history.get_by_id(rec_id) is None
    assert await history.delete(rec_id) is False


# ---- 并发 -------------------------------------------------------------------

async def test_concurrent_saves(db_engine):
    sessionmaker = async_sessionmaker(db_engine, expire_on_commit=False)

    async def save_one(i):
        async with sessionmaker() as session:
            return await HistoryModel(session).save(make_request(english_story=f"story {i}"))

    ids = await asyncio.gather(*(save_one(i) for i in range(20)))
    assert len(set(ids)) == 20
    async with sessionmaker() as session:
        _, total = await HistoryModel(session).get_list(page=1, page_size=50, search="")
    assert total == 20

