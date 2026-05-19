from __future__ import annotations

import json
from datetime import date, datetime, timedelta

from fastapi import HTTPException, status
from google import genai
from google.genai import types
from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.core.config import Settings, get_settings
from app.models import (
    AICoverageIngredient,
    AICoverageStatus,
    AIPantryCoveragePayload,
    AIShoppingGapItem,
    AIShoppingGapsPayload,
    PantryItem,
    PlannedMeal,
    Recipe,
    RecipeOwnershipScope,
)


class AIPlanningService:
    """Generates structured pantry coverage and shopping gaps via Gemini.

    Uses Google AI Studio (Gemini models) and expects strict JSON output.
    """

    def __init__(self, session: SessionDep, user_id: UserIdDep) -> None:
        self._session = session
        self._user_id = user_id
        self._settings: Settings = get_settings()

    def generate_recipe_coverage_payload(self, recipe_id: str) -> AIPantryCoveragePayload:
        recipe = self._require_accessible_recipe(recipe_id)
        pantry_items = self._list_pantry_items()

        prompt_context = {
            "recipe": {
                "id": recipe.id,
                "title": recipe.title,
                "ingredients": recipe.ingredients,
            },
            "pantry_items": [
                {
                    "name": item.name,
                    "quantity": item.quantity,
                    "unit": item.unit,
                }
                for item in pantry_items
            ],
            "rules": {
                "statuses": [status.value for status in AICoverageStatus],
                "units_allowed": [
                    "pcs",
                    "g",
                    "kg",
                    "ml",
                    "l",
                    "tsp",
                    "tbsp",
                    "cup",
                    "serving",
                ],
            },
        }

        if not self._is_ai_enabled:
            return self._deterministic_coverage_payload(recipe.id, recipe.ingredients, pantry_items)

        response_json = self._call_gemini(
            instruction=(
                "Return a JSON object that maps recipe ingredients to pantry coverage. "
                "Follow the schema exactly and include summary counts."
            ),
            context=prompt_context,
            output_schema=self._coverage_output_schema(),
        )

        payload = AIPantryCoveragePayload.model_validate(response_json)
        if payload.recipe_id != recipe.id:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="AI payload recipe_id mismatch.",
            )
        return payload

    def generate_shopping_gaps_payload(self, days: int = 7) -> AIShoppingGapsPayload:
        window_days = max(1, days)
        today = date.today()
        end_date = today + timedelta(days=window_days - 1)

        meals = self._list_planned_meals(today, end_date)
        pantry_items = self._list_pantry_items()
        recipes = self._list_accessible_recipes()
        recipe_by_id = {recipe.id: recipe for recipe in recipes}

        prompt_context = {
            "start_date": today.isoformat(),
            "end_date": end_date.isoformat(),
            "planned_meals": [
                {
                    "id": meal.id,
                    "recipe_id": meal.recipe_id,
                    "date": meal.date.isoformat(),
                    "slot": meal.slot,
                }
                for meal in meals
            ],
            "recipes": [
                {
                    "id": recipe.id,
                    "title": recipe.title,
                    "ingredients": recipe.ingredients,
                }
                for recipe in recipes
            ],
            "pantry_items": [
                {
                    "name": item.name,
                    "quantity": item.quantity,
                    "unit": item.unit,
                }
                for item in pantry_items
            ],
            "rules": {
                "units_allowed": [
                    "pcs",
                    "g",
                    "kg",
                    "ml",
                    "l",
                    "tsp",
                    "tbsp",
                    "cup",
                    "serving",
                ],
                "note": "normalize names to lowercase singular where possible",
            },
        }

        if not self._is_ai_enabled:
            return self._deterministic_shopping_payload(today, end_date, meals, recipe_by_id, pantry_items)

        response_json = self._call_gemini(
            instruction=(
                "Return a JSON object with normalized shopping gap items and suggested quantities "
                "for the plan window. Follow the schema exactly."
            ),
            context=prompt_context,
            output_schema=self._shopping_output_schema(),
        )

        payload = AIShoppingGapsPayload.model_validate(response_json)
        if payload.start_date != today or payload.end_date != end_date:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="AI payload date window mismatch.",
            )
        return payload

    @property
    def _is_ai_enabled(self) -> bool:
        return bool(
            self._settings.gemini_api_key.strip() and self._settings.gemini_model.strip()
        )

    def _call_gemini(self, *, instruction: str, context: dict, output_schema: dict) -> dict:
        if not self._is_ai_enabled:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Gemini is not configured. Set GEMINI_API_KEY and GEMINI_MODEL.",
            )

        contents = (
            instruction
            + "\n\n"
            + "Context JSON:\n"
            + json.dumps(context, ensure_ascii=True)
            + "\n\n"
            + "Output schema JSON:\n"
            + json.dumps(output_schema, ensure_ascii=True)
        )

        client = genai.Client(api_key=self._settings.gemini_api_key)
        last_error: Exception | None = None

        for model_name in self._models_to_try():
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=contents,
                    config=types.GenerateContentConfig(
                        temperature=0.1,
                        response_mime_type="application/json",
                    ),
                )
            except Exception as exc:  # SDK raises typed runtime errors per transport.
                last_error = exc
                if "404" in str(exc):
                    continue
                break

            text = (response.text or "").strip()
            if not text:
                last_error = RuntimeError("Gemini returned empty content.")
                continue

            try:
                parsed = json.loads(text)
            except json.JSONDecodeError as exc:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="Gemini returned malformed JSON content.",
                ) from exc

            if not isinstance(parsed, dict):
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="Gemini JSON payload must be an object.",
                )
            return parsed

        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=(
                "Gemini request failed for all attempted models "
                f"{self._models_to_try()}: {last_error}"
            ),
        )

    def _models_to_try(self) -> list[str]:
        configured = self._settings.gemini_model.strip()
        fallbacks = ["gemini-2.0-flash", "gemini-2.0-flash-lite", "gemini-1.5-flash"]
        ordered = [configured, *fallbacks]

        unique_models: list[str] = []
        for model in ordered:
            if model and model not in unique_models:
                unique_models.append(model)
        return unique_models

    def _deterministic_coverage_payload(
        self,
        recipe_id: str,
        ingredients: list[str],
        pantry_items: list[PantryItem],
    ) -> AIPantryCoveragePayload:
        pantry_names = {item.name.strip().lower() for item in pantry_items}
        ai_ingredients: list[AICoverageIngredient] = []

        for raw in ingredients:
            normalized = raw.strip().lower()
            is_available = normalized in pantry_names
            ai_ingredients.append(
                AICoverageIngredient(
                    ingredient_text=raw,
                    normalized_name=normalized,
                    required_quantity=1,
                    required_unit="pcs",
                    available_quantity=1 if is_available else 0,
                    missing_quantity=0 if is_available else 1,
                    status=AICoverageStatus.available if is_available else AICoverageStatus.missing,
                    matched_pantry_item=raw if is_available else None,
                    substitution=None,
                    confidence=0.6,
                )
            )

        matched = sum(1 for item in ai_ingredients if item.status == AICoverageStatus.available)
        missing = sum(1 for item in ai_ingredients if item.status == AICoverageStatus.missing)
        substituted = sum(1 for item in ai_ingredients if item.status == AICoverageStatus.substituted)
        coverage = round(((matched + substituted) / len(ai_ingredients)) * 100) if ai_ingredients else 0

        return AIPantryCoveragePayload(
            recipe_id=recipe_id,
            model="deterministic-fallback",
            generated_at=datetime.utcnow(),
            ingredients=ai_ingredients,
            matched_count=matched,
            missing_count=missing,
            substituted_count=substituted,
            coverage_percent=coverage,
            notes="Fallback payload used because Gemini config is missing.",
        )

    def _deterministic_shopping_payload(
        self,
        start_date: date,
        end_date: date,
        meals: list[PlannedMeal],
        recipe_by_id: dict[str, Recipe],
        pantry_items: list[PantryItem],
    ) -> AIShoppingGapsPayload:
        pantry_names = {item.name.strip().lower() for item in pantry_items}
        missing_counts: dict[str, int] = {}

        for meal in meals:
            recipe = recipe_by_id.get(meal.recipe_id)
            if not recipe:
                continue
            for ingredient in recipe.ingredients:
                normalized = ingredient.strip().lower()
                if not normalized or normalized in pantry_names:
                    continue
                missing_counts[normalized] = missing_counts.get(normalized, 0) + 1

        items = [
            AIShoppingGapItem(
                ingredient_text=name,
                normalized_name=name,
                suggested_quantity=float(count),
                suggested_unit="pcs",
                reason="Derived from deterministic fallback gap counts.",
                confidence=0.6,
            )
            for name, count in sorted(missing_counts.items())
        ]

        return AIShoppingGapsPayload(
            start_date=start_date,
            end_date=end_date,
            model="deterministic-fallback",
            generated_at=datetime.utcnow(),
            items=items,
            notes="Fallback payload used because Gemini config is missing.",
        )

    def _coverage_output_schema(self) -> dict:
        return {
            "type": "object",
            "required": [
                "recipe_id",
                "model",
                "generated_at",
                "ingredients",
                "matched_count",
                "missing_count",
                "substituted_count",
                "coverage_percent",
            ],
            "properties": {
                "recipe_id": {"type": "string"},
                "model": {"type": "string"},
                "generated_at": {"type": "string", "format": "date-time"},
                "ingredients": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "required": [
                            "ingredient_text",
                            "normalized_name",
                            "required_quantity",
                            "required_unit",
                            "available_quantity",
                            "missing_quantity",
                            "status",
                            "confidence",
                        ],
                    },
                },
                "matched_count": {"type": "integer"},
                "missing_count": {"type": "integer"},
                "substituted_count": {"type": "integer"},
                "coverage_percent": {"type": "integer"},
                "notes": {"type": "string"},
            },
        }

    def _shopping_output_schema(self) -> dict:
        return {
            "type": "object",
            "required": [
                "start_date",
                "end_date",
                "model",
                "generated_at",
                "items",
            ],
            "properties": {
                "start_date": {"type": "string", "format": "date"},
                "end_date": {"type": "string", "format": "date"},
                "model": {"type": "string"},
                "generated_at": {"type": "string", "format": "date-time"},
                "items": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "required": [
                            "ingredient_text",
                            "normalized_name",
                            "suggested_quantity",
                            "suggested_unit",
                            "confidence",
                        ],
                    },
                },
                "notes": {"type": "string"},
            },
        }

    def _list_pantry_items(self) -> list[PantryItem]:
        statement = select(PantryItem).where(PantryItem.user_id == self._user_id)
        return list(self._session.exec(statement).all())

    def _list_planned_meals(self, start_date: date, end_date: date) -> list[PlannedMeal]:
        statement = select(PlannedMeal).where(
            PlannedMeal.user_id == self._user_id,
            PlannedMeal.date >= start_date,
            PlannedMeal.date <= end_date,
        )
        return list(self._session.exec(statement).all())

    def _list_accessible_recipes(self) -> list[Recipe]:
        statement = select(Recipe).where(
            (Recipe.ownership_scope == RecipeOwnershipScope.starter_catalog)
            | (Recipe.ownership_scope == RecipeOwnershipScope.plus_catalog)
            | (
                (Recipe.ownership_scope == RecipeOwnershipScope.custom_account)
                & (Recipe.user_id == self._user_id)
            )
        )
        return list(self._session.exec(statement).all())

    def _require_accessible_recipe(self, recipe_id: str) -> Recipe:
        recipe = self._session.get(Recipe, recipe_id)
        if not recipe:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")

        is_catalog = recipe.ownership_scope in {
            RecipeOwnershipScope.starter_catalog,
            RecipeOwnershipScope.plus_catalog,
        }
        is_owned_custom = (
            recipe.ownership_scope == RecipeOwnershipScope.custom_account
            and recipe.user_id == self._user_id
        )
        if not (is_catalog or is_owned_custom):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")
        return recipe
