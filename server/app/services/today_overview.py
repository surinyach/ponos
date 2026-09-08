from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.focus_area import FocusArea, FocusAreaTarget
from app.models.timer_execution import TimerExecution
from app.schemas.today_overview import (
    FocusAreaTodayProgress,
    TodayOverviewResponse,
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

    focused_by_area = dict(
        (
            await db.execute(
                select(
                    TimerExecution.focus_area_id,
                    func.coalesce(func.sum(TimerExecution.focused_seconds), 0),
                )
                .join(FocusArea)
                .where(
                    FocusArea.archived_at.is_(None),
                    TimerExecution.work_date == work_date,
                )
                .group_by(TimerExecution.focus_area_id)
            )
        ).all()
    )

    progress = []
    for area in areas:
        target = _target_for(area, work_date)
        target_seconds = None if target is None else target.target_minutes * 60
        focused_seconds = int(focused_by_area.get(area.id, 0))
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
    return TodayOverviewResponse(
        date=work_date,
        expected_focus_seconds=sum(item.target_seconds or 0 for item in targeted),
        actual_focused_seconds=sum(item.focused_seconds for item in progress),
        completed_focus_areas=sum(item.completed for item in targeted),
        targeted_focus_areas=len(targeted),
        areas=progress,
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
