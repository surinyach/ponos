from datetime import date, timedelta
from typing import Any, TypeVar

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.work_goal import DailyWorkGoal, WeeklyWorkGoal
from app.schemas.work_goal import DailyGoalValue, WorkGoalsResponse, WorkGoalsUpdate

GoalVersion = TypeVar("GoalVersion", DailyWorkGoal, WeeklyWorkGoal)


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


async def load_goal_history(
    db: AsyncSession,
) -> tuple[list[DailyWorkGoal], list[WeeklyWorkGoal]]:
    daily = list(
        await db.scalars(
            select(DailyWorkGoal).order_by(DailyWorkGoal.weekday, DailyWorkGoal.valid_from)
        )
    )
    weekly = list(
        await db.scalars(select(WeeklyWorkGoal).order_by(WeeklyWorkGoal.valid_from))
    )
    return daily, weekly


async def get_work_goals(db: AsyncSession, effective_date: date) -> WorkGoalsResponse:
    daily, weekly = await load_goal_history(db)
    next_week = _next_week_start(effective_date)
    weekly_version = version_for(weekly, next_week)
    return WorkGoalsResponse(
        date=effective_date,
        daily_goals=[
            DailyGoalValue(
                weekday=weekday,
                target_minutes=(
                    version.target_minutes
                    if (version := version_for(
                        [item for item in daily if item.weekday == weekday],
                        effective_date,
                    ))
                    else 0
                ),
            )
            for weekday in range(1, 8)
        ],
        weekly_goal_minutes=weekly_version.target_minutes if weekly_version else 0,
        weekly_goal_effective_from=weekly_version.valid_from if weekly_version else next_week,
    )


async def update_work_goals(
    db: AsyncSession,
    effective_date: date,
    payload: WorkGoalsUpdate,
) -> WorkGoalsResponse:
    daily, weekly = await load_goal_history(db)
    for goal in payload.daily_goals:
        await _upsert_version(
            db,
            [item for item in daily if item.weekday == goal.weekday],
            DailyWorkGoal,
            effective_date,
            goal.target_minutes,
            weekday=goal.weekday,
        )
    next_week = _next_week_start(effective_date)
    await _upsert_version(
        db,
        weekly,
        WeeklyWorkGoal,
        next_week,
        payload.weekly_goal_minutes,
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


def _next_week_start(work_date: date) -> date:
    return work_date - timedelta(days=work_date.weekday()) + timedelta(days=7)
