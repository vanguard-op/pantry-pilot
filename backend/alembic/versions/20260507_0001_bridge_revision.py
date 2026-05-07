"""Bridge revision kept for migration chain compatibility.

Revision ID: 20260507_0001
Revises: 20260506_0001
Create Date: 2026-05-07 00:10:00

This revision intentionally performs no schema changes. It preserves
compatibility for environments that previously recorded this revision id.
"""

from typing import Sequence, Union


# revision identifiers, used by Alembic.
revision: str = "20260507_0001"
down_revision: Union[str, None] = "20260506_0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
