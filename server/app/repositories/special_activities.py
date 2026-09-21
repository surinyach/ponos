from sqlalchemy import delete, exists, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.special_activity import SpecialActivity
from app.models.manual_work_entry import ManualWorkEntry
from app.models.timer_execution import TimerExecution


async def add(
    session: AsyncSession,
    special_activity: SpecialActivity,
) -> SpecialActivity:
    session.add(special_activity)
    await session.flush()
    return special_activity


async def list_all(session: AsyncSession) -> list[SpecialActivity]:
    result = await session.scalars(
        select(SpecialActivity)
        .order_by(SpecialActivity.id)
    )
    return list(result.all())


async def get(
    session: AsyncSession,
    special_activity_id: int,
    *,
    for_update: bool = False,
) -> SpecialActivity | None:
    statement = select(SpecialActivity).where(
        SpecialActivity.id == special_activity_id
    )
    if for_update:
        statement = statement.with_for_update()
    return await session.scalar(statement)


async def has_work(session: AsyncSession, special_activity_id: int) -> bool:
    manual = await session.scalar(
        select(exists().where(ManualWorkEntry.special_activity_id == special_activity_id))
    )
    if manual:
        return True
    timer = await session.scalar(
        select(exists().where(TimerExecution.special_activity_id == special_activity_id))
    )
    return bool(timer)


async def remove(session: AsyncSession, special_activity_id: int) -> None:
    await session.execute(
        delete(SpecialActivity).where(SpecialActivity.id == special_activity_id)
    )
