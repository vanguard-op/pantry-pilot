# PantryPilot Feature Plan

## Prioritization Framework
- Priority basis: user pain solved, implementation complexity, and retention impact
- Focus users: busy families, meal-prep enthusiasts, beginner cooks

## MVP Features (Mobile First)

### 1. Pantry Inventory
- Add/edit/remove ingredients with quantity, unit, and storage location
- Store leftovers as pantry Cooked Meals (separate from ingredient inventory) with portion/serving count and consume-by date
- Cooked Meals can be created automatically from Meal Completion leftover logging and manually from Pantry Add Item
- Expiry date tracking with "use soon" surfacing
- Low-stock flagging for restock planning

### 2. Meal Planning
- Weekly planner with drag-and-drop meals
- AI translates recipe ingredient text and planning context into structured coverage data
- AI generates pantry coverage results and shopping gaps, including suggested missing quantities
- Rule-based logic validates AI JSON payloads (schema/consistency/safety constraints) before use
- Shopping list purchase check-off that adds bought ingredients into pantry ingredient stock only (not Cooked Meals/leftovers)

#### AI-Generated Structured Data Contract
- AI outputs structured JSON for pantry coverage and shopping gaps (ingredients, quantities, units, substitutions, confidence/context fields)
- Rule-based logic does not recompute full coverage/gap decisions; it validates payload integrity and rejects malformed or inconsistent output

### 3. Recipe Management

#### Data Ownership Model: Hybrid
Recipes follow a three-layer ownership model:

| Layer | Ownership | Description |
|---|---|---|
| Global catalog | Platform-owned | Curated starter recipes available to all users; read-only to users |
| Account metadata | Account-scoped | Per-account data: favorites, ratings, last cooked date, usage frequency |
| Custom recipes | Account-scoped | User-created or imported recipes; only visible to the owning account |

- Global catalog is the source for all ingredient-aware suggestions and guided cooking
- Account metadata drives personalization (favorites, planner recommendations, repeat meals)
- Custom recipes are a Plus-tier feature; stored against the authenticated account (Cognito user ID)
- No recipe data is shared across accounts in MVP (multi-household sharing is post-MVP)

#### Features
- Browse and filter the global recipe catalog (time, skill, dietary preference)
- Mark global recipes as household favorites (stored as account metadata)
- Mark recipes as repeatable weekly meals (stored as account metadata)
- (Plus) Create, edit, and import custom recipes linked to the account
- Recipe suggestions in planner use both global catalog and account-owned custom recipes

### 4. Guided Cooking
- Step-by-step cooking mode with clear instruction progression
- Built-in timers per step
- Quick substitution hints when ingredients are missing

### 5. Waste Reduction Nudges
- "Cook this first" queue for near-expiry ingredients
- Leftover logging on Meal Completion Screen: prompt to record remaining portions as pantry Cooked Meals after every guided cook session
- Leftover-based suggestions surfaced from pantry Cooked Meals in the Waste Reduction screen
- Weekly waste-reduction summary

> **Post-MVP**: Manual cooked-meal/leftover entry from the Waste Reduction screen for meals cooked outside the app

## Post-MVP Features
- Multi-user household roles and permissions
- Barcode scanning and receipt import for faster inventory updates
- Grocery integration (delivery/curbside sync)
- Nutrition tracking and macro-aware recommendations
- Voice-assisted cooking mode
- AI meal coach for budget and dietary goals

## Non-Goals for MVP
- Full e-commerce grocery checkout
- Advanced nutrition medical planning
- Smart appliance integration

## Success Criteria
- Users create first weekly plan within first 2 sessions
- At least 3 guided cooking sessions per active user per week
- Measurable reduction in expired/discarded items after 4 weeks
