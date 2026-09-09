from typing import Annotated, NoReturn

from fastapi import APIRouter, Depends, HTTPException, Path, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.manual_work_entry import (
    ManualWorkEntryCreate,
    ManualWorkEntryResponse,
    ManualWorkEntryUpdate,
)
from app.services import manual_work_entries as service

router = APIRouter(
    prefix="/api/v1/manual-work-entries",
    tags=["manual-work-entries"],
)
ManualWorkEntryId = Annotated[int, Path(gt=0)]


DatabaseSession = Annotated[AsyncSession, Depends(get_db)]


def _raise_service_error(error: Exception) -> NoReturn:
    record_id = error.args[0]
    if isinstance(error, service.ManualWorkEntryNotFoundError):
        detail = f"Manual Work Entry {record_id} was not found"
        code = status.HTTP_404_NOT_FOUND
    elif isinstance(error, service.FocusAreaNotFoundError):
        detail = f"Focus Area {record_id} was not found"
        code = status.HTTP_404_NOT_FOUND
    elif isinstance(error, service.SpecialActivityNotFoundError):
        detail = f"Special Activity {record_id} was not found"
        code = status.HTTP_404_NOT_FOUND
    elif isinstance(error, service.ArchivedSpecialActivityError):
        detail = f"Special Activity {record_id} is archived"
        code = status.HTTP_409_CONFLICT
    else:
        detail = str(record_id)
        code = status.HTTP_422_UNPROCESSABLE_CONTENT
    raise HTTPException(status_code=code, detail=detail)


@router.get("", response_model=list[ManualWorkEntryResponse])
async def list_manual_work_entries(session: DatabaseSession) -> list:
    return await service.list_manual_work_entries(session)


@router.post(
    "",
    response_model=ManualWorkEntryResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_manual_work_entry(
    payload: ManualWorkEntryCreate,
    session: DatabaseSession,
):
    try:
        return await service.create_manual_work_entry(session, payload)
    except (
        service.FocusAreaNotFoundError,
        service.SpecialActivityNotFoundError,
        service.ArchivedSpecialActivityError,
        service.InvalidManualWorkEntryError,
    ) as error:
        _raise_service_error(error)


@router.patch(
    "/{manual_work_entry_id}",
    response_model=ManualWorkEntryResponse,
)
async def update_manual_work_entry(
    manual_work_entry_id: ManualWorkEntryId,
    payload: ManualWorkEntryUpdate,
    session: DatabaseSession,
):
    try:
        return await service.update_manual_work_entry(
            session, manual_work_entry_id, payload
        )
    except (
        service.ManualWorkEntryNotFoundError,
        service.FocusAreaNotFoundError,
        service.SpecialActivityNotFoundError,
        service.ArchivedSpecialActivityError,
        service.InvalidManualWorkEntryError,
    ) as error:
        _raise_service_error(error)


@router.delete(
    "/{manual_work_entry_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_manual_work_entry(
    manual_work_entry_id: ManualWorkEntryId,
    session: DatabaseSession,
) -> Response:
    try:
        await service.delete_manual_work_entry(session, manual_work_entry_id)
    except service.ManualWorkEntryNotFoundError as error:
        _raise_service_error(error)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
