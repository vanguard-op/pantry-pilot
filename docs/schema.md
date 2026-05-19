# PantryPilot — Data Schema

## Overview

PantryPilot's data model consists of **six table entities** that map to persistent database tables. All entities are scoped to a `user_id`. Enumerations and embedded object types are defined inline within the schemas that reference them.

---

## Core Entities (Table Models)

### `PantryItem`

An item in a user's pantry — can be a raw ingredient or a cooked meal leftover. Tracks quantity, location, and expiry.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://pantrypilot.app/schemas/entities/pantry-item.schema.json",
  "title": "PantryItem",
  "description": "An item in a user's pantry — can be a raw ingredient or a cooked meal leftover.",
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "description": "UUID primary key",
      "format": "uuid"
    },
    "user_id": {
      "type": "string",
      "description": "Foreign key — the owning user's account ID"
    },
    "name": {
      "type": "string",
      "description": "Display name of the item (e.g. 'Chicken Breast')"
    },
    "quantity": {
      "type": "number",
      "description": "Current stock quantity",
      "exclusiveMinimum": 0
    },
    "unit": {
      "type": "string",
      "description": "Unit of measurement (e.g. 'g', 'ml', 'pcs')",
      "default": "pcs"
    },
    "storage_location": {
      "type": "string",
      "description": "Where the item is stored (e.g. 'Pantry', 'Fridge', 'Freezer')",
      "default": "Pantry"
    },
    "item_kind": {
      "type": "string",
      "description": "Whether this is a raw ingredient or a cooked meal",
      "enum": ["ingredient", "cooked_meal"],
      "default": "ingredient"
    },
    "expiry_date": {
      "type": "string",
      "description": "Item expiration date (ISO 8601 date)",
      "format": "date",
      "default": null
    },
    "low_stock_threshold": {
      "type": "number",
      "description": "Quantity threshold that triggers a low-stock alert",
      "minimum": 0,
      "default": 1
    },
    "created_at": {
      "type": "string",
      "description": "Timestamp when the item was added",
      "format": "date-time"
    },
    "updated_at": {
      "type": "string",
      "description": "Timestamp of the last update",
      "format": "date-time"
    }
  },
  "required": ["id", "user_id", "name", "quantity", "unit", "storage_location", "item_kind", "created_at", "updated_at"]
}
```

---

### `Recipe`

A recipe with ingredients, structured steps, metadata, and ownership scope. Recipes can be starter catalog items, plus catalog items, or user-created custom recipes.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://pantrypilot.app/schemas/entities/recipe.schema.json",
  "title": "Recipe",
  "description": "A recipe with ingredients, structured steps, metadata, and ownership scope.",
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "description": "UUID primary key",
      "format": "uuid"
    },
    "user_id": {
      "type": "string",
      "description": "Foreign key — the creator's account ID (null for catalog recipes)",
      "default": null
    },
    "title": {
      "type": "string",
      "description": "Recipe display title"
    },
    "description": {
      "type": "string",
      "description": "Short summary or description of the recipe"
    },
    "prep_minutes": {
      "type": "integer",
      "description": "Preparation time in minutes",
      "minimum": 0,
      "default": 0
    },
    "cook_minutes": {
      "type": "integer",
      "description": "Cooking time in minutes",
      "minimum": 0,
      "default": 0
    },
    "servings": {
      "type": "integer",
      "description": "Number of servings the recipe yields",
      "minimum": 1,
      "default": 1
    },
    "difficulty": {
      "type": "string",
      "description": "Recipe difficulty level",
      "enum": ["Beginner", "Intermediate", "Confident"],
      "default": "Beginner"
    },
    "tags": {
      "type": "array",
      "description": "Freeform tags for filtering (e.g. ['quick', 'vegetarian', 'meal-prep'])",
      "items": {
        "type": "string"
      },
      "default": []
    },
    "ingredients": {
      "type": "array",
      "description": "List of ingredient strings (e.g. ['200g pasta', '2 tbsp olive oil'])",
      "items": {
        "type": "string"
      },
      "default": []
    },
    "steps": {
      "type": "array",
      "description": "Ordered list of cooking steps",
      "items": {
        "type": "object",
        "description": "A single step within a recipe's cooking instructions.",
        "properties": {
          "description": {
            "type": "string",
            "description": "Step instruction text"
          },
          "duration_minutes": {
            "type": "integer",
            "description": "Duration of this step in minutes",
            "minimum": 0
          },
          "ingredient_mentions": {
            "type": "array",
            "description": "References to ingredient names used in this step",
            "items": {
              "type": "string"
            }
          }
        },
        "required": ["description", "duration_minutes", "ingredient_mentions"]
      },
      "default": []
    },
    "ownership_scope": {
      "type": "string",
      "description": "Origin scope of the recipe",
      "enum": ["starter", "plus", "custom"],
      "default": "custom"
    },
    "created_at": {
      "type": "string",
      "description": "Timestamp when the recipe was created",
      "format": "date-time"
    },
    "updated_at": {
      "type": "string",
      "description": "Timestamp of the last update",
      "format": "date-time"
    }
  },
  "required": ["id", "title", "description", "prep_minutes", "cook_minutes", "servings", "difficulty", "ownership_scope", "created_at", "updated_at"]
}
```

---

### `RecipeAccountMetadata`

Per-user metadata attached to a recipe. Tracks favorites, ratings, and usage history. Uses a composite primary key of `(user_id, recipe_id)` — never persisted on the recipe row itself.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://pantrypilot.app/schemas/entities/recipe-account-metadata.schema.json",
  "title": "RecipeAccountMetadata",
  "description": "Per-user metadata attached to a recipe. Composite PK of (user_id, recipe_id).",
  "type": "object",
  "properties": {
    "user_id": {
      "type": "string",
      "description": "Foreign key — the user's account ID (part of composite PK)"
    },
    "recipe_id": {
      "type": "string",
      "description": "Foreign key — the recipe ID (part of composite PK)"
    },
    "is_favorite": {
      "type": "boolean",
      "description": "Whether the user has marked this recipe as a favorite",
      "default": false
    },
    "rating": {
      "type": "integer",
      "description": "User's rating (1–5 scale)",
      "minimum": 1,
      "maximum": 5,
      "default": null
    },
    "last_cooked_at": {
      "type": "string",
      "description": "Timestamp of the most recent cooking session using this recipe",
      "format": "date-time",
      "default": null
    },
    "usage_count": {
      "type": "integer",
      "description": "Number of times the user has cooked this recipe",
      "minimum": 0,
      "default": 0
    },
    "updated_at": {
      "type": "string",
      "description": "Timestamp of the last metadata update",
      "format": "date-time"
    }
  },
  "required": ["user_id", "recipe_id", "is_favorite", "usage_count", "updated_at"]
}
```

---

### `PlannedMeal`

A meal plan entry linking a recipe to a specific date and meal slot (e.g. `breakfast`, `lunch`, `dinner`).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://pantrypilot.app/schemas/entities/planned-meal.schema.json",
  "title": "PlannedMeal",
  "description": "A meal plan entry linking a recipe to a specific date and meal slot.",
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "description": "UUID primary key",
      "format": "uuid"
    },
    "user_id": {
      "type": "string",
      "description": "Foreign key — the owning user's account ID"
    },
    "recipe_id": {
      "type": "string",
      "description": "Foreign key — the recipe planned for this meal"
    },
    "date": {
      "type": "string",
      "description": "The date this meal is planned for (ISO 8601 date)",
      "format": "date"
    },
    "slot": {
      "type": "string",
      "description": "Meal slot identifier (e.g. 'breakfast', 'lunch', 'dinner', 'snack')"
    },
    "created_at": {
      "type": "string",
      "description": "Timestamp when the plan entry was created",
      "format": "date-time"
    },
    "updated_at": {
      "type": "string",
      "description": "Timestamp of the last update",
      "format": "date-time"
    }
  },
  "required": ["id", "user_id", "recipe_id", "date", "slot", "created_at", "updated_at"]
}
```

---

### `SettingsModel`

Per-user application settings and preferences. Keyed by `user_id` as the primary key (one settings row per user).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://pantrypilot.app/schemas/entities/settings.schema.json",
  "title": "SettingsModel",
  "description": "Per-user application settings and preferences. One row per user (user_id is PK).",
  "type": "object",
  "properties": {
    "user_id": {
      "type": "string",
      "description": "Primary key — the user's account ID"
    },
    "household_size": {
      "type": "integer",
      "description": "Number of people in the household",
      "minimum": 1,
      "maximum": 12,
      "default": 1
    },
    "skill_level": {
      "type": "string",
      "description": "User's self-reported cooking skill level",
      "enum": ["Beginner", "Intermediate", "Confident"],
      "default": "Beginner"
    },
    "dietary_notes": {
      "type": "string",
      "description": "Free-text dietary preferences, restrictions, or notes",
      "default": ""
    },
    "onboarding_complete": {
      "type": "boolean",
      "description": "Whether the user has completed the onboarding flow",
      "default": false
    },
    "first_plan_created_at": {
      "type": "string",
      "description": "Timestamp when the user created their first meal plan",
      "format": "date-time",
      "default": null
    },
    "cooking_session_dates": {
      "type": "array",
      "description": "List of dates (ISO 8601) on which cooking sessions occurred, used for streak tracking",
      "items": {
        "type": "string",
        "format": "date"
      },
      "default": []
    },
    "expiry_threshold_days": {
      "type": "integer",
      "description": "Number of days before expiry to trigger a 'use soon' alert",
      "minimum": 1,
      "maximum": 30,
      "default": 3
    },
    "expiry_notifications_enabled": {
      "type": "boolean",
      "description": "Whether expiry-based notifications are enabled",
      "default": true
    },
    "meal_reminder_notifications_enabled": {
      "type": "boolean",
      "description": "Whether meal reminder notifications are enabled",
      "default": true
    },
    "pantry_auto_deduct_enabled": {
      "type": "boolean",
      "description": "Whether pantry quantities are automatically deducted when a meal is cooked",
      "default": true
    },
    "updated_at": {
      "type": "string",
      "description": "Timestamp of the last settings update",
      "format": "date-time"
    }
  },
  "required": ["user_id", "household_size", "skill_level", "onboarding_complete", "expiry_threshold_days", "updated_at"]
}
```

---

### `FeedbackEntry`

A user-submitted feedback or support message.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://pantrypilot.app/schemas/entities/feedback-entry.schema.json",
  "title": "FeedbackEntry",
  "description": "A user-submitted feedback or support message.",
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "description": "UUID primary key",
      "format": "uuid"
    },
    "user_id": {
      "type": "string",
      "description": "Foreign key — the submitting user's account ID"
    },
    "message": {
      "type": "string",
      "description": "Free-text feedback message"
    },
    "category": {
      "type": "string",
      "description": "Categorization of the feedback",
      "enum": ["bug", "suggestion", "other"],
      "default": "other"
    },
    "status": {
      "type": "string",
      "description": "Review status of the feedback",
      "enum": ["open", "in_review", "resolved"],
      "default": "open"
    },
    "created_at": {
      "type": "string",
      "description": "Timestamp of submission",
      "format": "date-time"
    },
    "updated_at": {
      "type": "string",
      "description": "Timestamp of the last status update",
      "format": "date-time"
    }
  },
  "required": ["id", "user_id", "message", "category", "status", "created_at", "updated_at"]
}
```

---

## Entity Relationships

### Diagram Summary

```
User (external auth system)
  ├── 1:N  PantryItem              — user_id FK
  ├── 1:N  Recipe                  — user_id FK (nullable for catalog recipes)
  ├── 1:N  PlannedMeal             — user_id FK
  ├── 1:1  SettingsModel           — user_id PK
  ├── 1:N  FeedbackEntry           — user_id FK
  └── 1:N  RecipeAccountMetadata   — user_id FK (composite PK with recipe_id)

Recipe
  └── 1:N  RecipeAccountMetadata   — recipe_id FK
  └── 1:N  PlannedMeal             — recipe_id FK
  └── embeds  steps[]              — inline object array (RecipeStep)
  └── embeds  ingredients[]        — inline string array
  └── embeds  tags[]               — inline string array
```

### Key Relationship Notes

| From | To | Type | Via | Description |
|------|----|------|-----|-------------|
| `PantryItem` | User | N:1 | `user_id` | Every pantry item belongs to exactly one user. |
| `Recipe` | User | N:1 | `user_id` (nullable) | Custom recipes are owned by a user; catalog recipes have null `user_id`. |
| `RecipeAccountMetadata` | User | N:1 | `user_id` | Composite PK with `recipe_id` — one row per user-recipe pair. |
| `RecipeAccountMetadata` | Recipe | N:1 | `recipe_id` | Metadata is keyed to a recipe. If a recipe is deleted, its metadata rows should cascade. |
| `PlannedMeal` | User | N:1 | `user_id` | Plans belong to a user. |
| `PlannedMeal` | Recipe | N:1 | `recipe_id` | Each planned meal references a recipe. |
| `SettingsModel` | User | 1:1 | `user_id` as PK | One settings row per user, created on onboarding. |
| `FeedbackEntry` | User | N:1 | `user_id` | Feedback is submitted by a user. |

### Inline Enum Values

| Enum | Values | Used In |
|------|--------|---------|
| `PantryItemKind` | `ingredient`, `cooked_meal` | `PantryItem.item_kind` |
| `Difficulty` | `Beginner`, `Intermediate`, `Confident` | `Recipe.difficulty`, `SettingsModel.skill_level` |
| `RecipeOwnershipScope` | `starter`, `plus`, `custom` | `Recipe.ownership_scope` |
| `FeedbackCategory` | `bug`, `suggestion`, `other` | `FeedbackEntry.category` |
| `FeedbackStatus` | `open`, `in_review`, `resolved` | `FeedbackEntry.status` |
