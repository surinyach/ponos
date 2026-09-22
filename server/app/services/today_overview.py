from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.focus_area import FocusArea, FocusAreaTarget
from app.models.special_activity import SpecialActivity
from app.schemas.today_overview import (
    FocusAreaTodayProgress,
    SpecialActivityTodayProgress,
    TodayOverviewResponse,
)
from app.schemas.work_totals import OverallTotalsResponse, WeekTotalsResponse
from app.services.work_totals import (
    aggregate_day,
    lifetime_totals,
    totals_between,
)


async def get_today_overview(
    db: AsyncSession,
    work_date: date,
) -> TodayOverviewResponse:
    areas = list(
        (
            await db.scalars(
                select(FocusArea)
                .where(FocusArea.archived_at.is_(None))
                .options(selectinload(FocusArea.targets))
                .order_by(FocusArea.priority, FocusArea.id)
            )
        ).all()
    )

    daily = await aggregate_day(db, work_date)
    special_time = daily.time_by_special_activity
    special_activities = list(
        (
            await db.scalars(
                select(SpecialActivity)
                .where(SpecialActivity.id.in_(special_time))
                .order_by(SpecialActivity.id)
            )
        ).all()
    )
    actual_focused, actual_rest = daily.focused_seconds, daily.rest_seconds

    progress = []
    for area in areas:
        target = _target_for(area, work_date)
        target_seconds = None if target is None else target.target_minutes * 60
        focused_seconds = daily.focused_by_area.get(area.id, 0)
        progress.append(
            FocusAreaTodayProgress(
                focus_area=area,
                target_seconds=target_seconds,
                focused_seconds=focused_seconds,
                completed=(
                    target_seconds is not None
                    and focused_seconds >= target_seconds
                ),
            )
        )

    targeted = [item for item in progress if item.target_seconds is not None]
    week_start = work_date - timedelta(days=work_date.weekday())
    week_end = week_start + timedelta(days=6)
    week_focused, week_rest = await totals_between(db, week_start, week_end)
    days, overall_focused, overall_rest = await lifetime_totals(db)
    return TodayOverviewResponse(
        date=work_date,
        expected_focus_seconds=sum(item.target_seconds or 0 for item in targeted),
        actual_focused_seconds=actual_focused,
        actual_rest_seconds=actual_rest,
        actual_tracked_seconds=actual_focused + actual_rest,
        completed_focus_areas=sum(item.completed for item in targeted),
        targeted_focus_areas=len(targeted),
        areas=progress,
        special_activities=[
            SpecialActivityTodayProgress(
                special_activity=activity,
                focused_seconds=special_time[activity.id][0],
                rest_seconds=special_time[activity.id][1],
            )
            for activity in special_activities
        ],
        week=WeekTotalsResponse(
            week_start=week_start,
            week_end=week_end,
            focused_seconds=week_focused,
            rest_seconds=week_rest,
            tracked_seconds=week_focused + week_rest,
        ),
        overall=OverallTotalsResponse(
            days_worked=days,
            focused_seconds=overall_focused,
            rest_seconds=overall_rest,
            tracked_seconds=overall_focused + overall_rest,
        ),
    )


def _target_for(area: FocusArea, work_date: date) -> FocusAreaTarget | None:
    if area.target_end_date is not None and work_date > area.target_end_date:
        return None
    return next(
        (
            target
            for target in area.targets
            if target.weekday == work_date.isoweekday()
            and target.valid_from <= work_date
            and (target.valid_until is None or target.valid_until >= work_date)
        ),
        None,
    )
