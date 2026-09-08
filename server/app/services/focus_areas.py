from datetime import datetime, timedelta, timezone
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from app.models.focus_area import FocusArea, FocusAreaTarget
from app.schemas.focus_area import FocusAreaCreate, FocusAreaPrioritiesUpdate, FocusAreaUpdate, WeekdayTargetCreate

class FocusAreaNotFoundError(Exception):
    pass

class TargetVersionConflictError(Exception):
    pass

def _query_with_targets():
    return select(FocusArea).options(selectinload(FocusArea.targets))

async def _get_locked(session: AsyncSession, focus_area_id: int) -> FocusArea:
    result = await session.execute(select(FocusArea).where(FocusArea.id == focus_area_id).with_for_update())
    focus_area = result.scalar_one_or_none()
    if focus_area is None:
        raise FocusAreaNotFoundError(focus_area_id)
    return focus_area

async def _get_with_targets(session: AsyncSession, focus_area_id: int) -> FocusArea:
    result = await session.execute(_query_with_targets().where(FocusArea.id == focus_area_id))
    focus_area = result.scalar_one_or_none()
    if focus_area is None:
        raise FocusAreaNotFoundError(focus_area_id)
    focus_area.targets.sort(key=lambda item: (item.weekday, item.valid_from))
    return focus_area

async def create_focus_area(session: AsyncSession, payload: FocusAreaCreate) -> FocusArea:
    try:
        focus_area = FocusArea(
            name=payload.name, description=payload.description, priority=payload.priority,
            target_end_date=payload.target_end_date,
            targets=[FocusAreaTarget(weekday=item.weekday, target_minutes=item.target_minutes, valid_from=item.valid_from) for item in payload.targets],
        )
        session.add(focus_area)
        await session.commit()
        return await _get_with_targets(session, focus_area.id)
    except Exception:
        await session.rollback()
        raise

async def list_focus_areas(session: AsyncSession, *, archived: bool) -> list[FocusArea]:
    archive_filter = FocusArea.archived_at.is_not(None) if archived else FocusArea.archived_at.is_(None)
    result = await session.execute(_query_with_targets().where(archive_filter).order_by(FocusArea.priority, FocusArea.id))
    focus_areas = list(result.scalars().all())
    for focus_area in focus_areas:
        focus_area.targets.sort(key=lambda item: (item.weekday, item.valid_from))
    return focus_areas

async def get_focus_area(session: AsyncSession, focus_area_id: int) -> FocusArea:
    return await _get_with_targets(session, focus_area_id)

async def _append_target_version(session: AsyncSession, focus_area_id: int, item: WeekdayTargetCreate) -> None:
    result = await session.execute(
        select(FocusAreaTarget)
        .where(FocusAreaTarget.focus_area_id == focus_area_id, FocusAreaTarget.weekday == item.weekday)
        .order_by(FocusAreaTarget.valid_from).with_for_update()
    )
    versions = list(result.scalars().all())
    if any(version.valid_from == item.valid_from for version in versions):
        raise TargetVersionConflictError(
            f"weekday {item.weekday} already has a target starting on {item.valid_from.isoformat()}"
        )
    previous = next((version for version in reversed(versions) if version.valid_from < item.valid_from), None)
    following = next((version for version in versions if version.valid_from > item.valid_from), None)
    if previous is not None and (previous.valid_until is None or previous.valid_until >= item.valid_from):
        previous.valid_until = item.valid_from - timedelta(days=1)
    session.add(FocusAreaTarget(
        focus_area_id=focus_area_id, weekday=item.weekday, target_minutes=item.target_minutes,
        valid_from=item.valid_from,
        valid_until=(following.valid_from - timedelta(days=1) if following else None),
    ))

async def update_focus_area(session: AsyncSession, focus_area_id: int, payload: FocusAreaUpdate) -> FocusArea:
    try:
        focus_area = await _get_locked(session, focus_area_id)
        for field_name in {"name", "description", "priority", "target_end_date"}.intersection(payload.model_fields_set):
            setattr(focus_area, field_name, getattr(payload, field_name))
        if "targets" in payload.model_fields_set and payload.targets is not None:
            for item in payload.targets:
                await _append_target_version(session, focus_area_id, item)
        await session.commit()
        return await _get_with_targets(session, focus_area_id)
    except Exception:
        await session.rollback()
        raise

async def set_archived(session: AsyncSession, focus_area_id: int, *, archived: bool) -> FocusArea:
    try:
        focus_area = await _get_locked(session, focus_area_id)
        focus_area.archived_at = datetime.now(timezone.utc) if archived else None
        await session.commit()
        return await _get_with_targets(session, focus_area_id)
    except Exception:
        await session.rollback()
        raise

async def update_priorities(session: AsyncSession, payload: FocusAreaPrioritiesUpdate) -> list[FocusArea]:
    identifiers = [item.id for item in payload.items]
    try:
        result = await session.execute(
            select(FocusArea).where(FocusArea.id.in_(identifiers)).order_by(FocusArea.id).with_for_update()
        )
        focus_areas = {item.id: item for item in result.scalars().all()}
        missing = set(identifiers).difference(focus_areas)
        if missing:
            raise FocusAreaNotFoundError(min(missing))
        for item in payload.items:
            focus_areas[item.id].priority = item.priority
        await session.commit()
        refreshed = [await _get_with_targets(session, item.id) for item in payload.items]
        return sorted(refreshed, key=lambda item: (item.priority, item.id))
    except Exception:
        await session.rollback()
        raise
