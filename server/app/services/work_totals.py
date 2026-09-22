from datetime import date
from dataclasses import dataclass

from sqlalchemy import func, select, union_all
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.manual_work_entry import ManualWorkEntry
from app.models.timer_execution import TimerExecution


def _work_rows():
    return union_all(
        select(
            TimerExecution.work_date.label("work_date"),
            TimerExecution.focus_area_id.label("focus_area_id"),
            TimerExecution.special_activity_id.label("special_activity_id"),
            TimerExecution.focused_seconds.label("focused_seconds"),
            TimerExecution.rest_seconds.label("rest_seconds"),
        ),
        select(
            ManualWorkEntry.work_date,
            ManualWorkEntry.focus_area_id,
            ManualWorkEntry.special_activity_id,
            ManualWorkEntry.focused_seconds,
            ManualWorkEntry.rest_seconds,
        ),
    ).subquery()


@dataclass(frozen=True)
class DailyWorkAggregation:
    focused_seconds: int
    rest_seconds: int
    focused_by_area: dict[int, int]
    time_by_special_activity: dict[int, tuple[int, int]]


async def aggregate_day(db: AsyncSession, work_date: date) -> DailyWorkAggregation:
    """Use the same timer/manual rows for today's totals and work-area progress."""
    rows = _work_rows()
    result = await db.execute(
        select(
            rows.c.focus_area_id,
            rows.c.special_activity_id,
            func.sum(rows.c.focused_seconds),
            func.sum(rows.c.rest_seconds),
        )
        .where(rows.c.work_date == work_date)
        .group_by(rows.c.focus_area_id, rows.c.special_activity_id)
    )
    focused = rest = 0
    by_area: dict[int, int] = {}
    by_special: dict[int, tuple[int, int]] = {}
    for area_id, activity_id, row_focused, row_rest in result.all():
        row_focused, row_rest = int(row_focused), int(row_rest)
        focused += row_focused
        rest += row_rest
        if area_id is not None:
            by_area[int(area_id)] = row_focused
        else:
            by_special[int(activity_id)] = (row_focused, row_rest)
    return DailyWorkAggregation(focused, rest, by_area, by_special)


async def totals_between(
    db: AsyncSession,
    start_date: date,
    end_date: date,
) -> tuple[int, int]:
    rows = _work_rows()
    result = await db.execute(
        select(
            func.coalesce(func.sum(rows.c.focused_seconds), 0),
            func.coalesce(func.sum(rows.c.rest_seconds), 0),
        ).where(rows.c.work_date.between(start_date, end_date))
    )
    focused, rest = result.one()
    return int(focused), int(rest)


async def lifetime_totals(db: AsyncSession) -> tuple[int, int, int]:
    rows = _work_rows()
    result = await db.execute(
        select(
            func.count(func.distinct(rows.c.work_date)),
            func.coalesce(func.sum(rows.c.focused_seconds), 0),
            func.coalesce(func.sum(rows.c.rest_seconds), 0),
        )
    )
    days, focused, rest = result.one()
    return int(days), int(focused), int(rest)
