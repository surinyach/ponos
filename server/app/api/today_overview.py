from datetime import date, datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.today_overview import TodayOverviewResponse
from app.services.today_overview import get_today_overview

router = APIRouter(prefix="/api/v1/overview", tags=["overview"])
DatabaseSession = Annotated[AsyncSession, Depends(get_db)]


@router.get("/today", response_model=TodayOverviewResponse)
async def today_overview(
    db: DatabaseSession,
    date_: Annotated[date, Query(alias="date")],
    day_start_utc: Annotated[datetime, Query()],
    day_end_utc: Annotated[datetime, Query()],
) -> TodayOverviewResponse:
    if day_start_utc.tzinfo is None or day_end_utc.tzinfo is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Day boundaries must include a timezone offset",
        )
    start = day_start_utc.astimezone(timezone.utc)
    end = day_end_utc.astimezone(timezone.utc)
    if not timedelta(hours=22) <= end - start <= timedelta(hours=26):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Day boundaries must describe one local calendar day",
        )
    return await get_today_overview(db, date_, start, end)
