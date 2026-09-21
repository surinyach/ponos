"""Remove date from reusable Special Activities.

Revision ID: 0005
Revises: 0004
"""

from alembic import op
import sqlalchemy as sa

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_column("special_activities", "work_date")


def downgrade() -> None:
    op.add_column("special_activities", sa.Column("work_date", sa.Date(), nullable=True))
    op.execute(
        "UPDATE special_activities SET work_date = CURRENT_DATE "
        "WHERE work_date IS NULL"
    )
    op.alter_column("special_activities", "work_date", nullable=False)
