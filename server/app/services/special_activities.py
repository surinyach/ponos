from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import IntegrityError

from app.models.special_activity import SpecialActivity
from app.repositories import special_activities as repository
from app.schemas.special_activity import SpecialActivityCreate, SpecialActivityUpdate


class SpecialActivityNotFoundError(Exception):
    pass


class DuplicateSpecialActivityNameError(Exception):
    pass


class SpecialActivityHasWorkError(Exception):
    pass


def _duplicate_name(error: IntegrityError) -> bool:
    return (
        getattr(getattr(error.orig, "diag", None), "constraint_name", None)
        == "uq_special_activities_name_ci"
    )


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
        )
        await repository.add(session, activity)
        await session.commit()
        return activity
    except IntegrityError as error:
        await session.rollback()
        if _duplicate_name(error):
            raise DuplicateSpecialActivityNameError(payload.name) from error
        raise
    except Exception:
        await session.rollback()
        raise


async def list_special_activities(
    session: AsyncSession,
) -> list[SpecialActivity]:
    return await repository.list_all(session)


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
        }.intersection(payload.model_fields_set):
            setattr(activity, field_name, getattr(payload, field_name))
        await session.commit()
        return activity
    except IntegrityError as error:
        await session.rollback()
        if _duplicate_name(error):
            raise DuplicateSpecialActivityNameError(payload.name) from error
        raise
    except Exception:
        await session.rollback()
        raise


async def delete_special_activity(
    session: AsyncSession,
    special_activity_id: int,
) -> None:
    try:
        await _get_required_activity(
            session,
            special_activity_id,
            for_update=True,
        )
        if await repository.has_work(session, special_activity_id):
            raise SpecialActivityHasWorkError(special_activity_id)
        await repository.remove(session, special_activity_id)
        await session.commit()
    except Exception:
        await session.rollback()
        raise
