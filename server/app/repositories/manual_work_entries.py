from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.focus_area import FocusArea
from app.models.manual_work_entry import ManualWorkEntry
from app.models.special_activity import SpecialActivity


async def add(
    session: AsyncSession,
    entry: ManualWorkEntry,
) -> ManualWorkEntry:
    session.add(entry)
    await session.flush()
    return entry


async def list_all(session: AsyncSession) -> list[ManualWorkEntry]:
    result = await session.scalars(
        select(ManualWorkEntry).order_by(
            ManualWorkEntry.work_date.desc(),
            ManualWorkEntry.id,
        )
    )
    return list(result.all())


async def get(
    session: AsyncSession,
    manual_work_entry_id: int,
    *,
    for_update: bool = False,
) -> ManualWorkEntry | None:
    statement = select(ManualWorkEntry).where(
        ManualWorkEntry.id == manual_work_entry_id
    )
    if for_update:
        statement = statement.with_for_update()
    return await session.scalar(statement)


async def focus_area_exists(session: AsyncSession, focus_area_id: int) -> bool:
    return (
        await session.scalar(
            select(FocusArea.id).where(FocusArea.id == focus_area_id)
        )
        is not None
    )


async def get_special_activity(
    session: AsyncSession,
    special_activity_id: int,
) -> SpecialActivity | None:
    return await session.scalar(
        select(SpecialActivity).where(
            SpecialActivity.id == special_activity_id
        )
    )


async def delete(session: AsyncSession, entry: ManualWorkEntry) -> None:
    await session.delete(entry)
