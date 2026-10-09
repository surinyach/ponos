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


def payload(monday=0, weekly=0):
    return {
        "daily_goals": [
            {"weekday": weekday, "target_minutes": monday if weekday == 1 else 0}
            for weekday in range(1, 8)
        ],
        "weekly_goal_minutes": weekly,
    }


@pytest.mark.asyncio
async def test_weekday_goals_keep_historical_versions(client):
    first = await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-07"},
        json=payload(monday=60),
    )
    second = await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-14"},
        json=payload(monday=120),
    )
    assert first.status_code == second.status_code == 200

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


@pytest.mark.asyncio
async def test_weekly_goal_activates_next_week_and_keeps_started_week(client):
    await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-02"},
        json=payload(weekly=300),
    )
    response = await client.put(
        "/api/v1/work-goals",
        params={"date": "2026-09-09"},
        json=payload(weekly=480),
    )
    assert response.status_code == 200
    assert response.json()["weekly_goal_effective_from"] == "2026-09-14"

    async with engine.connect() as connection:
        versions = list(
            (
                await connection.execute(
                    text(
                        "SELECT target_minutes, valid_from, valid_until "
                        "FROM weekly_work_goals ORDER BY valid_from"
                    )
                )
            ).all()
        )
    assert versions == [
        (300, date(2026, 9, 7), date(2026, 9, 13)),
        (480, date(2026, 9, 14), None),
    ]


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
