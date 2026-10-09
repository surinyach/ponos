from datetime import date, timedelta
from enum import StrEnum

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.focus_area import FocusArea
from app.models.work_goal import DailyWorkGoal, WeeklyWorkGoal
from app.schemas.today_overview import DailyCompletionResponse, StreakSummaryResponse
from app.services.focus_area_targets import target_for
from app.services.work_goals import load_goal_history, version_for
from app.services.work_totals import DailyWorkAggregation, aggregate_days


class PeriodState(StrEnum):
    COMPLETED = "completed"
    FAILED = "failed"
    NEUTRAL = "neutral"
    IN_PROGRESS = "in_progress"


async def get_streak_summary(
    db: AsyncSession,
    areas: list[FocusArea],
    today: date,
) -> StreakSummaryResponse:
    daily_goals, weekly_goals = await load_goal_history(db)
    starts = [goal.valid_from for goal in daily_goals + weekly_goals]
    starts.extend(target.valid_from for area in areas for target in area.targets)
    earliest = min(starts, default=today)
    totals = await aggregate_days(db, earliest, today)
    recent_start = today - timedelta(days=6)
    recent_days = []
    for offset in range(7):
        work_date = recent_start + timedelta(days=offset)
        state = (
            PeriodState.IN_PROGRESS
            if work_date == today
            else _daily_state(areas, daily_goals, totals, work_date)
        )
        recent_days.append(
            DailyCompletionResponse(
                date=work_date,
                completed=state == PeriodState.COMPLETED,
                state=state.value,
            )
        )
    return StreakSummaryResponse(
        current_daily_streak=_daily_streak(areas, daily_goals, totals, today, earliest),
        current_weekly_streak=_weekly_streak(
            areas,
            weekly_goals,
            totals,
            today,
            earliest,
        ),
        recent_days=recent_days,
    )


def daily_goal_minutes(goals: list[DailyWorkGoal], work_date: date) -> int:
    version = version_for(
        [goal for goal in goals if goal.weekday == work_date.isoweekday()],
        work_date,
    )
    return version.target_minutes if version else 0


def _daily_streak(
    areas: list[FocusArea],
    goals: list[DailyWorkGoal],
    totals: dict[date, DailyWorkAggregation],
    today: date,
    earliest: date,
) -> int:
    streak = 0
    cursor = today - timedelta(days=1)
    while cursor >= earliest:
        state = _daily_state(areas, goals, totals, cursor)
        if state == PeriodState.COMPLETED:
            streak += 1
        elif state == PeriodState.FAILED:
            break
        cursor -= timedelta(days=1)
    return streak


def _daily_state(
    areas: list[FocusArea],
    goals: list[DailyWorkGoal],
    totals: dict[date, DailyWorkAggregation],
    work_date: date,
) -> PeriodState:
    daily = totals.get(work_date, _empty_day())
    global_goal_seconds = daily_goal_minutes(goals, work_date) * 60
    obligations = [
        (area, target.target_minutes * 60)
        for area in areas
        if area.priority == 1
        and (target := target_for(area, work_date)) is not None
        and target.target_minutes > 0
    ]
    if global_goal_seconds == 0 and not obligations:
        return PeriodState.NEUTRAL
    compulsory_met = all(
        daily.focused_by_area.get(area.id, 0) >= target_seconds
        for area, target_seconds in obligations
    )
    if daily.focused_seconds >= global_goal_seconds and compulsory_met:
        return PeriodState.COMPLETED
    return PeriodState.FAILED


def _weekly_streak(
    areas: list[FocusArea],
    goals: list[WeeklyWorkGoal],
    totals: dict[date, DailyWorkAggregation],
    today: date,
    earliest: date,
) -> int:
    streak = 0
    cursor = today - timedelta(days=today.weekday() + 7)
    earliest_week = earliest - timedelta(days=earliest.weekday())
    while cursor >= earliest_week:
        state = _weekly_state(areas, goals, totals, cursor)
        if state == PeriodState.COMPLETED:
            streak += 1
        elif state == PeriodState.FAILED:
            break
        cursor -= timedelta(days=7)
    return streak


def _weekly_state(
    areas: list[FocusArea],
    goals: list[WeeklyWorkGoal],
    totals: dict[date, DailyWorkAggregation],
    week_start: date,
) -> PeriodState:
    goal = version_for(goals, week_start)
    obligations: list[tuple[date, FocusArea, int]] = []
    focused_seconds = 0
    for offset in range(7):
        work_date = week_start + timedelta(days=offset)
        daily = totals.get(work_date, _empty_day())
        focused_seconds += daily.focused_seconds
        obligations.extend(
            (work_date, area, target.target_minutes * 60)
            for area in areas
            if area.priority == 1
            and (target := target_for(area, work_date)) is not None
            and target.target_minutes > 0
        )
    if (goal is None or goal.target_minutes == 0) and not obligations:
        return PeriodState.NEUTRAL
    compulsory_met = all(
        totals.get(work_date, _empty_day()).focused_by_area.get(area.id, 0)
        >= target_seconds
        for work_date, area, target_seconds in obligations
    )
    weekly_goal_seconds = (goal.target_minutes if goal else 0) * 60
    if focused_seconds >= weekly_goal_seconds and compulsory_met:
        return PeriodState.COMPLETED
    return PeriodState.FAILED


def _empty_day() -> DailyWorkAggregation:
    return DailyWorkAggregation(0, 0, {}, {})
