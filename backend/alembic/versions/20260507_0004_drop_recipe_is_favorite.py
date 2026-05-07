"""Drop is_favorite column from recipe table

``is_favorite`` is now stored exclusively in ``recipeaccountmetadata``
per account.  This migration removes the stale column from the ``recipe``
table so it cannot be accidentally written or read.

Revision ID: 20260507_0004
Revises: 20260507_0003
Create Date: 2026-05-07 11:00:00

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "20260507_0004"
down_revision: Union[str, None] = "20260507_0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_column("recipe", "is_favorite")


def downgrade() -> None:
    # Re-add the column as NOT NULL with default False so existing rows keep a
    # sensible value.  Favorites will no longer be reflected here after a
    # downgrade, but the column shape is at least schema-compatible again.
    op.add_column(
        "recipe",
        sa.Column(
            "is_favorite",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
        ),
    )
