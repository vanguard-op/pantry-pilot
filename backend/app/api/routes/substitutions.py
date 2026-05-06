from fastapi import APIRouter, Query

from app.api.deps import SessionDep, UserIdDep
from app.models import PantryItem, SubstitutionHint, SubstitutionHintsResponse
from sqlmodel import select

router = APIRouter(prefix="/substitutions", tags=["substitutions"])

# Static knowledge base: maps an ingredient name to a canonical substitution
# hint. Pantry-aware hints (using items the user actually has) are generated
# at request time and layered on top of these defaults.
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


@router.get("", response_model=SubstitutionHintsResponse)
def get_substitution_hints(
    session: SessionDep,
    user_id: UserIdDep,
    ingredients: list[str] = Query(default=[]),
) -> SubstitutionHintsResponse:
    """Return substitution hints for a list of ingredient names.

    Each hint is enriched with pantry-aware suggestions when the user has
    a plausible substitute already in stock. Falls back to the knowledge
    base default for unknown ingredients.
    """
    if not ingredients:
        return SubstitutionHintsResponse(hints=[])

    # Support comma-separated values sent as a single query param, e.g.
    # ?ingredients=chicken,rice, in addition to repeated params.
    expanded: list[str] = []
    for item in ingredients:
        expanded.extend(part.strip() for part in item.split(",") if part.strip())
    ingredients = expanded

    pantry_items = list(
        session.exec(select(PantryItem).where(PantryItem.user_id == user_id)).all()
    )
    pantry_names = {item.name.lower() for item in pantry_items}

    hints: list[SubstitutionHint] = []
    for ingredient in ingredients:
        normalised = ingredient.strip().lower()
        default_hint = _SUBSTITUTION_KB.get(
            normalised, f"swap with a similar pantry item and adjust cook time"
        )

        # Attempt to build a pantry-aware hint by finding items that share
        # a keyword with the ingredient or appear in its KB entry.
        pantry_suggestion = _pantry_suggestion(normalised, default_hint, pantry_names)
        hint_text = pantry_suggestion if pantry_suggestion else f"{ingredient}: {default_hint}"

        hints.append(SubstitutionHint(ingredient=ingredient, hint=hint_text))

    return SubstitutionHintsResponse(hints=hints)


def _pantry_suggestion(
    ingredient: str, default_hint: str, pantry_names: set[str]
) -> str | None:
    """Return a personalised suggestion if the user has a plausible substitute."""
    kb_entry = _SUBSTITUTION_KB.get(ingredient)
    if kb_entry is None:
        return None

    # Check if any of the KB-suggested substitutes are already in the pantry.
    substitutes = [token.strip().rstrip(",") for token in kb_entry.split()]
    for substitute in substitutes:
        # Only consider multi-char words as meaningful ingredient names.
        if len(substitute) < 3:
            continue
        for pantry_name in pantry_names:
            if substitute in pantry_name or pantry_name in substitute:
                return f"{ingredient}: you have {pantry_name} — {kb_entry}"
    return None
