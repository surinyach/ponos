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


def _duplicate_name() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail="A Special Activity with this name already exists",
    )


@router.get("", response_model=list[SpecialActivityResponse])
async def list_active_special_activities(
    session: DatabaseSession,
) -> list:
    return await service.list_special_activities(session)


@router.post(
    "",
    response_model=SpecialActivityResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_special_activity(
    payload: SpecialActivityCreate,
    session: DatabaseSession,
):
    try:
        return await service.create_special_activity(session, payload)
    except service.DuplicateSpecialActivityNameError:
        raise _duplicate_name() from None


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
    except service.DuplicateSpecialActivityNameError:
        raise _duplicate_name() from None


@router.delete(
    "/{special_activity_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_special_activity(
    special_activity_id: SpecialActivityId,
    session: DatabaseSession,
) -> None:
    try:
        await service.delete_special_activity(session, special_activity_id)
    except service.SpecialActivityNotFoundError:
        raise _not_found(special_activity_id) from None
    except service.SpecialActivityHasWorkError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Special Activity has recorded work and cannot be deleted",
        ) from None
