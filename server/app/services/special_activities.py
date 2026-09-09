from sqlalchemy.ext.asyncio import AsyncSession

from app.models.special_activity import SpecialActivity
from app.repositories import special_activities as repository
from app.schemas.special_activity import SpecialActivityCreate, SpecialActivityUpdate


class SpecialActivityNotFoundError(Exception):
    pass


async def _get_required_activity(
    session: AsyncSession,
    special_activity_id: int,
    *,
    for_update: bool = False,
) -> SpecialActivity:
    activity = await repository.get(
        session,
        special_activity_id,
        for_update=for_update,
    )
    if activity is None:
        raise SpecialActivityNotFoundError(special_activity_id)
    return activity


async def create_special_activity(
    session: AsyncSession,
    payload: SpecialActivityCreate,
) -> SpecialActivity:
    try:
        activity = SpecialActivity(
            name=payload.name,
            description=payload.description,
            work_date=payload.work_date,
        )
        await repository.add(session, activity)
        await session.commit()
        return activity
    except Exception:
        await session.rollback()
        raise


async def list_special_activities(
    session: AsyncSession,
    *,
    archived: bool,
) -> list[SpecialActivity]:
    return await repository.list_by_archive_state(session, archived=archived)


async def get_special_activity(
    session: AsyncSession,
    special_activity_id: int,
) -> SpecialActivity:
    return await _get_required_activity(session, special_activity_id)


async def update_special_activity(
    session: AsyncSession,
    special_activity_id: int,
    payload: SpecialActivityUpdate,
) -> SpecialActivity:
    try:
        activity = await _get_required_activity(
            session,
            special_activity_id,
            for_update=True,
        )
        for field_name in {
            "name",
            "description",
            "work_date",
        }.intersection(payload.model_fields_set):
            setattr(activity, field_name, getattr(payload, field_name))
        await session.commit()
        return activity
    except Exception:
        await session.rollback()
        raise


async def set_archived(
    session: AsyncSession,
    special_activity_id: int,
    *,
    archived: bool,
) -> SpecialActivity:
    try:
        activity = await _get_required_activity(
            session,
            special_activity_id,
            for_update=True,
        )
        activity.is_archived = archived
        await session.commit()
        return activity
    except Exception:
        await session.rollback()
        raise
