from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.focus_area import FocusArea
from app.models.special_activity import SpecialActivity
from app.models.timer_execution import TimerExecution


async def focus_area_exists(session: AsyncSession, focus_area_id: int) -> bool:
    result = await session.scalar(
        select(FocusArea.id).where(FocusArea.id == focus_area_id)
    )
    return result is not None


async def special_activity_exists(
    session: AsyncSession, special_activity_id: int
) -> bool:
    return await session.scalar(
        select(SpecialActivity.id).where(
            SpecialActivity.id == special_activity_id
        )
    ) is not None


async def add(
    session: AsyncSession,
    execution: TimerExecution,
) -> TimerExecution:
    session.add(execution)
    await session.flush()
    return execution
