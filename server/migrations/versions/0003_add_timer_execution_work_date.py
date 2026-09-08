"""Add immutable local work date to timer executions.

Revision ID: 0003
Revises: 0002
Create Date: 2026-09-08
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "timer_executions",
        sa.Column("work_date", sa.Date(), nullable=True),
    )
    # Pre-timer-feature rows have no captured local date. UTC provides a
    # deterministic compatibility fallback; new rows must supply work_date.
    op.execute(
        "UPDATE timer_executions "
        "SET work_date = timezone('UTC', started_at)::date "
        "WHERE work_date IS NULL"
    )
    op.alter_column("timer_executions", "work_date", nullable=False)
    op.create_index(
        "ix_timer_executions_work_date",
        "timer_executions",
        ["work_date"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_timer_executions_work_date",
        table_name="timer_executions",
    )
    op.drop_column("timer_executions", "work_date")
