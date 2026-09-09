from datetime import date, datetime, timezone

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


def create_payload(name: str = "Work placement", priority: int = 1):
    return {
        "name": name,
        "description": "Daily focused work",
        "priority": priority,
        "target_end_date": None,
        "targets": [
            {
                "weekday": 1,
                "target_minutes": 480,
                "valid_from": "2026-09-07",
            }
        ],
    }


async def create_area(client: httpx.AsyncClient, **overrides):
    payload = create_payload()
    payload.update(overrides)
    response = await client.post("/api/v1/focus-areas", json=payload)
    assert response.status_code == 201
    return response.json()


@pytest.mark.asyncio
async def test_create_list_get_and_partial_update(client):
    second = await create_area(client, name="Personal project", priority=2)
    first = await create_area(client, name="LeetCode", priority=1)

    listed = await client.get("/api/v1/focus-areas")
    assert listed.status_code == 200
    assert [item["id"] for item in listed.json()] == [first["id"], second["id"]]

    updated = await client.patch(
        f"/api/v1/focus-areas/{first['id']}",
        json={"description": None, "target_end_date": "2026-12-31"},
    )
    assert updated.status_code == 200
    assert updated.json()["description"] is None
    assert updated.json()["target_end_date"] == "2026-12-31"

    fetched = await client.get(f"/api/v1/focus-areas/{first['id']}")
    assert fetched.json() == updated.json()


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "target",
    [
        {"weekday": 0, "target_minutes": 60, "valid_from": "2026-09-07"},
        {"weekday": 8, "target_minutes": 60, "valid_from": "2026-09-07"},
        {"weekday": 1, "target_minutes": -1, "valid_from": "2026-09-07"},
    ],
)
async def test_invalid_weekdays_and_targets_return_422(client, target):
    payload = create_payload()
    payload["targets"] = [target]
    response = await client.post("/api/v1/focus-areas", json=payload)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_missing_records_return_404(client):
    assert (await client.get("/api/v1/focus-areas/999")).status_code == 404
    assert (
        await client.patch("/api/v1/focus-areas/999", json={"name": "Missing"})
    ).status_code == 404
    assert (
        await client.post("/api/v1/focus-areas/999/archive")
    ).status_code == 404
    assert (
        await client.post("/api/v1/focus-areas/999/restore")
    ).status_code == 404


@pytest.mark.asyncio
async def test_archive_and_restore_move_area_between_lists(client):
    area = await create_area(client)

    archived = await client.post(f"/api/v1/focus-areas/{area['id']}/archive")
    assert archived.status_code == 200
    assert archived.json()["archived_at"] is not None
    assert (await client.get("/api/v1/focus-areas")).json() == []
    assert [item["id"] for item in (await client.get("/api/v1/focus-areas/archived")).json()] == [area["id"]]

    restored = await client.post(f"/api/v1/focus-areas/{area['id']}/restore")
    assert restored.status_code == 200
    assert restored.json()["archived_at"] is None
    assert (await client.get("/api/v1/focus-areas/archived")).json() == []


@pytest.mark.asyncio
async def test_archive_and_restore_preserve_targets_and_timer_history(client):
    area = await create_area(client)
    versioned = await client.patch(
        f"/api/v1/focus-areas/{area['id']}",
        json={
            "targets": [
                {
                    "weekday": 1,
                    "target_minutes": 360,
                    "valid_from": "2026-09-14",
                }
            ]
        },
    )
    assert versioned.status_code == 200

    async with engine.begin() as connection:
        await connection.execute(
            text(
                "INSERT INTO timer_executions "
                "(focus_area_id, work_date, started_at, ended_at, "
                "focused_seconds, rest_seconds) "
                "VALUES (:area_id, '2026-09-07', :started_at, :ended_at, 1800, 300)"
            ),
            {
                "area_id": area["id"],
                "started_at": datetime(2026, 9, 7, 8, tzinfo=timezone.utc),
                "ended_at": datetime(2026, 9, 7, 8, 35, tzinfo=timezone.utc),
            },
        )

    archived = await client.post(f"/api/v1/focus-areas/{area['id']}/archive")
    assert archived.status_code == 200
    assert len(archived.json()["targets"]) == 2

    async with engine.connect() as connection:
        target_count = await connection.scalar(
            text(
                "SELECT count(*) FROM focus_area_targets "
                "WHERE focus_area_id = :area_id"
            ),
            {"area_id": area["id"]},
        )
        execution = (
            await connection.execute(
                text(
                    "SELECT focused_seconds, rest_seconds FROM timer_executions "
                    "WHERE focus_area_id = :area_id"
                ),
                {"area_id": area["id"]},
            )
        ).one()

    assert target_count == 2
    assert tuple(execution) == (1800, 300)

    restored = await client.post(f"/api/v1/focus-areas/{area['id']}/restore")
    fetched = await client.get(f"/api/v1/focus-areas/{area['id']}")
    assert restored.status_code == 200
    assert fetched.status_code == 200
    assert fetched.json()["targets"] == restored.json()["targets"]


@pytest.mark.asyncio
async def test_target_update_preserves_historical_version(client):
    area = await create_area(client)

    response = await client.patch(
        f"/api/v1/focus-areas/{area['id']}",
        json={
            "targets": [
                {
                    "weekday": 1,
                    "target_minutes": 360,
                    "valid_from": "2026-09-14",
                }
            ]
        },
    )

    assert response.status_code == 200
    versions = response.json()["targets"]
    assert [(item["target_minutes"], item["valid_from"], item["valid_until"]) for item in versions] == [
        (480, "2026-09-07", "2026-09-13"),
        (360, "2026-09-14", None),
    ]


@pytest.mark.asyncio
async def test_same_effective_date_returns_conflict_without_losing_history(client):
    area = await create_area(client)
    response = await client.patch(
        f"/api/v1/focus-areas/{area['id']}",
        json={
            "name": "Updated name",
            "targets": [
                {
                    "weekday": 1,
                    "target_minutes": 360,
                    "valid_from": "2026-09-07",
                }
            ]
        },
    )
    assert response.status_code == 409
    fetched = (await client.get(f"/api/v1/focus-areas/{area['id']}")).json()
    assert fetched["name"] == "Work placement"
    assert len(fetched["targets"]) == 1
    assert fetched["targets"][0]["target_minutes"] == 480


@pytest.mark.asyncio
async def test_batch_priorities_allow_duplicates(client):
    first = await create_area(client, name="One", priority=1)
    second = await create_area(client, name="Two", priority=2)

    response = await client.patch(
        "/api/v1/focus-areas/priorities",
        json={
            "items": [
                {"id": first["id"], "priority": 4},
                {"id": second["id"], "priority": 4},
            ]
        },
    )
    assert response.status_code == 200
    assert [item["priority"] for item in response.json()] == [4, 4]


@pytest.mark.asyncio
async def test_batch_priority_update_rolls_back_when_one_record_is_missing(client):
    area = await create_area(client, priority=1)
    response = await client.patch(
        "/api/v1/focus-areas/priorities",
        json={
            "items": [
                {"id": area["id"], "priority": 9},
                {"id": 999, "priority": 9},
            ]
        },
    )
    assert response.status_code == 404
    fetched = (await client.get(f"/api/v1/focus-areas/{area['id']}")).json()
    assert fetched["priority"] == 1
