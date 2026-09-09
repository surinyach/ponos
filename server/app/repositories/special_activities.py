from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.special_activity import SpecialActivity


async def add(
    session: AsyncSession,
    special_activity: SpecialActivity,
) -> SpecialActivity:
    session.add(special_activity)
    await session.flush()
    return special_activity


async def list_by_archive_state(
    session: AsyncSession,
    *,
    archived: bool,
) -> list[SpecialActivity]:
    result = await session.scalars(
        select(SpecialActivity)
        .where(SpecialActivity.is_archived.is_(archived))
        .order_by(SpecialActivity.work_date.desc(), SpecialActivity.id)
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
