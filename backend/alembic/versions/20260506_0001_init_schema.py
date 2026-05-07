"""Initial PantryPilot schema

Revision ID: 20260506_0001
Revises:
Create Date: 2026-05-06 00:00:00

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260506_0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # SQLAlchemy persists Enum member names by default (beginner/intermediate/confident).
    # Keep migration enum values aligned so inserts from ORM models succeed.
    difficulty_enum = sa.Enum("beginner", "intermediate", "confident", name="difficulty")
    feedback_category_enum = sa.Enum("bug", "suggestion", "other", name="feedbackcategory")
    feedback_status_enum = sa.Enum("open", "in_review", "resolved", name="feedbackstatus")

    op.create_table(
        "pantryitem",
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("quantity", sa.Float(), nullable=False),
        sa.Column("unit", sa.String(), nullable=False),
        sa.Column("storage_location", sa.String(), nullable=False),
        sa.Column("expiry_date", sa.Date(), nullable=True),
        sa.Column("low_stock_threshold", sa.Float(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_pantryitem_user_id"), "pantryitem", ["user_id"], unique=False)

    op.create_table(
        "recipe",
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("description", sa.String(), nullable=False),
        sa.Column("prep_minutes", sa.Integer(), nullable=False),
        sa.Column("cook_minutes", sa.Integer(), nullable=False),
        sa.Column("servings", sa.Integer(), nullable=False),
        sa.Column("difficulty", difficulty_enum, nullable=False),
        sa.Column("tags", sa.JSON(), nullable=True),
        sa.Column("ingredients", sa.JSON(), nullable=True),
        sa.Column("steps", sa.JSON(), nullable=True),
        sa.Column(
            "ownership_scope",
            sa.String(length=16),
            nullable=False,
            server_default="custom",
        ),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_recipe_user_id"), "recipe", ["user_id"], unique=False)

    op.create_table(
        "recipeaccountmetadata",
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("recipe_id", sa.String(), nullable=False),
        sa.Column("is_favorite", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("rating", sa.Integer(), nullable=True),
        sa.Column("last_cooked_at", sa.DateTime(), nullable=True),
        sa.Column("usage_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "rating IS NULL OR (rating >= 1 AND rating <= 5)",
            name="ck_recipe_metadata_rating",
        ),
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

    op.create_table(
        "plannedmeal",
        sa.Column("recipe_id", sa.String(), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("slot", sa.String(), nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_plannedmeal_user_id"), "plannedmeal", ["user_id"], unique=False)

    op.create_table(
        "settingsmodel",
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("household_size", sa.Integer(), nullable=False),
        sa.Column("skill_level", difficulty_enum, nullable=False),
        sa.Column("dietary_notes", sa.String(), nullable=False),
        sa.Column("onboarding_complete", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("first_plan_created_at", sa.DateTime(), nullable=True),
        sa.Column("cooking_session_dates", sa.JSON(), nullable=False),
        sa.Column("expiry_threshold_days", sa.Integer(), nullable=False),
        sa.Column("expiry_notifications_enabled", sa.Boolean(), nullable=False),
        sa.Column("meal_reminder_notifications_enabled", sa.Boolean(), nullable=False),
        sa.Column("pantry_auto_deduct_enabled", sa.Boolean(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("user_id"),
    )

    op.create_table(
        "feedbackentry",
        sa.Column("message", sa.String(), nullable=False),
        sa.Column("category", feedback_category_enum, nullable=False),
        sa.Column("id", sa.String(), nullable=False),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("status", feedback_status_enum, nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_feedbackentry_user_id"), "feedbackentry", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_feedbackentry_user_id"), table_name="feedbackentry")
    op.drop_table("feedbackentry")

    op.drop_table("settingsmodel")

    op.drop_index(op.f("ix_plannedmeal_user_id"), table_name="plannedmeal")
    op.drop_table("plannedmeal")

    op.drop_index(op.f("ix_recipeaccountmetadata_recipe_id"), table_name="recipeaccountmetadata")
    op.drop_table("recipeaccountmetadata")

    op.drop_index(op.f("ix_recipe_user_id"), table_name="recipe")
    op.drop_table("recipe")

    op.drop_index(op.f("ix_pantryitem_user_id"), table_name="pantryitem")
    op.drop_table("pantryitem")
