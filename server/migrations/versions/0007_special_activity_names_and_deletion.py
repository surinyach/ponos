"""Make names unique and retire Special Activity archiving.

Revision ID: 0007
Revises: 0006
"""

from alembic import op
import sqlalchemy as sa

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_index(
        "uq_special_activities_name_ci",
        "special_activities",
        [sa.text("lower(btrim(name))")],
        unique=True,
    )
    op.drop_column("special_activities", "is_archived")


def downgrade() -> None:
    op.add_column(
        "special_activities",
        sa.Column("is_archived", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.drop_index("uq_special_activities_name_ci", "special_activities")
