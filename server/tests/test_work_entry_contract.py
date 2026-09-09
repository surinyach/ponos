from datetime import date

import httpx
import pytest
from pydantic import ValidationError

from app.main import app
from app.schemas.manual_work_entry import (
    ManualWorkEntryCreate,
    ManualWorkEntryUpdate,
)
from app.schemas.special_activity import (
    SpecialActivityCreate,
    SpecialActivityResponse,
    SpecialActivityUpdate,
)


def test_openapi_exposes_special_activity_operations() -> None:
    paths = app.openapi()["paths"]

    assert set(paths["/api/v1/special-activities"]) == {"get", "post"}
    assert set(paths["/api/v1/special-activities/archived"]) == {"get"}
    assert set(
        paths["/api/v1/special-activities/{special_activity_id}"]
    ) == {"get", "patch"}
    assert set(
        paths["/api/v1/special-activities/{special_activity_id}/archive"]
    ) == {"post"}
    assert set(
        paths["/api/v1/special-activities/{special_activity_id}/restore"]
    ) == {"post"}


def test_openapi_exposes_manual_work_entry_operations() -> None:
    paths = app.openapi()["paths"]

    assert set(paths["/api/v1/manual-work-entries"]) == {"get", "post"}
    assert set(
        paths["/api/v1/manual-work-entries/{manual_work_entry_id}"]
    ) == {"patch", "delete"}
    delete = paths[
        "/api/v1/manual-work-entries/{manual_work_entry_id}"
    ]["delete"]
    assert "204" in delete["responses"]


def test_special_activity_contract_has_no_recurring_work_fields() -> None:
    request = SpecialActivityCreate.model_validate(
        {
            "name": "Release day",
            "description": None,
            "work_date": "2026-09-09",
        }
    )

    assert request.work_date == date(2026, 9, 9)
    assert set(SpecialActivityResponse.model_fields) == {
        "id",
        "name",
        "description",
        "work_date",
        "is_archived",
    }
    assert not {
        "priority",
        "targets",
        "target_end_date",
    }.intersection(SpecialActivityResponse.model_fields)


def test_special_activity_patch_is_partial_but_not_empty() -> None:
    assert SpecialActivityUpdate.model_validate(
        {"description": "Deployment"}
    ).description == "Deployment"

    with pytest.raises(ValidationError):
        SpecialActivityUpdate.model_validate({})


@pytest.mark.parametrize(
    ("focus_area_id", "special_activity_id"),
    [(None, None), (1, 2)],
    ids=["neither", "both"],
)
def test_manual_entry_create_requires_exactly_one_owner(
    focus_area_id,
    special_activity_id,
) -> None:
    with pytest.raises(ValidationError):
        ManualWorkEntryCreate.model_validate(
            {
                "focus_area_id": focus_area_id,
                "special_activity_id": special_activity_id,
                "work_date": "2026-09-09",
                "focused_seconds": 60,
                "rest_seconds": 0,
            }
        )


def test_manual_entry_create_accepts_either_owner() -> None:
    focus_entry = ManualWorkEntryCreate.model_validate(
        {
            "focus_area_id": 1,
            "work_date": "2026-09-09",
            "focused_seconds": 60,
            "rest_seconds": 0,
        }
    )
    activity_entry = ManualWorkEntryCreate.model_validate(
        {
            "special_activity_id": 2,
            "work_date": "2026-09-09",
            "focused_seconds": 0,
            "rest_seconds": 30,
        }
    )

    assert focus_entry.focus_area_id == 1
    assert activity_entry.special_activity_id == 2


def test_manual_entry_rejects_two_zero_durations() -> None:
    with pytest.raises(ValidationError):
        ManualWorkEntryCreate.model_validate(
            {
                "focus_area_id": 1,
                "work_date": "2026-09-09",
                "focused_seconds": 0,
                "rest_seconds": 0,
            }
        )
    with pytest.raises(ValidationError):
        ManualWorkEntryUpdate.model_validate(
            {"focused_seconds": 0, "rest_seconds": 0}
        )


def test_manual_entry_patch_is_partial_and_reassignment_is_explicit() -> None:
    update = ManualWorkEntryUpdate.model_validate({"focused_seconds": 120})
    assert update.focused_seconds == 120

    with pytest.raises(ValidationError):
        ManualWorkEntryUpdate.model_validate({"special_activity_id": 2})

    reassignment = ManualWorkEntryUpdate.model_validate(
        {"focus_area_id": None, "special_activity_id": 2}
    )
    assert reassignment.special_activity_id == 2


@pytest.mark.asyncio
async def test_routes_reject_invalid_payload_before_database_access() -> None:
    async with httpx.AsyncClient(
        transport=httpx.ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        invalid = await client.post(
            "/api/v1/manual-work-entries",
            json={
                "work_date": "2026-09-09",
                "focused_seconds": 0,
                "rest_seconds": 0,
            },
        )

    assert invalid.status_code == 422
