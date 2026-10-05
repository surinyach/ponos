"""Add historically versioned daily and weekly work goals.

Revision ID: 0008
Revises: 0007
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ExcludeConstraint

revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "daily_work_goals",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("weekday", sa.SmallInteger(), nullable=False),
        sa.Column("target_minutes", sa.Integer(), nullable=False),
        sa.Column("valid_from", sa.Date(), nullable=False),
        sa.Column("valid_until", sa.Date(), nullable=True),
        sa.CheckConstraint("weekday BETWEEN 1 AND 7", name="ck_daily_work_goals_weekday"),
        sa.CheckConstraint("target_minutes >= 0", name="ck_daily_work_goals_minutes"),
        sa.CheckConstraint(
            "valid_until IS NULL OR valid_until >= valid_from",
            name="ck_daily_work_goals_valid_period",
        ),
        ExcludeConstraint(
            ("weekday", "="),
            (sa.text("daterange(valid_from, valid_until, '[]')"), "&&"),
            using="gist",
            name="excl_daily_work_goals_no_overlap",
        ),
    )
    op.create_table(
        "weekly_work_goals",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("target_minutes", sa.Integer(), nullable=False),
        sa.Column("valid_from", sa.Date(), nullable=False),
        sa.Column("valid_until", sa.Date(), nullable=True),
        sa.CheckConstraint("target_minutes >= 0", name="ck_weekly_work_goals_minutes"),
        sa.CheckConstraint(
            "valid_until IS NULL OR valid_until >= valid_from",
            name="ck_weekly_work_goals_valid_period",
        ),
        ExcludeConstraint(
            (sa.text("daterange(valid_from, valid_until, '[]')"), "&&"),
            using="gist",
            name="excl_weekly_work_goals_no_overlap",
        ),
    )


def downgrade() -> None:
    op.drop_table("weekly_work_goals")
    op.drop_table("daily_work_goals")
