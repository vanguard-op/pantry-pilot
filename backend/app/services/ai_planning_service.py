from __future__ import annotations

import json
import uuid
from datetime import date, datetime, timedelta

from fastapi import HTTPException, status
import httpx
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

    Uses the OpenCode platform (deepseek-v4-flash and other models) and
    expects strict JSON output.  Falls back to deterministic matching when
    the OpenCode service is not configured.
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
                "units_allowed": list(_ALLOWED_UNITS),
            },
        }

        if not self._is_ai_enabled:
            return self._deterministic_coverage_payload(recipe.id, recipe.ingredients, pantry_items)

        response_json = self._call_opencode(
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
                "units_allowed": list(_ALLOWED_UNITS),
                "note": "normalize names to lowercase singular where possible",
            },
        }

        if not self._is_ai_enabled:
            return self._deterministic_shopping_payload(today, end_date, meals, recipe_by_id, pantry_items)

        response_json = self._call_opencode(
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
        return bool(self._settings.opencode_model.strip())

    def _call_opencode(self, *, instruction: str, context: dict, output_schema: dict) -> dict:
        """Send a structured prompt to OpenCode AI and return the parsed JSON.

        Tries the OpenAI-compatible ``/v1/chat/completions`` endpoint first.
        If that fails (the endpoint may not be mounted) it falls back to the
        native session-based ``POST /session/{id}/message`` path.

        The prompt is sent as a ``system`` message (the instruction) followed
        by a ``user`` message that contains both the context data and the
        expected output schema so the model has everything it needs inline.

        Raises ``HTTPException(502)`` if the server returns an error or the
        response cannot be parsed into a JSON object.
        """
        model = self._settings.opencode_model.strip()
        base_url = self._settings.opencode_base_url.strip().rstrip("/")

        if not model:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=(
                    "OpenCode AI is not configured. "
                    "Set OPENCODE_MODEL and optionally OPENCODE_BASE_URL."
                ),
            )

        user_content = json.dumps(
            {"context": context, "output_schema": output_schema},
            ensure_ascii=True,
        )

        messages = [
            {"role": "system", "content": instruction},
            {
                "role": "user",
                "content": (
                    "Return valid JSON that conforms to the schema below.\n\n"
                    + user_content
                ),
            },
        ]

        body = {
            "model": model,
            "messages": messages,
            "temperature": 0.1,
        }
        session_id = str(uuid.uuid4())

        with httpx.Client(timeout=60.0) as http:
            # ── Attempt 1 — OpenAI-compatible completions ──────────────
            response = http.post(
                f"{base_url}/v1/chat/completions",
                json={**body, "response_format": {"type": "json_object"}},
                headers={"Content-Type": "application/json"},
            )

            response_text = response.text.strip()

            # ── Attempt 2 — Native session message API ─────────────────
            if not response_text:
                response = http.post(
                    f"{base_url}/session/{session_id}/message",
                    json={
                        "modelID": model,
                        "providerID": "opencode-go",
                        "parts": [
                            {
                                "type": "text",
                                "text": json.dumps(body, ensure_ascii=True),
                            }
                        ],
                        "system": instruction,
                    },
                    headers={"Content-Type": "application/json"},
                )
                response_text = response.text.strip()

        # ── Validate HTTP status ───────────────────────────────────────
        if response.status_code != 200:
            detail = (
                f"OpenCode AI at {base_url} returned HTTP "
                f"{response.status_code}"
            )
            if response_text:
                # Attempt to extract a human-readable error from server body.
                try:
                    err_body = json.loads(response_text)
                    err_data = err_body.get("data", {}) if isinstance(err_body, dict) else err_body
                    detail += f": {err_data.get('message', response_text[:500])}"
                except json.JSONDecodeError:
                    detail += f": {response_text[:500]}"
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=detail,
            )

        if not response_text:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=(
                    f"OpenCode AI at {base_url} returned HTTP 200 with an "
                    f"empty body. The server may not support the requested "
                    f"endpoint."
                ),
            )

        # ── Parse top-level JSON ───────────────────────────────────────
        try:
            data = json.loads(response_text)
        except json.JSONDecodeError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=(
                    f"OpenCode AI returned non-JSON response: "
                    f"{response_text[:500]}"
                ),
            ) from exc

        # ── Extract text from session-format response ──────────────────
        if isinstance(data, dict) and "choices" not in data:
            # Session response: look for a text part in the top-level body
            # or in a list wrapper.
            parts = data.get("parts") or []
            text = ""
            for part in parts:
                if part.get("type") == "text":
                    text = (part.get("text") or "").strip()
                    if text:
                        break
            # If still empty, try the first list element (some endpoints
            # wrap the message in a list).
            if not text and isinstance(data.get("data"), list):
                for item in data["data"]:
                    for part in item.get("parts") or []:
                        if part.get("type") == "text":
                            text = (part.get("text") or "").strip()
                            if text:
                                break
                    if text:
                        break

            if not text:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=(
                        f"OpenCode AI returned no text part in session "
                        f"response. Body: {response_text[:500]}"
                    ),
                )
        # ── Extract text from OpenAI-format response ───────────────────
        else:
            choices = data.get("choices") if isinstance(data, dict) else []
            if not choices:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=(
                        f"OpenCode AI response missing 'choices'. "
                        f"Body: {response_text[:500]}"
                    ),
                )
            text = (
                (choices[0].get("message") or {}).get("content") or ""
            ).strip()
            if not text:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="OpenCode AI assistant message content is empty.",
                )

        # ── Parse the extracted JSON text ─────────────────────────────
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=(
                    f"OpenCode AI returned malformed JSON: {text[:500]}"
                ),
            ) from exc

        if not isinstance(parsed, dict):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="OpenCode AI JSON payload must be an object.",
            )

        return parsed

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
            notes="Fallback payload used because OpenCode AI is not configured.",
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
            notes="Fallback payload used because OpenCode AI is not configured.",
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
                        "properties": {
                            "ingredient_text": {
                                "type": "string",
                                "description": "Raw ingredient string as it appears in the recipe, e.g. '200g pasta'",
                            },
                            "normalized_name": {
                                "type": "string",
                                "description": "Lower-cased, singular, trimmed ingredient name for matching against pantry, e.g. 'pasta'",
                            },
                            "required_quantity": {
                                "type": "number",
                                "exclusiveMinimum": 0,
                                "description": "Quantity required by the recipe for this ingredient",
                            },
                            "required_unit": {
                                "type": "string",
                                "enum": list(_ALLOWED_UNITS),
                                "description": "Unit for required_quantity — 'serving' is not valid here; that unit is only for cooked meals/leftovers",
                            },
                            "available_quantity": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Quantity the user already has in their pantry (0 if none)",
                            },
                            "missing_quantity": {
                                "type": "number",
                                "minimum": 0,
                                "description": "Quantity the user still needs to buy (0 if fully covered)",
                            },
                            "status": {
                                "type": "string",
                                "enum": ["available", "missing", "substituted"],
                                "description": "available = pantry covers full required quantity; missing = nothing or insufficient; substituted = a different pantry item can fill the gap",
                            },
                            "matched_pantry_item": {
                                "type": "string",
                                "description": "The pantry item name that matched this ingredient (null when status is 'missing')",
                            },
                            "substitution": {
                                "anyOf": [
                                    {"type": "null"},
                                    {
                                        "type": "object",
                                        "required": ["pantry_item_name"],
                                        "properties": {
                                            "pantry_item_name": {
                                                "type": "string",
                                                "description": "Name of a pantry item that can serve as a substitute",
                                            },
                                            "notes": {
                                                "type": "string",
                                                "description": "Optional human-readable usage note, e.g. 'use 1:1 ratio, adjust cook time'",
                                            },
                                        },
                                    },
                                ],
                                "description": "Present when status is 'substituted'; null otherwise",
                            },
                            "confidence": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Model confidence in this assessment (0.0 – 1.0)",
                            },
                        },
                    },
                },
                "matched_count": {"type": "integer", "minimum": 0},
                "missing_count": {"type": "integer", "minimum": 0},
                "substituted_count": {"type": "integer", "minimum": 0},
                "coverage_percent": {
                    "type": "integer",
                    "minimum": 0,
                    "maximum": 100,
                },
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
                        "properties": {
                            "ingredient_text": {
                                "type": "string",
                                "description": "Raw ingredient string as it appears in recipes, e.g. '200g pasta'",
                            },
                            "normalized_name": {
                                "type": "string",
                                "description": "Lower-cased, singular, trimmed ingredient name for de-duplication across recipes, e.g. 'pasta'",
                            },
                            "suggested_quantity": {
                                "type": "number",
                                "exclusiveMinimum": 0,
                                "description": "Suggested quantity the user should buy to cover all planned meals",
                            },
                            "suggested_unit": {
                                "type": "string",
                                "enum": list(_ALLOWED_UNITS),
                                "description": "Unit for suggested_quantity — 'serving' is not valid here; that unit is only for cooked meals/leftovers",
                            },
                            "reason": {
                                "type": "string",
                                "description": "Short human-readable note explaining why this item is needed, e.g. 'Missing for 2 planned spaghetti bolognese meals'",
                            },
                            "confidence": {
                                "type": "number",
                                "minimum": 0,
                                "maximum": 1,
                                "description": "Model confidence that this item is genuinely needed (0.0 – 1.0)",
                            },
                        },
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
