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
                "TRUNCATE manual_work_entries, special_activities, "
                "timer_executions, focus_area_targets, focus_areas "
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


@pytest.mark.asyncio
async def test_manual_and_timer_time_combine_without_special_completion(client):
    primary = await create_area(client, "Primary", 1)
    secondary = await create_area(client, "Secondary", 2)
    special_response = await client.post(
        "/api/v1/special-activities",
        json={"name": "Release"},
    )
    assert special_response.status_code == 201
    special_id = special_response.json()["id"]

    async with engine.begin() as connection:
        await connection.execute(
            text(
                "INSERT INTO timer_executions "
                "(focus_area_id, work_date, started_at, ended_at, "
                "focused_seconds, rest_seconds) VALUES "
                "(:area, '2026-09-07', '2026-09-07T08:00:00Z', "
                "'2026-09-07T08:30:00Z', 1200, 300)"
            ),
            {"area": primary["id"]},
        )
        await connection.execute(
            text(
                "INSERT INTO manual_work_entries "
                "(focus_area_id, work_date, focused_seconds, rest_seconds) "
                "VALUES (:area, '2026-09-07', 2400, 600)"
            ),
            {"area": primary["id"]},
        )
        await connection.execute(
            text(
                "INSERT INTO manual_work_entries "
                "(special_activity_id, work_date, focused_seconds, rest_seconds) "
                "VALUES (:activity, '2026-09-07', 7200, 900), "
                "(:activity, '2026-09-08', 300, 60)"
            ),
            {"activity": special_id},
        )

    today = await client.get(
        "/api/v1/overview/today",
        params={
            "date": "2026-09-07",
            "day_start_utc": "2026-09-06T22:00:00Z",
            "day_end_utc": "2026-09-07T22:00:00Z",
        },
    )
    assert today.status_code == 200
    body = today.json()
    assert body["expected_focus_seconds"] == 7200
    assert body["actual_focused_seconds"] == 10800
    assert body["actual_rest_seconds"] == 1800
    assert body["actual_tracked_seconds"] == 12600
    assert body["completed_focus_areas"] == 1
    assert body["targeted_focus_areas"] == 2
    assert [item["focused_seconds"] for item in body["areas"]] == [3600, 0]
    assert [item["completed"] for item in body["areas"]] == [True, False]
    assert body["special_activities"][0]["special_activity"]["name"] == "Release"
    assert body["special_activities"][0]["focused_seconds"] == 7200
    assert body["special_activities"][0]["rest_seconds"] == 900
    assert body["week"]["focused_seconds"] == 11100
    assert body["week"]["rest_seconds"] == 1860
    assert body["overall"]["days_worked"] == 2
    assert body["overall"]["tracked_seconds"] == 12960

    week = await client.get(
        "/api/v1/overview/week", params={"date": "2026-09-09"}
    )
    assert week.status_code == 200
    assert week.json() == {
        "week_start": "2026-09-07",
        "week_end": "2026-09-13",
        "focused_seconds": 11100,
        "rest_seconds": 1860,
        "tracked_seconds": 12960,
    }
    overall = await client.get("/api/v1/overview/overall")
    assert overall.status_code == 200
    assert overall.json() == {
        "days_worked": 2,
        "focused_seconds": 11100,
        "rest_seconds": 1860,
        "tracked_seconds": 12960,
    }


@pytest.mark.asyncio
async def test_week_boundaries_and_empty_lifetime_totals(client):
    empty = await client.get("/api/v1/overview/overall")
    assert empty.json() == {
        "days_worked": 0,
        "focused_seconds": 0,
        "rest_seconds": 0,
        "tracked_seconds": 0,
    }
    special = await client.post(
        "/api/v1/special-activities",
        json={"name": "One-off"},
    )
    await client.post(
        "/api/v1/manual-work-entries",
        json={
            "special_activity_id": special.json()["id"],
            "work_date": "2026-09-06",
            "focused_seconds": 120,
            "rest_seconds": 30,
        },
    )
    current_week = await client.get(
        "/api/v1/overview/week", params={"date": "2026-09-07"}
    )
    prior_week = await client.get(
        "/api/v1/overview/week", params={"date": "2026-09-06"}
    )
    assert current_week.json()["focused_seconds"] == 0
    assert prior_week.json()["focused_seconds"] == 120
    assert prior_week.json()["week_start"] == "2026-08-31"

    special_only_day = await client.get(
        "/api/v1/overview/today",
        params={
            "date": "2026-09-06",
            "day_start_utc": "2026-09-05T22:00:00Z",
            "day_end_utc": "2026-09-06T22:00:00Z",
        },
    )
    assert special_only_day.json()["areas"] == []
    assert special_only_day.json()["actual_focused_seconds"] == 120
    assert special_only_day.json()["completed_focus_areas"] == 0


@pytest.mark.asyncio
async def test_edit_delete_and_reassign_manual_entries_recalculate_every_total(client):
    area = await create_area(client, "Placement", 1, minutes=30)
    activity = await client.post(
        "/api/v1/special-activities",
        json={"name": "One-off"},
    )
    activity_id = activity.json()["id"]
    timer = await client.post(
        "/api/v1/timer-executions",
        json={
            "focus_area_id": area["id"],
            "work_date": "2026-09-07",
            "started_at": "2026-09-07T08:00:00+02:00",
            "ended_at": "2026-09-07T08:20:00+02:00",
            "focused_seconds": 900,
            "rest_seconds": 300,
        },
    )
    assert timer.status_code == 201
    area_entry = await client.post(
        "/api/v1/manual-work-entries",
        json={
            "focus_area_id": area["id"],
            "work_date": "2026-09-07",
            "focused_seconds": 900,
            "rest_seconds": 0,
        },
    )
    special_entry = await client.post(
        "/api/v1/manual-work-entries",
        json={
            "special_activity_id": activity_id,
            "work_date": "2026-09-07",
            "focused_seconds": 600,
            "rest_seconds": 120,
        },
    )
    assert area_entry.status_code == special_entry.status_code == 201

    async def snapshot():
        daily = await client.get(
            "/api/v1/overview/today",
            params={
                "date": "2026-09-07",
                "day_start_utc": "2026-09-06T22:00:00Z",
                "day_end_utc": "2026-09-07T22:00:00Z",
            },
        )
        week = await client.get(
            "/api/v1/overview/week", params={"date": "2026-09-07"}
        )
        overall = await client.get("/api/v1/overview/overall")
        assert daily.status_code == week.status_code == overall.status_code == 200
        return daily.json(), week.json(), overall.json()

    daily, week, overall = await snapshot()
    assert daily["actual_focused_seconds"] == 2400
    assert daily["actual_rest_seconds"] == 420
    assert daily["areas"][0]["focused_seconds"] == 1800
    assert daily["completed_focus_areas"] == 1
    assert week["tracked_seconds"] == overall["tracked_seconds"] == 2820

    updated = await client.patch(
        f"/api/v1/manual-work-entries/{area_entry.json()['id']}",
        json={"focused_seconds": 300, "rest_seconds": 60},
    )
    assert updated.status_code == 200
    daily, week, overall = await snapshot()
    assert daily["areas"][0]["focused_seconds"] == 1200
    assert daily["completed_focus_areas"] == 0
    assert daily["actual_focused_seconds"] == 1800
    assert daily["actual_rest_seconds"] == 480
    assert week["tracked_seconds"] == overall["tracked_seconds"] == 2280

    reassigned = await client.patch(
        f"/api/v1/manual-work-entries/{area_entry.json()['id']}",
        json={"focus_area_id": None, "special_activity_id": activity_id},
    )
    assert reassigned.status_code == 200
    daily, _, _ = await snapshot()
    assert daily["areas"][0]["focused_seconds"] == 900
    assert daily["actual_focused_seconds"] == 1800

    deleted = await client.delete(
        f"/api/v1/manual-work-entries/{special_entry.json()['id']}"
    )
    assert deleted.status_code == 204
    daily, week, overall = await snapshot()
    assert daily["actual_focused_seconds"] == 1200
    assert daily["actual_rest_seconds"] == 360
    assert week["tracked_seconds"] == overall["tracked_seconds"] == 1560
    assert overall["days_worked"] == 1
