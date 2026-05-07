"""Introduce hybrid recipe ownership and account metadata

Revision ID: 20260507_0003
Revises: 20260506_0002
Create Date: 2026-05-07 10:00:00

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260507_0003"
down_revision: Union[str, None] = "20260506_0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "recipe",
        sa.Column(
            "ownership_scope",
            sa.String(length=16),
            nullable=False,
            server_default="custom",
        ),
    )
    op.alter_column("recipe", "user_id", existing_type=sa.String(), nullable=True)

    op.create_table(
        "recipeaccountmetadata",
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("recipe_id", sa.String(), nullable=False),
        sa.Column("is_favorite", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("rating", sa.Integer(), nullable=True),
        sa.Column("last_cooked_at", sa.DateTime(), nullable=True),
        sa.Column("usage_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint("rating IS NULL OR (rating >= 1 AND rating <= 5)", name="ck_recipe_metadata_rating"),
        sa.CheckConstraint("usage_count >= 0", name="ck_recipe_metadata_usage_count"),
        sa.ForeignKeyConstraint(["recipe_id"], ["recipe.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id", "recipe_id"),
    )
    op.create_index(
        op.f("ix_recipeaccountmetadata_recipe_id"),
        "recipeaccountmetadata",
        ["recipe_id"],
        unique=False,
    )

    op.execute("UPDATE recipe SET ownership_scope = 'custom' WHERE ownership_scope IS NULL")
    op.execute(
        "UPDATE recipe SET ownership_scope = 'global', user_id = NULL, is_favorite = false WHERE user_id = 'mobile-user-1'"
    )


def downgrade() -> None:
    op.execute("UPDATE recipe SET user_id = 'mobile-user-1' WHERE user_id IS NULL")
    op.execute("UPDATE recipe SET ownership_scope = 'custom'")

    op.drop_index(op.f("ix_recipeaccountmetadata_recipe_id"), table_name="recipeaccountmetadata")
    op.drop_table("recipeaccountmetadata")

    op.alter_column("recipe", "user_id", existing_type=sa.String(), nullable=False)
    op.drop_column("recipe", "ownership_scope")
