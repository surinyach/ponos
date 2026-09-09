from datetime import datetime, timezone

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import text

from app.db.session import engine
from app.main import app


@pytest_asyncio.fixture(autouse=True)
async def clean_database():
    async with engine.begin() as connection:
        await connection.execute(
            text(
                "TRUNCATE timer_executions, focus_area_targets, focus_areas "
                "RESTART IDENTITY CASCADE"
            )
        )
    yield


@pytest_asyncio.fixture
async def client():
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://test",
    ) as test_client:
        yield test_client


async def create_area(client, name, priority, weekday=1, minutes=60):
    response = await client.post(
        "/api/v1/focus-areas",
        json={
            "name": name,
            "priority": priority,
            "targets": [
                {
                    "weekday": weekday,
                    "target_minutes": minutes,
                    "valid_from": "2026-09-07",
                }
            ],
        },
    )
    assert response.status_code == 201
    return response.json()


@pytest.mark.asyncio
async def test_today_overview_uses_local_day_and_valid_target_version(client):
    area = await create_area(client, "Primary", 2)
    await client.patch(
        f"/api/v1/focus-areas/{area['id']}",
        json={
            "targets": [
                {
                    "weekday": 1,
                    "target_minutes": 120,
                    "valid_from": "2026-09-14",
                }
            ]
        },
    )
    await create_area(client, "First in priority", 1, weekday=2)

    async with engine.begin() as connection:
        await connection.execute(
            text(
                "INSERT INTO timer_executions "
                "(focus_area_id, work_date, started_at, ended_at, "
                "focused_seconds, rest_seconds) "
                "VALUES (:area_id, '2026-09-07', :started_at, :ended_at, 3600, 0)"
            ),
            {
                "area_id": area["id"],
                # 00:30 on 7 September for a UTC+02:00 user.
                "started_at": datetime(2026, 9, 6, 22, 30, tzinfo=timezone.utc),
                "ended_at": datetime(2026, 9, 6, 23, 30, tzinfo=timezone.utc),
            },
        )

    response = await client.get(
        "/api/v1/overview/today",
        params={
            "date": "2026-09-07",
            "day_start_utc": "2026-09-06T22:00:00Z",
            "day_end_utc": "2026-09-07T22:00:00Z",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["expected_focus_seconds"] == 3600
    assert body["actual_focused_seconds"] == 3600
    assert body["completed_focus_areas"] == 1
    assert body["targeted_focus_areas"] == 1
    assert [item["focus_area"]["name"] for item in body["areas"]] == [
        "First in priority",
        "Primary",
    ]
    assert body["areas"][1]["completed"] is True

    current = await client.get(
        "/api/v1/overview/today",
        params={
            "date": "2026-09-14",
            "day_start_utc": "2026-09-13T22:00:00Z",
            "day_end_utc": "2026-09-14T22:00:00Z",
        },
    )
    assert current.json()["expected_focus_seconds"] == 7200
    assert current.json()["areas"][1]["target_seconds"] == 7200


@pytest.mark.asyncio
async def test_today_overview_has_empty_and_invalid_offset_states(client):
    empty = await client.get(
        "/api/v1/overview/today",
        params={
            "date": "2026-09-07",
            "day_start_utc": "2026-09-07T00:00:00Z",
            "day_end_utc": "2026-09-08T00:00:00Z",
        },
    )
    assert empty.status_code == 200
    assert empty.json()["areas"] == []

    invalid = await client.get(
        "/api/v1/overview/today",
        params={
            "date": "2026-09-07",
            "day_start_utc": "2026-09-07T00:00:00Z",
            "day_end_utc": "2026-09-09T00:00:00Z",
        },
    )
    assert invalid.status_code == 422
