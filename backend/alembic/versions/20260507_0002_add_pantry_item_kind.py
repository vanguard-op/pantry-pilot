"""Add pantry item kind

Revision ID: 20260507_0002
Revises: 20260506_0001
Create Date: 2026-05-07 00:20:00

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260507_0002"
down_revision: Union[str, None] = "20260507_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "pantryitem",
        sa.Column(
            "item_kind",
            sa.String(length=16),
            nullable=False,
            server_default="ingredient",
        ),
    )


def downgrade() -> None:
    op.drop_column("pantryitem", "item_kind")
