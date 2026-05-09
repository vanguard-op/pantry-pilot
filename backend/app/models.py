from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from typing import Any, Dict, List, Optional
from typing_extensions import TypedDict
from uuid import uuid4

from sqlalchemy import JSON, Column
from sqlmodel import Field, SQLModel


class Difficulty(str, Enum):
    beginner = "Beginner"
    intermediate = "Intermediate"
    confident = "Confident"


class FeedbackCategory(str, Enum):
    bug = "bug"
    suggestion = "suggestion"
    other = "other"


class FeedbackStatus(str, Enum):
    open = "open"
    in_review = "in_review"
    resolved = "resolved"


class PantryItemKind(str, Enum):
    ingredient = "ingredient"
    cooked_meal = "cooked_meal"


class PantryItemBase(SQLModel):
    name: str
    quantity: float = Field(gt=0)
    unit: str = "pcs"
    storage_location: str = "Pantry"
    item_kind: PantryItemKind = PantryItemKind.ingredient
    expiry_date: Optional[date] = None
    low_stock_threshold: float = Field(default=1, ge=0)


class PantryItem(PantryItemBase, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    user_id: str = Field(index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class PantryItemCreate(PantryItemBase):
    pass


class PantryItemUpdate(SQLModel):
    name: Optional[str] = None
    quantity: Optional[float] = Field(default=None, gt=0)
    unit: Optional[str] = None
    storage_location: Optional[str] = None
    item_kind: Optional[PantryItemKind] = None
    expiry_date: Optional[date] = None
    low_stock_threshold: Optional[float] = Field(default=None, ge=0)


class RecipeOwnershipScope(str, Enum):
    starter_catalog = "starter"
    plus_catalog = "plus"
    custom_account = "custom"


class RecipeStep(TypedDict):
    description: str
    duration_minutes: int
    ingredient_mentions: List[str]


class RecipeBase(SQLModel):
    title: str
    description: str
    prep_minutes: int = Field(default=0, ge=0)
    cook_minutes: int = Field(default=0, ge=0)
    servings: int = Field(default=1, ge=1)
    difficulty: Difficulty = Difficulty.beginner
    tags: List[str] = Field(default_factory=list, sa_column=Column(JSON))
    ingredients: List[str] = Field(default_factory=list, sa_column=Column(JSON))
    steps: List[RecipeStep] = Field(default_factory=list, sa_column=Column(JSON))


class Recipe(RecipeBase, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    user_id: Optional[str] = Field(default=None, index=True)
    ownership_scope: RecipeOwnershipScope = Field(default=RecipeOwnershipScope.custom_account)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class RecipeCreate(RecipeBase):
    pass


class RecipeUpdate(SQLModel):
    title: Optional[str] = None
    description: Optional[str] = None
    prep_minutes: Optional[int] = Field(default=None, ge=0)
    cook_minutes: Optional[int] = Field(default=None, ge=0)
    servings: Optional[int] = Field(default=None, ge=1)
    difficulty: Optional[Difficulty] = None
    tags: Optional[List[str]] = None
    ingredients: Optional[List[str]] = None
    steps: Optional[List[RecipeStep]] = None


class RecipePublic(SQLModel):
    """API response schema for a recipe with per-account metadata overlaid.

    Distinct from the ``Recipe`` table model so that ``is_favorite`` is never
    persisted on the recipe row itself — it is always derived from
    ``RecipeAccountMetadata`` for the requesting account.
    """

    id: str
    title: str
    description: str
    prep_minutes: int
    cook_minutes: int
    servings: int
    difficulty: Difficulty
    tags: List[str]
    ingredients: List[str]
    steps: List[RecipeStep]
    ownership_scope: RecipeOwnershipScope
    is_favorite: bool
    created_at: datetime
    updated_at: datetime


class RecipeAccountMetadata(SQLModel, table=True):
    user_id: str = Field(primary_key=True)
    recipe_id: str = Field(primary_key=True)
    is_favorite: bool = False
    rating: Optional[int] = Field(default=None, ge=1, le=5)
    last_cooked_at: Optional[datetime] = None
    usage_count: int = Field(default=0, ge=0)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class PlannedMealBase(SQLModel):
    recipe_id: str
    date: date
    slot: str


class PlannedMeal(PlannedMealBase, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    user_id: str = Field(index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class PlannedMealCreate(PlannedMealBase):
    pass


class PlannedMealUpdate(SQLModel):
    recipe_id: Optional[str] = None
    date: Optional[date] = None
    slot: Optional[str] = None


class BoughtItem(SQLModel):
    name: str
    quantity: float = Field(gt=0)


class ShoppingListItem(SQLModel):
    name: str
    needed_for_meals: int


class ShoppingListResponse(SQLModel):
    items: List[ShoppingListItem]


class RecipeRecommendation(SQLModel):
    recipe: RecipePublic
    score: int
    pantry_coverage: int
    matching_ingredients: List[str]
    use_soon_ingredients: List[str]
    recent_plan_count: int


class LeftoverSuggestion(SQLModel):
    recipe: RecipePublic
    source_recipe_title: str
    shared_ingredients: List[str]
    reason: str


class PlannerRecommendationsResponse(SQLModel):
    ranked: List[RecipeRecommendation]
    favorites: List[RecipePublic]
    repeats: List[RecipePublic]


class DashboardRecommendationsResponse(SQLModel):
    use_soon: List[RecipeRecommendation]
    leftovers: List[LeftoverSuggestion]


class SettingsModel(SQLModel, table=True):
    user_id: str = Field(primary_key=True)
    household_size: int = Field(default=1, ge=1, le=12)
    skill_level: Difficulty = Difficulty.beginner
    dietary_notes: str = ""
    onboarding_complete: bool = False
    first_plan_created_at: Optional[datetime] = None
    cooking_session_dates: List[str] = Field(default_factory=list, sa_column=Column(JSON))
    expiry_threshold_days: int = Field(default=3, ge=1, le=30)
    expiry_notifications_enabled: bool = True
    meal_reminder_notifications_enabled: bool = True
    pantry_auto_deduct_enabled: bool = True
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class SettingsUpdate(SQLModel):
    household_size: Optional[int] = Field(default=None, ge=1, le=12)
    skill_level: Optional[Difficulty] = None
    dietary_notes: Optional[str] = None
    onboarding_complete: Optional[bool] = None
    first_plan_created_at: Optional[datetime] = None
    cooking_session_dates: Optional[List[str]] = None
    expiry_threshold_days: Optional[int] = Field(default=None, ge=1, le=30)
    expiry_notifications_enabled: Optional[bool] = None
    meal_reminder_notifications_enabled: Optional[bool] = None
    pantry_auto_deduct_enabled: Optional[bool] = None


class FeedbackEntryBase(SQLModel):
    message: str
    category: FeedbackCategory = FeedbackCategory.other


class FeedbackEntry(FeedbackEntryBase, table=True):
    id: str = Field(default_factory=lambda: str(uuid4()), primary_key=True)
    user_id: str = Field(index=True)
    status: FeedbackStatus = FeedbackStatus.open
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class FeedbackEntryCreate(FeedbackEntryBase):
    pass


class FeedbackEntryUpdate(SQLModel):
    status: FeedbackStatus


class KpiSummary(SQLModel):
    has_created_first_plan: bool
    planned_meals_last_7_days: int
    cooking_sessions_last_7_days: int
    pantry_use_soon_ratio: float


class PantrySubstituteOption(SQLModel):
    """A pantry item that can serve as a substitute for a missing ingredient."""

    pantry_item_name: str
    reason: str


class SubstitutionHint(SQLModel):
    ingredient: str
    hint: str
    pantry_substitutes: List["PantrySubstituteOption"] = []


class SubstitutionHintsResponse(SQLModel):
    hints: List[SubstitutionHint]


class PantryCoverageResponse(SQLModel):
    """Pantry coverage summary for a single recipe."""

    recipe_id: str
    coverage_percent: int
    matched_count: int
    total_count: int
    missing_ingredients: List[str]
    available_ingredients: List[str]
