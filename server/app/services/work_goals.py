from datetime import date, timedelta
from typing import Any, TypeVar

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.work_goal import DailyWorkGoal
from app.schemas.work_goal import DailyGoalValue, WorkGoalsResponse, WorkGoalsUpdate

GoalVersion = TypeVar("GoalVersion", bound=DailyWorkGoal)


def version_for(versions: list[GoalVersion], work_date: date) -> GoalVersion | None:
    return next(
        (
            version
            for version in versions
            if version.valid_from <= work_date
            and (version.valid_until is None or version.valid_until >= work_date)
        ),
        None,
    )


async def load_daily_goal_history(db: AsyncSession) -> list[DailyWorkGoal]:
    return list(
        await db.scalars(
            select(DailyWorkGoal).order_by(DailyWorkGoal.weekday, DailyWorkGoal.valid_from)
        )
    )


async def get_work_goals(db: AsyncSession, effective_date: date) -> WorkGoalsResponse:
    daily = await load_daily_goal_history(db)
    week_start = _week_start(effective_date)
    return WorkGoalsResponse(
        date=effective_date,
        daily_goals=[
            DailyGoalValue(
                weekday=weekday,
                target_minutes=daily_goal_minutes(
                    daily,
                    _next_weekday_occurrence(effective_date, weekday),
                ),
            )
            for weekday in range(1, 8)
        ],
        weekly_goal_minutes=weekly_goal_minutes(daily, week_start),
        weekly_goal_effective_from=week_start,
    )


async def update_work_goals(
    db: AsyncSession,
    effective_date: date,
    payload: WorkGoalsUpdate,
) -> WorkGoalsResponse:
    daily = await load_daily_goal_history(db)
    for goal in payload.daily_goals:
        versions = [item for item in daily if item.weekday == goal.weekday]
        valid_from = _next_weekday_occurrence(effective_date, goal.weekday)
        current = version_for(versions, valid_from)
        if (current.target_minutes if current else 0) == goal.target_minutes:
            continue
        await _upsert_version(
            db,
            versions,
            DailyWorkGoal,
            valid_from,
            goal.target_minutes,
            weekday=goal.weekday,
        )
    await db.commit()
    return await get_work_goals(db, effective_date)


async def _upsert_version(
    db: AsyncSession,
    versions: list[GoalVersion],
    model: type[GoalVersion],
    valid_from: date,
    target_minutes: int,
    **fields: Any,
) -> None:
    same_date = next((item for item in versions if item.valid_from == valid_from), None)
    if same_date is not None:
        same_date.target_minutes = target_minutes
        return
    previous = next(
        (item for item in reversed(versions) if item.valid_from < valid_from),
        None,
    )
    following = next((item for item in versions if item.valid_from > valid_from), None)
    if previous is not None and (
        previous.valid_until is None or previous.valid_until >= valid_from
    ):
        previous.valid_until = valid_from - timedelta(days=1)
    db.add(
        model(
            target_minutes=target_minutes,
            valid_from=valid_from,
            valid_until=(following.valid_from - timedelta(days=1) if following else None),
            **fields,
        )
    )


def daily_goal_minutes(goals: list[DailyWorkGoal], work_date: date) -> int:
    version = version_for(
        [goal for goal in goals if goal.weekday == work_date.isoweekday()],
        work_date,
    )
    return version.target_minutes if version else 0


def weekly_goal_minutes(goals: list[DailyWorkGoal], week_start: date) -> int:
    return sum(
        daily_goal_minutes(goals, week_start + timedelta(days=offset))
        for offset in range(7)
    )


def _next_weekday_occurrence(effective_date: date, weekday: int) -> date:
    return effective_date + timedelta(
        days=(weekday - effective_date.isoweekday()) % 7,
    )


def _week_start(work_date: date) -> date:
    return work_date - timedelta(days=work_date.weekday())
