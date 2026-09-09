from datetime import date, datetime

import httpx
import pytest
import pytest_asyncio
from sqlalchemy import func, select, text

from app.db.session import async_session_factory, engine
from app.main import app
from app.models.timer_execution import TimerExecution
from app.repositories import timer_executions as repository
from app.schemas.timer_execution import TimerExecutionCreate
from app.services import timer_executions as service


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


async def create_area(client: httpx.AsyncClient) -> int:
    response = await client.post(
        "/api/v1/focus-areas",
        json={
            "name": "Work placement",
            "priority": 1,
            "targets": [
                {
                    "weekday": 2,
                    "target_minutes": 60,
                    "valid_from": "2026-09-08",
                }
            ],
        },
    )
    assert response.status_code == 201
    return response.json()["id"]


def execution_payload(focus_area_id: int) -> dict[str, object]:
    return {
        "focus_area_id": focus_area_id,
        "work_date": "2026-09-08",
        "started_at": "2026-09-08T00:30:00+02:00",
        "ended_at": "2026-09-08T01:05:00+02:00",
        "focused_seconds": 1500,
        "rest_seconds": 300,
    }


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("focused_seconds", "rest_seconds"),
    [(1500, 300), (420, 0)],
    ids=["completed", "partial"],
)
async def test_persists_completed_and_partial_executions(
    client,
    focused_seconds,
    rest_seconds,
):
    focus_area_id = await create_area(client)
    payload = execution_payload(focus_area_id)
    payload["focused_seconds"] = focused_seconds
    payload["rest_seconds"] = rest_seconds

    response = await client.post("/api/v1/timer-executions", json=payload)

    assert response.status_code == 201
    body = response.json()
    assert body["id"] > 0
    assert body["focus_area_id"] == focus_area_id
    assert body["work_date"] == "2026-09-08"
    assert body["focused_seconds"] == focused_seconds
    assert body["rest_seconds"] == rest_seconds

    async with engine.connect() as connection:
        stored = (
            await connection.execute(
                text(
                    "SELECT work_date, focused_seconds, rest_seconds "
                    "FROM timer_executions WHERE id = :id"
                ),
                {"id": body["id"]},
            )
        ).one()
    assert tuple(stored) == (
        date(2026, 9, 8),
        focused_seconds,
        rest_seconds,
    )


@pytest.mark.asyncio
async def test_missing_focus_area_returns_404_without_storing(client):
    response = await client.post(
        "/api/v1/timer-executions",
        json=execution_payload(999),
    )

    assert response.status_code == 404
    assert response.json()["detail"] == "Focus Area 999 was not found"
    assert await execution_count() == 0


@pytest.mark.asyncio
async def test_archived_focus_area_accepts_an_execution_started_before_archive(client):
    focus_area_id = await create_area(client)
    archived = await client.post(f"/api/v1/focus-areas/{focus_area_id}/archive")
    assert archived.status_code == 200

    response = await client.post(
        "/api/v1/timer-executions",
        json=execution_payload(focus_area_id),
    )

    assert response.status_code == 201
    assert response.json()["focus_area_id"] == focus_area_id
    assert await execution_count() == 1


@pytest.mark.asyncio
async def test_midnight_crossing_belongs_to_the_local_start_date(client):
    focus_area_id = await create_area(client)
    payload = execution_payload(focus_area_id)
    payload.update(
        {
            "work_date": "2026-09-08",
            "started_at": "2026-09-08T23:58:00+02:00",
            "ended_at": "2026-09-09T00:08:00+02:00",
            "focused_seconds": 480,
            "rest_seconds": 120,
        }
    )

    response = await client.post("/api/v1/timer-executions", json=payload)

    assert response.status_code == 201
    assert response.json()["work_date"] == "2026-09-08"


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("focused_seconds", -1),
        ("rest_seconds", -1),
        ("started_at", "2026-09-08T00:30:00"),
        ("ended_at", "2026-09-08T00:20:00+02:00"),
        ("work_date", "2026-09-07"),
        ("focused_seconds", 2200),
    ],
    ids=[
        "negative-focus",
        "negative-rest",
        "naive-start",
        "end-before-start",
        "wrong-work-date",
        "durations-exceed-elapsed",
    ],
)
async def test_rejects_invalid_executions(client, field, value):
    focus_area_id = await create_area(client)
    payload = execution_payload(focus_area_id)
    payload[field] = value

    response = await client.post("/api/v1/timer-executions", json=payload)

    assert response.status_code == 422
    assert await execution_count() == 0


@pytest.mark.asyncio
async def test_discard_marker_is_rejected_and_nothing_is_stored(client):
    focus_area_id = await create_area(client)
    payload = execution_payload(focus_area_id)
    payload["discarded"] = True

    response = await client.post("/api/v1/timer-executions", json=payload)

    assert response.status_code == 422
    assert await execution_count() == 0


@pytest.mark.asyncio
async def test_service_rolls_back_when_repository_write_fails(client, monkeypatch):
    focus_area_id = await create_area(client)

    async def failing_add(session, execution):
        session.add(execution)
        await session.flush()
        raise RuntimeError("simulated write failure")

    monkeypatch.setattr(repository, "add", failing_add)
    payload = TimerExecutionCreate.model_validate(
        execution_payload(focus_area_id)
    )

    async with async_session_factory() as session:
        with pytest.raises(RuntimeError, match="simulated write failure"):
            await service.create_timer_execution(session, payload)

    assert await execution_count() == 0


def test_contract_exposes_only_the_create_operation():
    operations = app.openapi()["paths"]["/api/v1/timer-executions"]
    assert set(operations) == {"post"}
    assert operations["post"]["responses"]["201"]["content"][
        "application/json"
    ]["schema"] == {"$ref": "#/components/schemas/TimerExecutionResponse"}


async def execution_count() -> int:
    async with async_session_factory() as session:
        return await session.scalar(select(func.count(TimerExecution.id))) or 0
