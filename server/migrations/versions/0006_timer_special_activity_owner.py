"""Allow a timer execution to belong to a Special Activity.

Revision ID: 0006
Revises: 0005
"""

from alembic import op
import sqlalchemy as sa

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("timer_executions", "focus_area_id", nullable=True)
    op.add_column(
        "timer_executions",
        sa.Column("special_activity_id", sa.BigInteger(), nullable=True),
    )
    op.create_foreign_key(
        "fk_timer_executions_special_activity_id",
        "timer_executions",
        "special_activities",
        ["special_activity_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_index(
        "ix_timer_executions_special_activity_id",
        "timer_executions",
        ["special_activity_id"],
    )
    op.create_check_constraint(
        "ck_timer_executions_exactly_one_owner",
        "timer_executions",
        "(focus_area_id IS NOT NULL) <> (special_activity_id IS NOT NULL)",
    )


def downgrade() -> None:
    op.execute(
        "DO $$ BEGIN IF EXISTS (SELECT 1 FROM timer_executions "
        "WHERE special_activity_id IS NOT NULL) THEN "
        "RAISE EXCEPTION 'Cannot downgrade with Special Activity timer executions'; "
        "END IF; END $$"
    )
    op.drop_constraint("ck_timer_executions_exactly_one_owner", "timer_executions")
    op.drop_index("ix_timer_executions_special_activity_id", "timer_executions")
    op.drop_constraint(
        "fk_timer_executions_special_activity_id", "timer_executions", type_="foreignkey"
    )
    op.drop_column("timer_executions", "special_activity_id")
    op.alter_column("timer_executions", "focus_area_id", nullable=False)
