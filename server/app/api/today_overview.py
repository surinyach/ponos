from datetime import date, datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.schemas.today_overview import TodayOverviewResponse
from app.schemas.work_totals import OverallTotalsResponse, WeekTotalsResponse
from app.services.today_overview import get_today_overview
from app.services.work_totals import lifetime_totals, totals_between

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
    return await get_today_overview(db, date_)


@router.get("/week", response_model=WeekTotalsResponse)
async def week_totals(
    db: DatabaseSession,
    date_: Annotated[date, Query(alias="date")],
) -> WeekTotalsResponse:
    week_start = date_ - timedelta(days=date_.weekday())
    week_end = week_start + timedelta(days=6)
    focused, rest = await totals_between(db, week_start, week_end)
    return WeekTotalsResponse(
        week_start=week_start,
        week_end=week_end,
        focused_seconds=focused,
        rest_seconds=rest,
        tracked_seconds=focused + rest,
    )


@router.get("/overall", response_model=OverallTotalsResponse)
async def overall_totals(db: DatabaseSession) -> OverallTotalsResponse:
    days, focused, rest = await lifetime_totals(db)
    return OverallTotalsResponse(
        days_worked=days,
        focused_seconds=focused,
        rest_seconds=rest,
        tracked_seconds=focused + rest,
    )
