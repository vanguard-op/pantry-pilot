"""Add settings fields required for mobile API sync

Revision ID: 20260506_0002
Revises: 20260506_0001
Create Date: 2026-05-06 00:30:00

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260506_0002"
down_revision: Union[str, None] = "20260506_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "settingsmodel",
        sa.Column(
            "onboarding_complete",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "settingsmodel",
        sa.Column("first_plan_created_at", sa.DateTime(), nullable=True),
    )
    op.add_column(
        "settingsmodel",
        sa.Column("cooking_session_dates", sa.JSON(), nullable=True),
    )
    op.execute(
        "UPDATE settingsmodel SET cooking_session_dates = '[]'::json WHERE cooking_session_dates IS NULL"
    )
    op.alter_column("settingsmodel", "cooking_session_dates", nullable=False)


def downgrade() -> None:
    op.drop_column("settingsmodel", "cooking_session_dates")
    op.drop_column("settingsmodel", "first_plan_created_at")
    op.drop_column("settingsmodel", "onboarding_complete")