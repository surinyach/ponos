from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    Integer,
    SmallInteger,
)
from sqlalchemy.dialects.postgresql import ExcludeConstraint

import app.models  # noqa: F401
from app.db.base import Base


def test_focus_area_tables_are_registered() -> None:
    assert {
        "focus_areas",
        "focus_area_targets",
        "timer_executions",
        "special_activities",
        "manual_work_entries",
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
    assert isinstance(table.c.work_date.type, Date)
    assert table.c.work_date.nullable is False
    assert table.c.started_at.type.timezone is True
    assert table.c.ended_at.type.timezone is True
    assert {"focused_seconds", "rest_seconds"}.issubset(table.c.keys())
    assert not {"total_focused_time", "total_rest_time", "total_time"}.intersection(
        table.c.keys()
    )
    assert "ix_timer_executions_work_date" in {
        index.name for index in table.indexes
    }


def test_special_activity_columns_match_storage_contract() -> None:
    table = Base.metadata.tables["special_activities"]

    assert isinstance(table.c.id.type, BigInteger)
    assert table.c.name.type.length == 100
    assert table.c.name.nullable is False
    assert table.c.description.nullable is True
    assert isinstance(table.c.work_date.type, Date)
    assert table.c.work_date.nullable is False
    assert isinstance(table.c.is_archived.type, Boolean)
    assert table.c.is_archived.nullable is False
    assert str(table.c.is_archived.server_default.arg) == "false"


def test_manual_work_entry_columns_and_constraints_match_contract() -> None:
    table = Base.metadata.tables["manual_work_entries"]
    constraint_names = {
        constraint.name
        for constraint in table.constraints
        if isinstance(constraint, CheckConstraint)
    }

    assert isinstance(table.c.id.type, BigInteger)
    assert table.c.focus_area_id.nullable is True
    assert table.c.special_activity_id.nullable is True
    assert table.c.work_date.nullable is False
    assert table.c.focused_seconds.nullable is False
    assert table.c.rest_seconds.nullable is False
    assert {
        "ck_manual_work_entries_exactly_one_subject",
        "ck_manual_work_entries_focused_nonnegative",
        "ck_manual_work_entries_rest_nonnegative",
        "ck_manual_work_entries_duration_nonzero",
    }.issubset(constraint_names)
    assert {
        "ix_manual_work_entries_focus_area_id",
        "ix_manual_work_entries_special_activity_id",
        "ix_manual_work_entries_work_date",
    } == {index.name for index in table.indexes}
