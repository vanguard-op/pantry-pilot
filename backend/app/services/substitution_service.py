from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import PantryItem, SubstitutionHint, SubstitutionHintsResponse

_SUBSTITUTION_KB: dict[str, str] = {
    "olive oil": "use butter or neutral cooking oil",
    "butter": "use olive oil or coconut oil",
    "spinach": "use kale, lettuce, or frozen greens",
    "kale": "use spinach or Swiss chard",
    "rice": "use quinoa or pasta",
    "quinoa": "use rice or couscous",
    "pasta": "use rice or wrap strips",
    "chicken": "use tofu, beans, or egg",
    "beef": "use chicken, pork, or lentils",
    "pork": "use chicken or tempeh",
    "egg": "use a flax egg (1 tbsp ground flax + 3 tbsp water) or silken tofu",
    "milk": "use plant-based milk or water with a pinch of cream",
    "cream": "use coconut cream or Greek yogurt",
    "garlic": "use garlic powder (1/4 tsp per clove) or shallots",
    "onion": "use shallots, leek, or onion powder",
    "tomato": "use canned tomatoes or tomato paste diluted with water",
    "lemon": "use lime juice or white wine vinegar",
    "soy sauce": "use coconut aminos or tamari",
    "flour": "use almond flour or oat flour at equal ratio",
    "breadcrumbs": "use crushed crackers or panko",
    "broccoli": "use cauliflower, green beans, or frozen broccoli",
    "carrot": "use parsnip or sweet potato",
    "bell pepper": "use zucchini or extra tomato",
    "mushroom": "use eggplant or zucchini for similar texture",
    "tofu": "use chicken, tempeh, or chickpeas",
    "salt": "use soy sauce or tamari for umami salt",
    "sugar": "use honey or maple syrup (use 3/4 of the amount)",
}


class SubstitutionService:
    def __init__(self, session: SessionDep, user_id: UserIdDep) -> None:
        self._session = session
        self._user_id = user_id

    def build_substitution_hints(self, ingredients: list[str]) -> SubstitutionHintsResponse:
        if not ingredients:
            return SubstitutionHintsResponse(hints=[])

        expanded = self._expand_ingredients(ingredients)
        if not expanded:
            return SubstitutionHintsResponse(hints=[])

        pantry_items = list(
            self._session.exec(select(PantryItem).where(PantryItem.user_id == self._user_id)).all()
        )
        pantry_names = {item.name.lower() for item in pantry_items}

        hints: list[SubstitutionHint] = []
        for ingredient in expanded:
            normalised = ingredient.strip().lower()
            default_hint = _SUBSTITUTION_KB.get(
                normalised,
                "swap with a similar pantry item and adjust cook time",
            )
            pantry_hint = self._pantry_suggestion(normalised, default_hint, pantry_names)
            hint_text = pantry_hint if pantry_hint else f"{ingredient}: {default_hint}"
            hints.append(SubstitutionHint(ingredient=ingredient, hint=hint_text))

        return SubstitutionHintsResponse(hints=hints)

    def _expand_ingredients(self, raw_ingredients: list[str]) -> list[str]:
        expanded: list[str] = []
        for item in raw_ingredients:
            expanded.extend(part.strip() for part in item.split(",") if part.strip())
        return expanded

    def _pantry_suggestion(
        self,
        ingredient: str,
        default_hint: str,
        pantry_names: set[str],
    ) -> str | None:
        kb_entry = _SUBSTITUTION_KB.get(ingredient)
        if kb_entry is None:
            return None

        substitutes = [token.strip().rstrip(",") for token in kb_entry.split()]
        for substitute in substitutes:
            if len(substitute) < 3:
                continue
            for pantry_name in pantry_names:
                if substitute in pantry_name or pantry_name in substitute:
                    return f"{ingredient}: you have {pantry_name} — {default_hint}"
        return None
