from sqlalchemy.ext.asyncio import AsyncSession

from app.models.manual_work_entry import ManualWorkEntry
from app.repositories import manual_work_entries as repository
from app.schemas.manual_work_entry import (
    ManualWorkEntryCreate,
    ManualWorkEntryUpdate,
)


class ManualWorkEntryNotFoundError(Exception):
    pass


class FocusAreaNotFoundError(Exception):
    pass


class SpecialActivityNotFoundError(Exception):
    pass


class ArchivedSpecialActivityError(Exception):
    pass


class InvalidManualWorkEntryError(Exception):
    pass


async def _get_entry(
    session: AsyncSession,
    manual_work_entry_id: int,
    *,
    for_update: bool = False,
) -> ManualWorkEntry:
    entry = await repository.get(
        session,
        manual_work_entry_id,
        for_update=for_update,
    )
    if entry is None:
        raise ManualWorkEntryNotFoundError(manual_work_entry_id)
    return entry


async def _validate_subject(
    session: AsyncSession,
    *,
    focus_area_id: int | None,
    special_activity_id: int | None,
) -> None:
    if (focus_area_id is None) == (special_activity_id is None):
        raise InvalidManualWorkEntryError(
            "exactly one linked Focus Area or Special Activity is required"
        )
    if focus_area_id is not None:
        if not await repository.focus_area_exists(session, focus_area_id):
            raise FocusAreaNotFoundError(focus_area_id)
        return

    activity = await repository.get_special_activity(
        session,
        special_activity_id,
    )
    if activity is None:
        raise SpecialActivityNotFoundError(special_activity_id)
    if activity.is_archived:
        raise ArchivedSpecialActivityError(special_activity_id)


def _validate_durations(focused_seconds: int, rest_seconds: int) -> None:
    if focused_seconds < 0 or rest_seconds < 0:
        raise InvalidManualWorkEntryError("durations must be non-negative")
    if focused_seconds == 0 and rest_seconds == 0:
        raise InvalidManualWorkEntryError(
            "focused_seconds and rest_seconds cannot both be 0"
        )


async def create_manual_work_entry(
    session: AsyncSession,
    payload: ManualWorkEntryCreate,
) -> ManualWorkEntry:
    try:
        await _validate_subject(
            session,
            focus_area_id=payload.focus_area_id,
            special_activity_id=payload.special_activity_id,
        )
        _validate_durations(payload.focused_seconds, payload.rest_seconds)
        entry = ManualWorkEntry(
            focus_area_id=payload.focus_area_id,
            special_activity_id=payload.special_activity_id,
            work_date=payload.work_date,
            focused_seconds=payload.focused_seconds,
            rest_seconds=payload.rest_seconds,
        )
        await repository.add(session, entry)
        await session.commit()
        return entry
    except Exception:
        await session.rollback()
        raise


async def list_manual_work_entries(
    session: AsyncSession,
) -> list[ManualWorkEntry]:
    return await repository.list_all(session)


async def update_manual_work_entry(
    session: AsyncSession,
    manual_work_entry_id: int,
    payload: ManualWorkEntryUpdate,
) -> ManualWorkEntry:
    try:
        entry = await _get_entry(
            session,
            manual_work_entry_id,
            for_update=True,
        )
        fields = payload.model_fields_set
        focus_area_id = (
            payload.focus_area_id
            if "focus_area_id" in fields
            else entry.focus_area_id
        )
        special_activity_id = (
            payload.special_activity_id
            if "special_activity_id" in fields
            else entry.special_activity_id
        )
        focused_seconds = (
            payload.focused_seconds
            if "focused_seconds" in fields
            else entry.focused_seconds
        )
        rest_seconds = (
            payload.rest_seconds
            if "rest_seconds" in fields
            else entry.rest_seconds
        )

        if {"focus_area_id", "special_activity_id"}.intersection(fields):
            await _validate_subject(
                session,
                focus_area_id=focus_area_id,
                special_activity_id=special_activity_id,
            )
        _validate_durations(focused_seconds, rest_seconds)

        for field_name in {
            "focus_area_id",
            "special_activity_id",
            "work_date",
            "focused_seconds",
            "rest_seconds",
        }.intersection(fields):
            setattr(entry, field_name, getattr(payload, field_name))
        await session.commit()
        return entry
    except Exception:
        await session.rollback()
        raise


async def delete_manual_work_entry(
    session: AsyncSession,
    manual_work_entry_id: int,
) -> None:
    try:
        entry = await _get_entry(
            session,
            manual_work_entry_id,
            for_update=True,
        )
        await repository.delete(session, entry)
        await session.commit()
    except Exception:
        await session.rollback()
        raise
