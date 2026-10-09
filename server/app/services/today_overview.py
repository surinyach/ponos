from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.focus_area import FocusArea
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
from app.services.focus_area_targets import target_for
from app.services.streak_evaluator import daily_goal_minutes, get_streak_summary
from app.services.work_goals import load_goal_history


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
    daily_goals, _ = await load_goal_history(db)
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
        target = target_for(area, work_date)
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
        expected_focus_seconds=daily_goal_minutes(daily_goals, work_date) * 60,
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
        streak=await get_streak_summary(db, areas, work_date),
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
