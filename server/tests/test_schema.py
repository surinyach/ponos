from sqlalchemy import BigInteger, DateTime, Integer, SmallInteger
from sqlalchemy.dialects.postgresql import ExcludeConstraint

import app.models  # noqa: F401
from app.db.base import Base


def test_focus_area_tables_are_registered() -> None:
    assert {
        "focus_areas",
        "focus_area_targets",
        "timer_executions",
    }.issubset(Base.metadata.tables)


def test_focus_area_columns_match_storage_contract() -> None:
    table = Base.metadata.tables["focus_areas"]

    assert isinstance(table.c.id.type, BigInteger)
    assert table.c.name.type.length == 100
    assert table.c.name.nullable is False
    assert isinstance(table.c.priority.type, Integer)
    assert table.c.archived_at.type.timezone is True
    assert table.c.created_at.nullable is False
    assert table.c.updated_at.nullable is False


def test_target_constraints_include_overlap_protection() -> None:
    table = Base.metadata.tables["focus_area_targets"]

    assert isinstance(table.c.weekday.type, SmallInteger)
    assert isinstance(table.c.target_minutes.type, Integer)
    assert any(
        isinstance(constraint, ExcludeConstraint)
        and constraint.name == "excl_focus_area_targets_no_overlap"
        for constraint in table.constraints
    )


def test_timer_executions_store_only_source_durations() -> None:
    table = Base.metadata.tables["timer_executions"]

    assert isinstance(table.c.id.type, BigInteger)
    assert isinstance(table.c.started_at.type, DateTime)
    assert table.c.started_at.type.timezone is True
    assert table.c.ended_at.type.timezone is True
    assert {"focused_seconds", "rest_seconds"}.issubset(table.c.keys())
    assert not {"total_focused_time", "total_rest_time", "total_time"}.intersection(
        table.c.keys()
    )