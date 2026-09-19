from datetime import date

from sqlalchemy import func, select, union_all
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.manual_work_entry import ManualWorkEntry
from app.models.timer_execution import TimerExecution


def _work_rows():
    return union_all(
        select(
            TimerExecution.work_date.label("work_date"),
            TimerExecution.focus_area_id.label("focus_area_id"),
            TimerExecution.focused_seconds.label("focused_seconds"),
            TimerExecution.rest_seconds.label("rest_seconds"),
        ),
        select(
            ManualWorkEntry.work_date,
            ManualWorkEntry.focus_area_id,
            ManualWorkEntry.focused_seconds,
            ManualWorkEntry.rest_seconds,
        ),
    ).subquery()


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


async def focused_by_area(
    db: AsyncSession,
    work_date: date,
) -> dict[int, int]:
    rows = _work_rows()
    result = await db.execute(
        select(
            rows.c.focus_area_id,
            func.coalesce(func.sum(rows.c.focused_seconds), 0),
        )
        .where(
            rows.c.work_date == work_date,
            rows.c.focus_area_id.is_not(None),
        )
        .group_by(rows.c.focus_area_id)
    )
    return {int(area_id): int(seconds) for area_id, seconds in result.all()}


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
