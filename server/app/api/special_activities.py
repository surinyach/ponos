from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.special_activity import (
    SpecialActivityCreate,
    SpecialActivityResponse,
    SpecialActivityUpdate,
)
from app.services import special_activities as service

router = APIRouter(
    prefix="/api/v1/special-activities",
    tags=["special-activities"],
)
SpecialActivityId = Annotated[int, Path(gt=0)]


DatabaseSession = Annotated[AsyncSession, Depends(get_db)]


def _not_found(special_activity_id: int) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"Special Activity {special_activity_id} was not found",
    )


@router.get("", response_model=list[SpecialActivityResponse])
async def list_active_special_activities(
    session: DatabaseSession,
) -> list:
    """List active activities only; archived activities are excluded."""
    return await service.list_special_activities(session, archived=False)


@router.post(
    "",
    response_model=SpecialActivityResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_special_activity(
    payload: SpecialActivityCreate,
    session: DatabaseSession,
):
    return await service.create_special_activity(session, payload)


@router.get("/archived", response_model=list[SpecialActivityResponse])
async def list_archived_special_activities(
    session: DatabaseSession,
) -> list:
    return await service.list_special_activities(session, archived=True)


@router.get("/{special_activity_id}", response_model=SpecialActivityResponse)
async def get_special_activity(
    special_activity_id: SpecialActivityId,
    session: DatabaseSession,
):
    try:
        return await service.get_special_activity(session, special_activity_id)
    except service.SpecialActivityNotFoundError:
        raise _not_found(special_activity_id) from None


@router.patch("/{special_activity_id}", response_model=SpecialActivityResponse)
async def update_special_activity(
    special_activity_id: SpecialActivityId,
    payload: SpecialActivityUpdate,
    session: DatabaseSession,
):
    try:
        return await service.update_special_activity(
            session, special_activity_id, payload
        )
    except service.SpecialActivityNotFoundError:
        raise _not_found(special_activity_id) from None


@router.post(
    "/{special_activity_id}/archive",
    response_model=SpecialActivityResponse,
)
async def archive_special_activity(
    special_activity_id: SpecialActivityId,
    session: DatabaseSession,
):
    try:
        return await service.set_archived(
            session, special_activity_id, archived=True
        )
    except service.SpecialActivityNotFoundError:
        raise _not_found(special_activity_id) from None


@router.post(
    "/{special_activity_id}/restore",
    response_model=SpecialActivityResponse,
)
async def restore_special_activity(
    special_activity_id: SpecialActivityId,
    session: DatabaseSession,
):
    try:
        return await service.set_archived(
            session, special_activity_id, archived=False
        )
    except service.SpecialActivityNotFoundError:
        raise _not_found(special_activity_id) from None
