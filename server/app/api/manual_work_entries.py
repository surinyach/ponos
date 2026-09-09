from typing import Annotated, NoReturn

from fastapi import APIRouter, HTTPException, Path, Response, status

from app.schemas.manual_work_entry import (
    ManualWorkEntryCreate,
    ManualWorkEntryResponse,
    ManualWorkEntryUpdate,
)

router = APIRouter(
    prefix="/api/v1/manual-work-entries",
    tags=["manual-work-entries"],
)
ManualWorkEntryId = Annotated[int, Path(gt=0)]


def not_implemented() -> NoReturn:
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Manual Work Entries persistence is not implemented yet",
    )


@router.get("", response_model=list[ManualWorkEntryResponse])
async def list_manual_work_entries() -> NoReturn:
    not_implemented()


@router.post(
    "",
    response_model=ManualWorkEntryResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_manual_work_entry(
    payload: ManualWorkEntryCreate,
) -> NoReturn:
    not_implemented()


@router.patch(
    "/{manual_work_entry_id}",
    response_model=ManualWorkEntryResponse,
)
async def update_manual_work_entry(
    manual_work_entry_id: ManualWorkEntryId,
    payload: ManualWorkEntryUpdate,
) -> NoReturn:
    not_implemented()


@router.delete(
    "/{manual_work_entry_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_manual_work_entry(
    manual_work_entry_id: ManualWorkEntryId,
) -> Response:
    not_implemented()
