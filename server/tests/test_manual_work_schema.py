import pytest
import pytest_asyncio
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from app.db.session import engine


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
async def subjects() -> tuple[int, int]:
    async with engine.begin() as connection:
        focus_area_id = await connection.scalar(
            text(
                "INSERT INTO focus_areas (name, priority) "
                "VALUES ('Placement', 1) RETURNING id"
            )
        )
        special_activity_id = await connection.scalar(
            text(
                "INSERT INTO special_activities (name, work_date) "
                "VALUES ('Release day', '2026-09-09') RETURNING id"
            )
        )
    return int(focus_area_id), int(special_activity_id)


@pytest.mark.asyncio
async def test_accepts_each_valid_manual_entry_owner(subjects):
    focus_area_id, special_activity_id = subjects
    async with engine.begin() as connection:
        await connection.execute(
            text(
                "INSERT INTO manual_work_entries "
                "(focus_area_id, work_date, focused_seconds, rest_seconds) "
                "VALUES (:focus_area_id, '2026-09-09', 900, 0)"
            ),
            {"focus_area_id": focus_area_id},
        )
        await connection.execute(
            text(
                "INSERT INTO manual_work_entries "
                "(special_activity_id, work_date, focused_seconds, rest_seconds) "
                "VALUES (:special_activity_id, '2026-09-09', 0, 300)"
            ),
            {"special_activity_id": special_activity_id},
        )


@pytest.mark.asyncio
@pytest.mark.parametrize("owner", ["neither", "both"])
async def test_rejects_invalid_manual_entry_ownership(subjects, owner):
    focus_area_id, special_activity_id = subjects
    values = {
        "focus_area_id": focus_area_id if owner == "both" else None,
        "special_activity_id": special_activity_id if owner == "both" else None,
    }

    with pytest.raises(IntegrityError):
        async with engine.begin() as connection:
            await connection.execute(
                text(
                    "INSERT INTO manual_work_entries "
                    "(focus_area_id, special_activity_id, work_date, "
                    "focused_seconds, rest_seconds) VALUES "
                    "(:focus_area_id, :special_activity_id, '2026-09-09', 60, 0)"
                ),
                values,
            )


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("focused_seconds", "rest_seconds"),
    [(0, 0), (-1, 0), (0, -1)],
)
async def test_rejects_invalid_manual_entry_durations(
    subjects,
    focused_seconds,
    rest_seconds,
):
    focus_area_id, _ = subjects

    with pytest.raises(IntegrityError):
        async with engine.begin() as connection:
            await connection.execute(
                text(
                    "INSERT INTO manual_work_entries "
                    "(focus_area_id, work_date, focused_seconds, rest_seconds) "
                    "VALUES (:focus_area_id, '2026-09-09', "
                    ":focused_seconds, :rest_seconds)"
                ),
                {
                    "focus_area_id": focus_area_id,
                    "focused_seconds": focused_seconds,
                    "rest_seconds": rest_seconds,
                },
            )
