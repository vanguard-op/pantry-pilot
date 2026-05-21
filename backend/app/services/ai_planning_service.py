"""AI planning service — fast deterministic matching with optional AI enrichment.

Architecture
------------
- Deterministic matching runs **instantly** (sub-second) and is always
  available as a clean fallback.
- When AI is enabled the LLM is called **synchronously**.  If the LLM
  fails or times out the request **automatically degrades** to the
  deterministic result so the caller never sees a 5xx error.
- ``reasoning_effort`` can be set via env
  ``OPENCODE_REASONING_EFFORT`` (e.g. ``"low"``) to reduce model
  thinking time when the model supports it.
"""

from __future__ import annotations

import json
from datetime import date, datetime, timedelta

from fastapi import HTTPException, status
from openai import APIError as OpenAIAPIError, OpenAI
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

_ALLOWED_UNITS = {
    "pcs",
    "g",
    "kg",
    "ml",
    "l",
    "cup",
}


class AIPlanningService:
    """Generates structured pantry coverage and shopping gaps via OpenCode AI.

    Falls back to deterministic matching when the AI service is not
    configured or when the AI call fails.
    """

    def __init__(self, session: SessionDep, user_id: UserIdDep) -> None:
        self._session = session
        self._user_id = user_id
        self._settings: Settings = get_settings()

    # ── Public API ────────────────────────────────────────────────────

    def generate_recipe_coverage_payload(self, recipe_id: str) -> AIPantryCoveragePayload:
        recipe = self._require_accessible_recipe(recipe_id)
        ingredients = recipe.ingredients
        pantry_items = self._list_pantry_items()

        if self._is_ai_enabled:
            try:
                prompt_context = self._build_coverage_context(recipe.id, ingredients, pantry_items)
                response_json = self._call_opencode(
                    instruction=(
                        "Return a JSON object that maps recipe ingredients to pantry coverage. "
                        "Follow the schema exactly and include summary counts."
                    ),
                    context=prompt_context,
                    output_schema=self._coverage_output_schema(),
                )
                return AIPantryCoveragePayload.model_validate(response_json)
            except Exception:
                pass  # Degrade gracefully to deterministic below.

        return self._deterministic_coverage_payload(recipe.id, ingredients, pantry_items)

    def generate_shopping_gaps_payload(self, days: int = 7) -> AIShoppingGapsPayload:
        window_days = max(1, days)
        today = date.today()
        end_date = today + timedelta(days=window_days - 1)

        meals = self._list_planned_meals(today, end_date)
        pantry_items = self._list_pantry_items()
        recipes = self._list_accessible_recipes()
        recipe_by_id = {r.id: r for r in recipes}

        if self._is_ai_enabled:
            try:
                prompt_context = self._build_shopping_context(today, end_date, meals, recipes, pantry_items)
                response_json = self._call_opencode(
                    instruction=(
                        "Return a JSON object with normalized shopping gap items and suggested quantities "
                        "for the plan window. Follow the schema exactly."
                    ),
                    context=prompt_context,
                    output_schema=self._shopping_output_schema(),
                )
                payload = AIShoppingGapsPayload.model_validate(response_json)
                if payload.start_date == today and payload.end_date == end_date:
                    return payload
                # Date mismatch — discard and fall through to deterministic.
            except Exception:
                pass  # Degrade gracefully to deterministic below.

        return self._deterministic_shopping_payload(today, end_date, meals, recipe_by_id, pantry_items)

    # ── AI call ───────────────────────────────────────────────────────

    @property
    def _is_ai_enabled(self) -> bool:
        return bool(
            self._settings.opencode_model.strip()
            and self._settings._resolved_opencode_api_key.strip()
            and self._settings.opencode_base_url.strip()
        )

    def _call_opencode(self, *, instruction: str, context: dict, output_schema: dict) -> dict:
        """Send a structured prompt via the OpenAI-compatible endpoint and return parsed JSON."""
        settings = self._settings
        model = settings.opencode_model.strip()

        if not model:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="OpenCode AI is not configured. Set OPENCODE_MODEL and OPENCODE_API_KEY.",
            )

        user_content = json.dumps(
            {"context": context, "output_schema": output_schema},
            ensure_ascii=True,
        )

        client = OpenAI(
            api_key=settings._resolved_opencode_api_key,
            base_url=settings.opencode_base_url,
            timeout=60.0,
            max_retries=0,
        )

        kwargs: dict = {
            "model": model,
            "messages": [
                {"role": "system", "content": instruction},
                {
                    "role": "user",
                    "content": "Return valid JSON that conforms to the schema below.\n\n" + user_content,
                },
            ],
            "temperature": 0.1,
            "response_format": {"type": "json_object"},
        }

        # Pass reasoning_effort only when explicitly configured.
        # This lets models that don't support it fall back gracefully
        # without sending an unknown parameter.
        effort = settings.opencode_reasoning_effort.strip()
        if effort:
            kwargs["reasoning_effort"] = effort

        try:
            completion = client.chat.completions.create(**kwargs)
        except OpenAIAPIError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"OpenCode AI request failed: {exc.message} (HTTP {exc.status_code})",
            ) from exc

        content = (completion.choices[0].message.content or "").strip()
        if not content:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="OpenCode AI returned an empty message.",
            )

        try:
            parsed = json.loads(content)
        except json.JSONDecodeError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"OpenCode AI returned malformed JSON: {content[:500]}",
            ) from exc

        if not isinstance(parsed, dict):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="OpenCode AI JSON payload must be a JSON object.",
            )

        return parsed

    # ── Prompt builders ───────────────────────────────────────────────

    @staticmethod
    def _build_coverage_context(
        recipe_id: str,
        ingredients: list[str],
        pantry_items: list[PantryItem],
    ) -> dict:
        return {
            "recipe": {"id": recipe_id, "ingredients": ingredients},
            "pantry_items": [
                {"name": i.name, "quantity": i.quantity, "unit": i.unit}
                for i in pantry_items
            ],
            "rules": {
                "statuses": [s.value for s in AICoverageStatus],
                "units_allowed": list(_ALLOWED_UNITS),
            },
        }

    @staticmethod
    def _build_shopping_context(
        today: date,
        end_date: date,
        meals: list[PlannedMeal],
        recipes: list[Recipe],
        pantry_items: list[PantryItem],
    ) -> dict:
        recipe_by_id = {r.id: r for r in recipes}
        return {
            "start_date": today.isoformat(),
            "end_date": end_date.isoformat(),
            "planned_meals": [
                {"id": m.id, "recipe_id": m.recipe_id, "date": m.date.isoformat(), "slot": m.slot}
                for m in meals
            ],
            "recipes": [
                {"id": r.id, "title": r.title, "ingredients": r.ingredients}
                for r in recipes
            ],
            "pantry_items": [
                {"name": i.name, "quantity": i.quantity, "unit": i.unit}
                for i in pantry_items
            ],
            "rules": {
                "units_allowed": list(_ALLOWED_UNITS),
                "note": "normalize names to lowercase singular where possible",
            },
        }

    # ── Deterministic fallbacks ───────────────────────────────────────

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
        total = len(ai_ingredients)
        coverage = round(((matched + substituted) / total) * 100) if total else 0

        return AIPantryCoveragePayload(
            recipe_id=recipe_id,
            model="deterministic",
            generated_at=datetime.utcnow(),
            ingredients=ai_ingredients,
            matched_count=matched,
            missing_count=missing,
            substituted_count=substituted,
            coverage_percent=coverage,
            notes="Fast-path deterministic coverage.",
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
            model="deterministic",
            generated_at=datetime.utcnow(),
            items=items,
            notes="Fast-path deterministic shopping gaps.",
        )

    # ── Output schemas (for the AI prompt) ────────────────────────────

    def _coverage_output_schema(self) -> dict:
        return {
            "type": "object",
            "required": [
                "recipe_id", "model", "generated_at", "ingredients",
                "matched_count", "missing_count", "substituted_count", "coverage_percent",
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
                            "ingredient_text", "normalized_name", "required_quantity",
                            "required_unit", "available_quantity", "missing_quantity",
                            "status", "confidence",
                        ],
                        "properties": {
                            "ingredient_text": {"type": "string", "description": "Raw ingredient string as it appears in the recipe, e.g. '200g pasta'"},
                            "normalized_name": {"type": "string", "description": "Lower-cased, singular, trimmed ingredient name for matching against pantry, e.g. 'pasta'"},
                            "required_quantity": {"type": "number", "exclusiveMinimum": 0, "description": "Quantity required by the recipe for this ingredient"},
                            "required_unit": {"type": "string", "enum": list(_ALLOWED_UNITS), "description": "Unit for required_quantity"},
                            "available_quantity": {"type": "number", "minimum": 0, "description": "Quantity the user already has in their pantry"},
                            "missing_quantity": {"type": "number", "minimum": 0, "description": "Quantity the user still needs to buy"},
                            "status": {"type": "string", "enum": ["available", "missing", "substituted"], "description": "Coverage status"},
                            "matched_pantry_item": {"type": "string", "description": "The pantry item name that matched this ingredient"},
                            "substitution": {
                                "anyOf": [
                                    {"type": "null"},
                                    {
                                        "type": "object",
                                        "required": ["pantry_item_name"],
                                        "properties": {
                                            "pantry_item_name": {"type": "string", "description": "Name of a pantry item that can serve as a substitute"},
                                            "notes": {"type": "string", "description": "Optional human-readable usage note"},
                                        },
                                    },
                                ],
                                "description": "Present when status is 'substituted'; null otherwise",
                            },
                            "confidence": {"type": "number", "minimum": 0, "maximum": 1, "description": "Model confidence in this assessment"},
                        },
                    },
                },
                "matched_count": {"type": "integer", "minimum": 0},
                "missing_count": {"type": "integer", "minimum": 0},
                "substituted_count": {"type": "integer", "minimum": 0},
                "coverage_percent": {"type": "integer", "minimum": 0, "maximum": 100},
                "notes": {"type": "string"},
            },
        }

    def _shopping_output_schema(self) -> dict:
        return {
            "type": "object",
            "required": ["start_date", "end_date", "model", "generated_at", "items"],
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
                            "ingredient_text", "normalized_name", "suggested_quantity",
                            "suggested_unit", "confidence",
                        ],
                        "properties": {
                            "ingredient_text": {"type": "string", "description": "Raw ingredient string as it appears in recipes, e.g. '200g pasta'"},
                            "normalized_name": {"type": "string", "description": "Lower-cased, singular, trimmed ingredient name for de-duplication across recipes"},
                            "suggested_quantity": {"type": "number", "exclusiveMinimum": 0, "description": "Suggested quantity the user should buy"},
                            "suggested_unit": {"type": "string", "enum": list(_ALLOWED_UNITS), "description": "Unit for suggested_quantity"},
                            "reason": {"type": "string", "description": "Short human-readable note explaining why this item is needed"},
                            "confidence": {"type": "number", "minimum": 0, "maximum": 1, "description": "Model confidence that this item is genuinely needed"},
                        },
                    },
                },
                "notes": {"type": "string"},
            },
        }

    # ── Data helpers ──────────────────────────────────────────────────

    def _list_pantry_items(self) -> list[PantryItem]:
        return list(self._session.exec(select(PantryItem).where(PantryItem.user_id == self._user_id)).all())

    def _list_planned_meals(self, start_date: date, end_date: date) -> list[PlannedMeal]:
        return list(
            self._session.exec(
                select(PlannedMeal).where(
                    PlannedMeal.user_id == self._user_id,
                    PlannedMeal.date >= start_date,
                    PlannedMeal.date <= end_date,
                )
            ).all()
        )

    def _list_accessible_recipes(self) -> list[Recipe]:
        return list(
            self._session.exec(
                select(Recipe).where(
                    (Recipe.ownership_scope == RecipeOwnershipScope.starter_catalog)
                    | (Recipe.ownership_scope == RecipeOwnershipScope.plus_catalog)
                    | (
                        (Recipe.ownership_scope == RecipeOwnershipScope.custom_account)
                        & (Recipe.user_id == self._user_id)
                    )
                )
            ).all()
        )

    def _require_accessible_recipe(self, recipe_id: str) -> Recipe:
        recipe = self._session.get(Recipe, recipe_id)
        if not recipe:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")

        is_catalog = recipe.ownership_scope in {
            RecipeOwnershipScope.starter_catalog,
            RecipeOwnershipScope.plus_catalog,
        }
        is_custom = (
            recipe.ownership_scope == RecipeOwnershipScope.custom_account
            and recipe.user_id == self._user_id
        )
        if not (is_catalog or is_custom):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipe not found")
        return recipe
