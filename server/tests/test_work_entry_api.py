import httpx
import pytest
import pytest_asyncio
from sqlalchemy import func, select, text

from app.db.session import async_session_factory, engine
from app.main import app
from app.models.manual_work_entry import ManualWorkEntry
from app.repositories import manual_work_entries as repository
from app.schemas.manual_work_entry import ManualWorkEntryCreate
from app.services import manual_work_entries as service


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


async def create_focus_area(client: httpx.AsyncClient) -> int:
    response = await client.post(
        "/api/v1/focus-areas",
        json={
            "name": "Placement",
            "priority": 1,
            "targets": [
                {
                    "weekday": 3,
                    "target_minutes": 60,
                    "valid_from": "2026-09-09",
                }
            ],
        },
    )
    assert response.status_code == 201
    return response.json()["id"]


async def create_special_activity(client: httpx.AsyncClient) -> dict:
    response = await client.post(
        "/api/v1/special-activities",
        json={
            "name": "Release day",
            "description": "Ship the app",
            "work_date": "2026-09-09",
        },
    )
    assert response.status_code == 201
    return response.json()


def entry_payload(**changes) -> dict:
    payload = {
        "focus_area_id": 1,
        "work_date": "2026-09-09",
        "focused_seconds": 1800,
        "rest_seconds": 300,
    }
    payload.update(changes)
    return payload


@pytest.mark.asyncio
async def test_special_activity_crud_archive_and_restore(client):
    created = await create_special_activity(client)
    activity_id = created["id"]

    active = await client.get("/api/v1/special-activities")
    fetched = await client.get(f"/api/v1/special-activities/{activity_id}")
    updated = await client.patch(
        f"/api/v1/special-activities/{activity_id}",
        json={"name": "Production release"},
    )
    archived = await client.post(
        f"/api/v1/special-activities/{activity_id}/archive"
    )

    assert active.json() == [created]
    assert fetched.json() == created
    assert updated.json()["name"] == "Production release"
    assert archived.json()["is_archived"] is True
    assert (await client.get("/api/v1/special-activities")).json() == []
    assert len(
        (await client.get("/api/v1/special-activities/archived")).json()
    ) == 1

    restored = await client.post(
        f"/api/v1/special-activities/{activity_id}/restore"
    )
    assert restored.json()["is_archived"] is False
    assert len((await client.get("/api/v1/special-activities")).json()) == 1


@pytest.mark.asyncio
@pytest.mark.parametrize("operation", ["get", "patch", "archive", "restore"])
async def test_missing_special_activity_returns_404(client, operation):
    if operation == "get":
        response = await client.get("/api/v1/special-activities/999")
    elif operation == "patch":
        response = await client.patch(
            "/api/v1/special-activities/999", json={"name": "Missing"}
        )
    else:
        response = await client.post(
            f"/api/v1/special-activities/999/{operation}"
        )
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_manual_entry_create_list_update_reassign_and_delete(client):
    focus_area_id = await create_focus_area(client)
    activity = await create_special_activity(client)

    created = await client.post(
        "/api/v1/manual-work-entries",
        json=entry_payload(focus_area_id=focus_area_id),
    )
    assert created.status_code == 201
    entry_id = created.json()["id"]
    assert len((await client.get("/api/v1/manual-work-entries")).json()) == 1

    updated = await client.patch(
        f"/api/v1/manual-work-entries/{entry_id}",
        json={"rest_seconds": 600},
    )
    reassigned = await client.patch(
        f"/api/v1/manual-work-entries/{entry_id}",
        json={
            "focus_area_id": None,
            "special_activity_id": activity["id"],
        },
    )
    deleted = await client.delete(f"/api/v1/manual-work-entries/{entry_id}")

    assert updated.json()["rest_seconds"] == 600
    assert reassigned.json()["focus_area_id"] is None
    assert reassigned.json()["special_activity_id"] == activity["id"]
    assert deleted.status_code == 204
    assert (await client.get("/api/v1/manual-work-entries")).json() == []


@pytest.mark.asyncio
@pytest.mark.parametrize(
    "payload",
    [
        entry_payload(focus_area_id=None),
        entry_payload(special_activity_id=1),
        entry_payload(focused_seconds=-1),
        entry_payload(rest_seconds=-1),
        entry_payload(focused_seconds=0, rest_seconds=0),
    ],
    ids=["no-owner", "two-owners", "negative-focus", "negative-rest", "zero"],
)
async def test_rejects_invalid_manual_entries(client, payload):
    response = await client.post("/api/v1/manual-work-entries", json=payload)
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_rejects_missing_references(client):
    missing_focus = await client.post(
        "/api/v1/manual-work-entries", json=entry_payload(focus_area_id=999)
    )
    missing_activity = await client.post(
        "/api/v1/manual-work-entries",
        json=entry_payload(
            focus_area_id=None,
            special_activity_id=999,
        ),
    )
    assert missing_focus.status_code == 404
    assert missing_activity.status_code == 404


@pytest.mark.asyncio
async def test_archived_activity_rejects_new_entries_but_preserves_existing(client):
    activity = await create_special_activity(client)
    activity_id = activity["id"]
    existing = await client.post(
        "/api/v1/manual-work-entries",
        json=entry_payload(
            focus_area_id=None,
            special_activity_id=activity_id,
        ),
    )
    assert existing.status_code == 201
    await client.post(f"/api/v1/special-activities/{activity_id}/archive")

    rejected = await client.post(
        "/api/v1/manual-work-entries",
        json=entry_payload(
            focus_area_id=None,
            special_activity_id=activity_id,
        ),
    )
    updated = await client.patch(
        f"/api/v1/manual-work-entries/{existing.json()['id']}",
        json={"focused_seconds": 2000},
    )

    assert rejected.status_code == 409
    assert updated.status_code == 200
    assert updated.json()["focused_seconds"] == 2000


@pytest.mark.asyncio
async def test_update_validates_merged_durations(client):
    focus_area_id = await create_focus_area(client)
    created = await client.post(
        "/api/v1/manual-work-entries",
        json=entry_payload(
            focus_area_id=focus_area_id,
            focused_seconds=60,
            rest_seconds=0,
        ),
    )
    response = await client.patch(
        f"/api/v1/manual-work-entries/{created.json()['id']}",
        json={"focused_seconds": 0},
    )
    assert response.status_code == 422


@pytest.mark.asyncio
async def test_missing_manual_entry_returns_404(client):
    updated = await client.patch(
        "/api/v1/manual-work-entries/999", json={"focused_seconds": 60}
    )
    deleted = await client.delete("/api/v1/manual-work-entries/999")
    assert updated.status_code == 404
    assert deleted.status_code == 404


@pytest.mark.asyncio
async def test_service_rolls_back_when_repository_write_fails(client, monkeypatch):
    focus_area_id = await create_focus_area(client)

    async def failing_add(session, entry):
        session.add(entry)
        await session.flush()
        raise RuntimeError("simulated write failure")

    monkeypatch.setattr(repository, "add", failing_add)
    payload = ManualWorkEntryCreate.model_validate(
        entry_payload(focus_area_id=focus_area_id)
    )
    async with async_session_factory() as session:
        with pytest.raises(RuntimeError, match="simulated write failure"):
            await service.create_manual_work_entry(session, payload)

    async with async_session_factory() as session:
        count = await session.scalar(select(func.count(ManualWorkEntry.id)))
    assert count == 0
