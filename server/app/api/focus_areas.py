from typing import Annotated
from fastapi import APIRouter, Depends, HTTPException, Path, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from app.schemas.focus_area import FocusAreaCreate, FocusAreaDeletionPreview, FocusAreaPrioritiesUpdate, FocusAreaResponse, FocusAreaUpdate
from app.services import focus_areas as service

router = APIRouter(prefix="/api/v1/focus-areas", tags=["focus-areas"])
FocusAreaId = Annotated[int, Path(gt=0)]
DatabaseSession = Annotated[AsyncSession, Depends(get_db)]

def not_found(error: service.FocusAreaNotFoundError) -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Focus Area {error.args[0]} was not found")

@router.get("", response_model=list[FocusAreaResponse])
async def list_active_focus_areas(db: DatabaseSession) -> list[FocusAreaResponse]:
    return await service.list_focus_areas(db, archived=False)

@router.post("", response_model=FocusAreaResponse, status_code=status.HTTP_201_CREATED)
async def create_focus_area(payload: FocusAreaCreate, db: DatabaseSession) -> FocusAreaResponse:
    return await service.create_focus_area(db, payload)

@router.get("/archived", response_model=list[FocusAreaResponse])
async def list_archived_focus_areas(db: DatabaseSession) -> list[FocusAreaResponse]:
    return await service.list_focus_areas(db, archived=True)

@router.patch("/priorities", response_model=list[FocusAreaResponse])
async def update_focus_area_priorities(payload: FocusAreaPrioritiesUpdate, db: DatabaseSession) -> list[FocusAreaResponse]:
    try:
        return await service.update_priorities(db, payload)
    except service.FocusAreaNotFoundError as error:
        raise not_found(error) from error

@router.get("/{focus_area_id}", response_model=FocusAreaResponse)
async def get_focus_area(focus_area_id: FocusAreaId, db: DatabaseSession) -> FocusAreaResponse:
    try:
        return await service.get_focus_area(db, focus_area_id)
    except service.FocusAreaNotFoundError as error:
        raise not_found(error) from error

@router.patch("/{focus_area_id}", response_model=FocusAreaResponse)
async def update_focus_area(focus_area_id: FocusAreaId, payload: FocusAreaUpdate, db: DatabaseSession) -> FocusAreaResponse:
    try:
        return await service.update_focus_area(db, focus_area_id, payload)
    except service.FocusAreaNotFoundError as error:
        raise not_found(error) from error
    except service.TargetVersionConflictError as error:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(error)) from error

@router.post("/{focus_area_id}/archive", response_model=FocusAreaResponse)
async def archive_focus_area(focus_area_id: FocusAreaId, db: DatabaseSession) -> FocusAreaResponse:
    try:
        return await service.set_archived(db, focus_area_id, archived=True)
    except service.FocusAreaNotFoundError as error:
        raise not_found(error) from error

@router.post("/{focus_area_id}/restore", response_model=FocusAreaResponse)
async def restore_focus_area(focus_area_id: FocusAreaId, db: DatabaseSession) -> FocusAreaResponse:
    try:
        return await service.set_archived(db, focus_area_id, archived=False)
    except service.FocusAreaNotFoundError as error:
        raise not_found(error) from error

@router.get("/{focus_area_id}/deletion-preview", response_model=FocusAreaDeletionPreview)
async def preview_focus_area_deletion(focus_area_id: FocusAreaId, db: DatabaseSession) -> FocusAreaDeletionPreview:
    try:
        return FocusAreaDeletionPreview(
            has_historical_work=await service.focus_area_has_historical_work(db, focus_area_id)
        )
    except service.FocusAreaNotFoundError as error:
        raise not_found(error) from error
    except service.FocusAreaNotArchivedError as error:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Only archived Focus Areas can be permanently deleted") from error

@router.delete("/{focus_area_id}", status_code=status.HTTP_204_NO_CONTENT)
async def permanently_delete_focus_area(
    focus_area_id: FocusAreaId,
    db: DatabaseSession,
    confirm_historical_work: Annotated[bool, Query()] = False,
) -> Response:
    try:
        await service.delete_focus_area(
            db, focus_area_id, confirm_historical_work=confirm_historical_work
        )
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except service.FocusAreaNotFoundError as error:
        raise not_found(error) from error
    except service.FocusAreaNotArchivedError as error:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Only archived Focus Areas can be permanently deleted") from error
    except service.HistoricalWorkConfirmationRequiredError as error:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Historical work exists; explicit confirmation is required") from error
