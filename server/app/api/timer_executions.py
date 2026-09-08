from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.timer_execution import (
    TimerExecutionCreate,
    TimerExecutionResponse,
)
from app.services import timer_executions as service

router = APIRouter(
    prefix="/api/v1/timer-executions",
    tags=["timer-executions"],
)
DatabaseSession = Annotated[AsyncSession, Depends(get_db)]


@router.post(
    "",
    response_model=TimerExecutionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_timer_execution(
    payload: TimerExecutionCreate,
    db: DatabaseSession,
) -> TimerExecutionResponse:
    try:
        return await service.create_timer_execution(db, payload)
    except service.FocusAreaNotFoundError as error:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Focus Area {error.args[0]} was not found",
        ) from error
