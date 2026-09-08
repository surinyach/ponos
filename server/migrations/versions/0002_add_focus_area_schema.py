"""Add Focus Area persistence schema.

Revision ID: 0002
Revises: 0001
Create Date: 2026-09-04
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "0002"
down_revision: str | None = "0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS btree_gist")

    op.create_table(
        "focus_areas",
        sa.Column("id", sa.BigInteger(), sa.Identity(), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("priority", sa.Integer(), nullable=False),
        sa.Column("target_end_date", sa.Date(), nullable=True),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id", name="pk_focus_areas"),
    )

    op.create_table(
        "focus_area_targets",
        sa.Column("id", sa.BigInteger(), sa.Identity(), nullable=False),
        sa.Column("focus_area_id", sa.BigInteger(), nullable=False),
        sa.Column("weekday", sa.SmallInteger(), nullable=False),
        sa.Column("target_minutes", sa.Integer(), nullable=False),
        sa.Column("valid_from", sa.Date(), nullable=False),
        sa.Column("valid_until", sa.Date(), nullable=True),
        sa.CheckConstraint(
            "target_minutes >= 0",
            name="ck_focus_area_targets_minutes_nonnegative",
        ),
        sa.CheckConstraint(
            "valid_until IS NULL OR valid_until >= valid_from",
            name="ck_focus_area_targets_valid_period",
        ),
        sa.CheckConstraint(
            "weekday BETWEEN 1 AND 7",
            name="ck_focus_area_targets_weekday",
        ),
        postgresql.ExcludeConstraint(
            ("focus_area_id", "="),
            ("weekday", "="),
            (sa.text("daterange(valid_from, valid_until, '[]')"), "&&"),
            name="excl_focus_area_targets_no_overlap",
            using="gist",
        ),
        sa.ForeignKeyConstraint(
            ["focus_area_id"],
            ["focus_areas.id"],
            name="fk_focus_area_targets_focus_area_id_focus_areas",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_focus_area_targets"),
    )
    op.create_index(
        "ix_focus_area_targets_focus_area_id",
        "focus_area_targets",
        ["focus_area_id"],
    )

    op.create_table(
        "timer_executions",
        sa.Column("id", sa.BigInteger(), sa.Identity(), nullable=False),
        sa.Column("focus_area_id", sa.BigInteger(), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("focused_seconds", sa.Integer(), nullable=False),
        sa.Column("rest_seconds", sa.Integer(), nullable=False),
        sa.CheckConstraint(
            "ended_at >= started_at",
            name="ck_timer_executions_valid_period",
        ),
        sa.CheckConstraint(
            "focused_seconds >= 0",
            name="ck_timer_executions_focused_nonnegative",
        ),
        sa.CheckConstraint(
            "rest_seconds >= 0",
            name="ck_timer_executions_rest_nonnegative",
        ),
        sa.ForeignKeyConstraint(
            ["focus_area_id"],
            ["focus_areas.id"],
            name="fk_timer_executions_focus_area_id_focus_areas",
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_timer_executions"),
    )
    op.create_index(
        "ix_timer_executions_focus_area_id",
        "timer_executions",
        ["focus_area_id"],
    )
    op.create_index(
        "ix_timer_executions_started_at",
        "timer_executions",
        ["started_at"],
    )


def downgrade() -> None:
    op.drop_index("ix_timer_executions_started_at", table_name="timer_executions")
    op.drop_index(
        "ix_timer_executions_focus_area_id",
        table_name="timer_executions",
    )
    op.drop_table("timer_executions")
    op.drop_index(
        "ix_focus_area_targets_focus_area_id",
        table_name="focus_area_targets",
    )
    op.drop_table("focus_area_targets")
    op.drop_table("focus_areas")