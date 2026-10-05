from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.work_goal import WorkGoalsResponse, WorkGoalsUpdate
from app.services.work_goals import get_work_goals, update_work_goals

router = APIRouter(prefix="/api/v1/work-goals", tags=["work goals"])
DatabaseSession = Annotated[AsyncSession, Depends(get_db)]


@router.get("", response_model=WorkGoalsResponse)
async def read_work_goals(
    db: DatabaseSession,
    date_: Annotated[date, Query(alias="date")],
) -> WorkGoalsResponse:
    return await get_work_goals(db, date_)


@router.put("", response_model=WorkGoalsResponse)
async def save_work_goals(
    payload: WorkGoalsUpdate,
    db: DatabaseSession,
    date_: Annotated[date, Query(alias="date")],
) -> WorkGoalsResponse:
    return await update_work_goals(db, date_, payload)
