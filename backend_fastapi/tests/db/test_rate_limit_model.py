"""S-5 限流计数（连测试库）：一条语句原子计数、并发准确、按窗口分行、过期清理。"""
import asyncio
from datetime import datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import async_sessionmaker

from app.models.rate_limit import RateLimitCounter
from app.ratelimit import limiter

NOW = datetime(2026, 10, 7, 12, 0, 30)
RULE = limiter.Rule("ocr", 2, 60)


async def test_hit_counts_and_compares_with_limit(db_session):
    decisions = [await limiter.hit(db_session, RULE, "u:1", now=NOW) for _ in range(3)]
    assert [(d.count, d.allowed, d.retry_after) for d in decisions] == [(1, True, 30), (2, True, 30), (3, False, 30)]
    rows = (await db_session.execute(select(RateLimitCounter))).scalars().all()
    assert [(r.scope, r.subject, r.window_start, r.count) for r in rows] == [
        ("ocr", "u:1", datetime(2026, 10, 7, 12, 0), 3)
    ]


async def test_hit_commits_immediately(db_engine, db_session):
    await limiter.hit(db_session, RULE, "u:1", now=NOW)
    async with async_sessionmaker(db_engine)() as other:
        assert await other.scalar(select(RateLimitCounter.count)) == 1


async def test_scopes_subjects_and_windows_are_separate_rows(db_session):
    await limiter.hit(db_session, RULE, "u:1", now=NOW)
    await limiter.hit(db_session, RULE, "u:2", now=NOW)
    await limiter.hit(db_session, limiter.Rule("compose", 2, 60), "u:1", now=NOW)
    await limiter.hit(db_session, RULE, "u:1", now=NOW + timedelta(seconds=30))
    assert await db_session.scalar(select(func.count()).select_from(RateLimitCounter)) == 4


async def test_concurrent_hits_on_separate_connections_are_exact(db_engine):
    """10 个独立连接同时计数同一行（额度 5）：计数值恰好是 1..10，恰好 5 个放行。"""
    sessionmaker = async_sessionmaker(db_engine, expire_on_commit=False)
    rule = limiter.Rule("compose", 5, 86400)

    async def one():
        async with sessionmaker() as s:
            return await limiter.hit(s, rule, "u:7", now=NOW)

    decisions = await asyncio.gather(*[one() for _ in range(10)])
    assert sorted(d.count for d in decisions) == list(range(1, 11))
    assert sum(d.allowed for d in decisions) == 5


async def _insert(session, *window_starts):
    for i, ws in enumerate(window_starts):
        session.add(RateLimitCounter(scope="login", subject=f"ip:203.0.113.{i}", window_start=ws, count=1))
    await session.commit()


async def test_cleanup_removes_windows_older_than_retention(db_session):
    old = [NOW - timedelta(days=3), NOW - timedelta(days=2, seconds=1)]
    keep = [NOW - timedelta(days=2), NOW - timedelta(days=1), NOW]
    await _insert(db_session, *old, *keep)
    assert await limiter.count_expired(db_session, now=NOW) == 2
    assert await limiter.cleanup(db_session, now=NOW) == 2
    remaining = (await db_session.execute(select(RateLimitCounter.window_start))).scalars().all()
    assert sorted(remaining) == sorted(keep)


async def test_cleanup_deletes_in_batches(db_session, monkeypatch):
    monkeypatch.setattr(limiter, "CLEANUP_BATCH_SIZE", 2)
    await _insert(db_session, *[NOW - timedelta(days=5)] * 5)
    assert await limiter.cleanup(db_session, now=NOW) == 5
    assert await db_session.scalar(select(func.count()).select_from(RateLimitCounter)) == 0
