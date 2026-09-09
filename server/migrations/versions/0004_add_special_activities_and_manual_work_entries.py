"""Add Special Activities and Manual Work Entries.

Revision ID: 0004
Revises: 0003
Create Date: 2026-09-09
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0004"
down_revision: str | None = "0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "special_activities",
        sa.Column("id", sa.BigInteger(), sa.Identity(), nullable=False),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("work_date", sa.Date(), nullable=False),
        sa.Column(
            "is_archived",
            sa.Boolean(),
            server_default=sa.false(),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id", name="pk_special_activities"),
    )

    op.create_table(
        "manual_work_entries",
        sa.Column("id", sa.BigInteger(), sa.Identity(), nullable=False),
        sa.Column("focus_area_id", sa.BigInteger(), nullable=True),
        sa.Column("special_activity_id", sa.BigInteger(), nullable=True),
        sa.Column("work_date", sa.Date(), nullable=False),
        sa.Column("focused_seconds", sa.Integer(), nullable=False),
        sa.Column("rest_seconds", sa.Integer(), nullable=False),
        sa.CheckConstraint(
            "(focus_area_id IS NOT NULL) <> "
            "(special_activity_id IS NOT NULL)",
            name="ck_manual_work_entries_exactly_one_subject",
        ),
        sa.CheckConstraint(
            "focused_seconds >= 0",
            name="ck_manual_work_entries_focused_nonnegative",
        ),
        sa.CheckConstraint(
            "rest_seconds >= 0",
            name="ck_manual_work_entries_rest_nonnegative",
        ),
        sa.CheckConstraint(
            "focused_seconds > 0 OR rest_seconds > 0",
            name="ck_manual_work_entries_duration_nonzero",
        ),
        sa.ForeignKeyConstraint(
            ["focus_area_id"],
            ["focus_areas.id"],
            name="fk_manual_work_entries_focus_area_id_focus_areas",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["special_activity_id"],
            ["special_activities.id"],
            name=(
                "fk_manual_work_entries_special_activity_id_"
                "special_activities"
            ),
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_manual_work_entries"),
    )
    op.create_index(
        "ix_manual_work_entries_focus_area_id",
        "manual_work_entries",
        ["focus_area_id"],
    )
    op.create_index(
        "ix_manual_work_entries_special_activity_id",
        "manual_work_entries",
        ["special_activity_id"],
    )
    op.create_index(
        "ix_manual_work_entries_work_date",
        "manual_work_entries",
        ["work_date"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_manual_work_entries_work_date",
        table_name="manual_work_entries",
    )
    op.drop_index(
        "ix_manual_work_entries_special_activity_id",
        table_name="manual_work_entries",
    )
    op.drop_index(
        "ix_manual_work_entries_focus_area_id",
        table_name="manual_work_entries",
    )
    op.drop_table("manual_work_entries")
    op.drop_table("special_activities")
