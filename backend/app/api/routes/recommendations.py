from datetime import date, timedelta

from fastapi import APIRouter
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import (
    DashboardRecommendationsResponse,
    LeftoverSuggestion,
    PantryItem,
    PlannedMeal,
    PlannerRecommendationsResponse,
    Recipe,
    RecipeRecommendation,
)

router = APIRouter(prefix="/recommendations", tags=["recommendations"])


@router.get("/planner", response_model=PlannerRecommendationsResponse)
def planner_recommendations(
    session: SessionDep,
    user_id: UserIdDep,
) -> PlannerRecommendationsResponse:
    recipes = _list_recipes(session, user_id)
    pantry_items = _list_pantry_items(session, user_id)
    planned_meals = _list_planned_meals(session, user_id)

    ranked = _rank_recipes(
        recipes=recipes,
        pantry_items=pantry_items,
        planned_meals=planned_meals,
    )

    favorites = [item.recipe for item in ranked if item.recipe.is_favorite][:4]
    repeats = _repeat_recipes(recipes=recipes, planned_meals=planned_meals)

    return PlannerRecommendationsResponse(
        ranked=ranked,
        favorites=favorites,
        repeats=repeats,
    )


@router.get("/dashboard", response_model=DashboardRecommendationsResponse)
def dashboard_recommendations(
    session: SessionDep,
    user_id: UserIdDep,
) -> DashboardRecommendationsResponse:
    recipes = _list_recipes(session, user_id)
    pantry_items = _list_pantry_items(session, user_id)
    planned_meals = _list_planned_meals(session, user_id)

    ranked = _rank_recipes(
        recipes=recipes,
        pantry_items=pantry_items,
        planned_meals=planned_meals,
    )
    use_soon = [item for item in ranked if item.use_soon_ingredients][:4]

    leftovers = _leftover_suggestions(recipes=recipes, planned_meals=planned_meals)
    return DashboardRecommendationsResponse(use_soon=use_soon, leftovers=leftovers)


def _list_recipes(session: SessionDep, user_id: str) -> list[Recipe]:
    return list(session.exec(select(Recipe).where(Recipe.user_id == user_id)).all())


def _list_pantry_items(session: SessionDep, user_id: str) -> list[PantryItem]:
    return list(session.exec(select(PantryItem).where(PantryItem.user_id == user_id)).all())


def _list_planned_meals(session: SessionDep, user_id: str) -> list[PlannedMeal]:
    return list(session.exec(select(PlannedMeal).where(PlannedMeal.user_id == user_id)).all())


def _rank_recipes(
    recipes: list[Recipe],
    pantry_items: list[PantryItem],
    planned_meals: list[PlannedMeal],
) -> list[RecipeRecommendation]:
    pantry_set = {item.name.lower() for item in pantry_items}
    use_soon_set = {
        item.name.lower()
        for item in pantry_items
        if item.expiry_date is not None and (item.expiry_date - date.today()).days <= 3
    }
    recent_counts = _recent_plan_counts(planned_meals)

    ranked: list[RecipeRecommendation] = []
    for recipe in recipes:
        matching = [
            ingredient
            for ingredient in recipe.ingredients
            if ingredient.lower() in pantry_set
        ]
        use_soon_matches = [
            ingredient
            for ingredient in recipe.ingredients
            if ingredient.lower() in use_soon_set
        ]

        coverage = (
            round((len(matching) / len(recipe.ingredients)) * 100)
            if recipe.ingredients
            else 0
        )
        recent_plan_count = recent_counts.get(recipe.id, 0)
        score = (
            (coverage * 2)
            + (len(use_soon_matches) * 18)
            + (14 if recipe.is_favorite else 0)
            + (recent_plan_count * 6)
        )

        ranked.append(
            RecipeRecommendation(
                recipe=recipe,
                score=score,
                pantry_coverage=coverage,
                matching_ingredients=matching,
                use_soon_ingredients=use_soon_matches,
                recent_plan_count=recent_plan_count,
            )
        )

    ranked.sort(key=lambda item: item.score, reverse=True)
    return ranked


def _repeat_recipes(recipes: list[Recipe], planned_meals: list[PlannedMeal]) -> list[Recipe]:
    recent_counts = _recent_plan_counts(planned_meals)
    repeated = [recipe for recipe in recipes if recent_counts.get(recipe.id, 0) > 0]
    repeated.sort(key=lambda recipe: recent_counts.get(recipe.id, 0), reverse=True)
    return repeated[:4]


def _leftover_suggestions(
    recipes: list[Recipe],
    planned_meals: list[PlannedMeal],
) -> list[LeftoverSuggestion]:
    recipe_by_id = {recipe.id: recipe for recipe in recipes}
    recent_cutoff = date.today() - timedelta(days=3)
    recent_meals = [meal for meal in planned_meals if meal.date >= recent_cutoff]
    recent_meals.sort(key=lambda meal: meal.date, reverse=True)

    suggestions: list[LeftoverSuggestion] = []
    used_recipe_ids: set[str] = set()

    for meal in recent_meals:
        source = recipe_by_id.get(meal.recipe_id)
        if source is None:
            continue

        best_match: Recipe | None = None
        shared: list[str] = []

        source_ingredients = {ingredient.lower() for ingredient in source.ingredients}
        for candidate in recipes:
            if candidate.id == source.id or candidate.id in used_recipe_ids:
                continue

            overlap = [
                ingredient
                for ingredient in candidate.ingredients
                if ingredient.lower() in source_ingredients
            ]
            if len(overlap) > len(shared):
                best_match = candidate
                shared = overlap

        if best_match is None or not shared:
            continue

        used_recipe_ids.add(best_match.id)
        shared_preview = ", ".join(shared[:2])
        reason_suffix = f" with {shared_preview}" if shared_preview else ""
        suggestions.append(
            LeftoverSuggestion(
                recipe=best_match,
                source_recipe_title=source.title,
                shared_ingredients=shared,
                reason=f"Reuse ingredients from {source.title}{reason_suffix}",
            )
        )

        if len(suggestions) == 3:
            break

    return suggestions


def _recent_plan_counts(planned_meals: list[PlannedMeal]) -> dict[str, int]:
    cutoff = date.today() - timedelta(days=14)
    counts: dict[str, int] = {}
    for meal in planned_meals:
        if meal.date < cutoff:
            continue
        counts[meal.recipe_id] = counts.get(meal.recipe_id, 0) + 1
    return counts
