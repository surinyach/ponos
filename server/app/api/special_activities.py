from typing import Annotated, NoReturn

from fastapi import APIRouter, HTTPException, Path, status

from app.schemas.special_activity import (
    SpecialActivityCreate,
    SpecialActivityResponse,
    SpecialActivityUpdate,
)

router = APIRouter(
    prefix="/api/v1/special-activities",
    tags=["special-activities"],
)
SpecialActivityId = Annotated[int, Path(gt=0)]


def not_implemented() -> NoReturn:
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Special Activities persistence is not implemented yet",
    )


@router.get("", response_model=list[SpecialActivityResponse])
async def list_active_special_activities() -> NoReturn:
    """List active activities only; archived activities are excluded."""
    not_implemented()


@router.post(
    "",
    response_model=SpecialActivityResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_special_activity(
    payload: SpecialActivityCreate,
) -> NoReturn:
    not_implemented()


@router.get("/archived", response_model=list[SpecialActivityResponse])
async def list_archived_special_activities() -> NoReturn:
    not_implemented()


@router.get("/{special_activity_id}", response_model=SpecialActivityResponse)
async def get_special_activity(
    special_activity_id: SpecialActivityId,
) -> NoReturn:
    not_implemented()


@router.patch("/{special_activity_id}", response_model=SpecialActivityResponse)
async def update_special_activity(
    special_activity_id: SpecialActivityId,
    payload: SpecialActivityUpdate,
) -> NoReturn:
    not_implemented()


@router.post(
    "/{special_activity_id}/archive",
    response_model=SpecialActivityResponse,
)
async def archive_special_activity(
    special_activity_id: SpecialActivityId,
) -> NoReturn:
    not_implemented()


@router.post(
    "/{special_activity_id}/restore",
    response_model=SpecialActivityResponse,
)
async def restore_special_activity(
    special_activity_id: SpecialActivityId,
) -> NoReturn:
    not_implemented()
