from sqlmodel import select

from app.api.deps import SessionDep, UserIdDep
from app.models import PantryItem, PantrySubstituteOption, SubstitutionHint, SubstitutionHintsResponse

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
        # Map normalised pantry name → original display name for matching.
        pantry_name_map: dict[str, str] = {item.name.lower(): item.name for item in pantry_items}

        hints: list[SubstitutionHint] = []
        for ingredient in expanded:
            normalised = ingredient.strip().lower()
            default_hint = _SUBSTITUTION_KB.get(
                normalised,
                "swap with a similar pantry item and adjust cook time",
            )
            pantry_subs = self._find_pantry_substitutes(normalised, pantry_name_map)
            # Build a human-readable hint that surfaces the best pantry match when available.
            if pantry_subs:
                first = pantry_subs[0].pantry_item_name
                hint_text = f"{ingredient}: you have {first} in your pantry — {default_hint}"
            else:
                hint_text = f"{ingredient}: {default_hint}"
            hints.append(
                SubstitutionHint(
                    ingredient=ingredient,
                    hint=hint_text,
                    pantry_substitutes=pantry_subs,
                )
            )

        return SubstitutionHintsResponse(hints=hints)

    def _expand_ingredients(self, raw_ingredients: list[str]) -> list[str]:
        expanded: list[str] = []
        for item in raw_ingredients:
            expanded.extend(part.strip() for part in item.split(",") if part.strip())
        return expanded

    def _find_pantry_substitutes(
        self,
        ingredient: str,
        pantry_name_map: dict[str, str],
    ) -> list[PantrySubstituteOption]:
        """Return pantry items that are known substitutes for `ingredient`.

        Looks up the ingredient in the knowledge base, tokenises the suggestion
        text, and matches each token against the user's pantry by substring
        containment. Each match becomes a `PantrySubstituteOption` so the
        mobile client can present concrete pantry-sourced swap choices.
        """
        kb_entry = _SUBSTITUTION_KB.get(ingredient)
        if kb_entry is None:
            return []

        tokens = [t.strip().rstrip(",") for t in kb_entry.split()]
        found: list[PantrySubstituteOption] = []
        seen: set[str] = set()
        for token in tokens:
            if len(token) < 3:
                continue
            for norm_name, orig_name in pantry_name_map.items():
                if norm_name in seen:
                    continue
                if token in norm_name or norm_name in token:
                    found.append(
                        PantrySubstituteOption(pantry_item_name=orig_name, reason=kb_entry)
                    )
                    seen.add(norm_name)
        return found
