from sqlalchemy.ext.asyncio import AsyncSession

from app.models.timer_execution import TimerExecution
from app.repositories import timer_executions as repository
from app.schemas.timer_execution import TimerExecutionCreate


class FocusAreaNotFoundError(Exception):
    pass


class SpecialActivityNotFoundError(Exception):
    pass


async def create_timer_execution(
    session: AsyncSession,
    payload: TimerExecutionCreate,
) -> TimerExecution:
    try:
        if payload.focus_area_id is not None:
            if not await repository.focus_area_exists(session, payload.focus_area_id):
                raise FocusAreaNotFoundError(payload.focus_area_id)
        else:
            exists = await repository.special_activity_exists(
                session, payload.special_activity_id
            )
            if not exists:
                raise SpecialActivityNotFoundError(payload.special_activity_id)

        execution = TimerExecution(
            focus_area_id=payload.focus_area_id,
            special_activity_id=payload.special_activity_id,
            work_date=payload.work_date,
            started_at=payload.started_at,
            ended_at=payload.ended_at,
            focused_seconds=payload.focused_seconds,
            rest_seconds=payload.rest_seconds,
        )
        await repository.add(session, execution)
        await session.commit()
        await session.refresh(execution)
        return execution
    except Exception:
        await session.rollback()
        raise
