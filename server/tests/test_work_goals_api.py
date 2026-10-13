from datetime import date

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import text

from app.db.session import engine
from app.main import app


@pytest_asyncio.fixture(autouse=True)
async def clean_goals():
    async with engine.begin() as connection:
        await connection.execute(
            text("TRUNCATE daily_work_goals, weekly_work_goals RESTART IDENTITY")
        )
    yield


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://test",
    ) as test_client:
        yield test_client


def payload(**targets):
    return {
        "daily_goals": [
            {
                "weekday": weekday,
                "target_minutes": targets.get(str(weekday), 0),
            }
            for weekday in range(1, 8)
        ],
    }


@pytest.mark.asyncio
async def test_weekday_changes_start_on_their_next_occurrence(client):
    response = await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-09"},  # Wednesday
        json=payload(**{"1": 60, "3": 90, "5": 120}),
    )
    assert response.status_code == 200
    body = response.json()
    assert body["weekly_goal_minutes"] == 210
    assert body["weekly_goal_effective_from"] == "2026-09-07"

    async with engine.connect() as connection:
        versions = list(
            (
                await connection.execute(
                    text(
                        "SELECT weekday, target_minutes, valid_from "
                        "FROM daily_work_goals ORDER BY weekday"
                    )
                )
            ).all()
        )
    assert versions == [
        (1, 60, date(2026, 9, 14)),
        (3, 90, date(2026, 9, 9)),
        (5, 120, date(2026, 9, 11)),
    ]


@pytest.mark.asyncio
async def test_passed_weekday_change_preserves_current_week_and_history(client):
    first = await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-07"},
        json=payload(**{"1": 60}),
    )
    second = await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-09"},
        json=payload(**{"1": 120}),
    )
    assert first.status_code == second.status_code == 200
    assert second.json()["weekly_goal_minutes"] == 60

    async with engine.connect() as connection:
        versions = list(
            (
                await connection.execute(
                    text(
                        "SELECT target_minutes, valid_from, valid_until "
                        "FROM daily_work_goals WHERE weekday = 1 ORDER BY valid_from"
                    )
                )
            ).all()
        )
    assert versions == [
        (60, date(2026, 9, 7), date(2026, 9, 13)),
        (120, date(2026, 9, 14), None),
    ]

    historical = await client.get(
        "/api/v1/work-goals",
        params={"date": "2026-09-07"},
    )
    following = await client.get(
        "/api/v1/work-goals",
        params={"date": "2026-09-14"},
    )
    assert historical.json()["weekly_goal_minutes"] == 60
    assert following.json()["weekly_goal_minutes"] == 120


@pytest.mark.asyncio
async def test_weekly_goal_sums_effective_goal_for_each_monday_to_sunday_date(client):
    initial = {str(weekday): weekday * 10 for weekday in range(1, 8)}
    await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-07"},
        json=payload(**initial),
    )
    changed = dict(initial)
    changed.update({"1": 100, "3": 300, "5": 500})
    response = await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-09"},
        json=payload(**changed),
    )
    assert response.status_code == 200
    assert response.json()["weekly_goal_minutes"] == 1000

    next_week = await client.get(
        "/api/v1/work-goals",
        params={"date": "2026-09-14"},
    )
    assert next_week.json()["weekly_goal_minutes"] == 1090


@pytest.mark.asyncio
async def test_derived_goal_uses_local_monday_to_sunday_boundaries(client):
    await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-07"},
        json=payload(**{"7": 70}),
    )
    await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-14"},
        json=payload(**{"7": 140}),
    )

    previous_sunday = await client.get(
        "/api/v1/work-goals",
        params={"date": "2026-09-13"},
    )
    next_monday = await client.get(
        "/api/v1/work-goals",
        params={"date": "2026-09-14"},
    )
    assert previous_sunday.json()["weekly_goal_minutes"] == 70
    assert previous_sunday.json()["weekly_goal_effective_from"] == "2026-09-07"
    assert next_monday.json()["weekly_goal_minutes"] == 140
    assert next_monday.json()["weekly_goal_effective_from"] == "2026-09-14"


@pytest.mark.asyncio
async def test_weekly_goal_is_read_only_and_legacy_storage_is_untouched(client):
    invalid = payload(**{"1": 60})
    invalid["weekly_goal_minutes"] = 999
    rejected = await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-07"},
        json=invalid,
    )
    assert rejected.status_code == 422

    accepted = await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-07"},
        json=payload(**{"1": 60}),
    )
    assert accepted.status_code == 200
    assert accepted.json()["weekly_goal_minutes"] == 60
    async with engine.connect() as connection:
        count = await connection.scalar(text("SELECT count(*) FROM weekly_work_goals"))
    assert count == 0


@pytest.mark.asyncio
async def test_work_goals_require_each_weekday_once(client):
    invalid = payload()
    invalid["daily_goals"] = invalid["daily_goals"][:-1]
    response = await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-07"},
        json=invalid,
    )
    assert response.status_code == 422
