# PantryPilot User Flows

## Overview
This document describes the five primary user flows in PantryPilot. Each flow covers the entry trigger, sequential steps, key decision points, and exit state.

---

## Flow 1: Onboarding

### Entry Trigger
User downloads the app and launches it for the first time.

### Steps
1. Welcome screen → app name, tagline, and brief value proposition
2. Authentication via Cognito hosted UI (handles email/password, social sign-in, and MFA — no in-app auth screens)
   - On success: Cognito returns a session token and the app proceeds
   - Returning users bypass steps 3–4 and land directly on the dashboard
3. Household profile setup
   - Number of people
   - Dietary restrictions or preferences (optional)
   - Cooking skill level (beginner / intermediate / confident)
4. Pantry seed prompt
   - Option A: Quick-add common staples from a checklist
   - Option B: Scan/enter items manually
   - Option C: Skip for now (app prompts again after first session)
5. First meal plan nudge → "Want to plan your first week? It takes 2 minutes."
   - Yes → redirect to Weekly Planning Flow
   - Not now → land on home dashboard

### Key Decisions
- Skill level affects default recipe difficulty shown throughout the app
- Skipping pantry setup reduces personalization; app surfaces a persistent prompt until at least 5 items are added

### Exit State
User lands on the home dashboard with a partially or fully seeded pantry and optionally a first weekly plan underway.

---

## Flow 2: Weekly Planning

### Entry Trigger
- User taps "Plan My Week" on the home dashboard
- Weekly plan reminder notification
- Existing plan expires at the start of a new week

### Steps
1. Planner screen opens showing a 7-day grid
2. App surfaces recommended meals based on:
   - Pantry inventory (prioritize use-soon ingredients)
   - Past favorites and frequency
   - Skill level and time-per-meal filters
3. User reviews suggestions
   - Swipe to accept or swap a meal
   - Tap to see full recipe before deciding
4. For each planned meal, app checks pantry coverage
   - Covered: shows green checkmark
   - Missing ingredients: flags items for shopping list
5. Shopping list auto-generated from gaps
   - User can edit, remove, or add items
6. User marks purchased items after shopping
   - Check off items as "Bought"
   - Confirm quantity actually purchased
   - Bought items are added to pantry stock
7. User confirms plan → saved to planner

### Key Decisions
- User can override any suggestion with manual search
- Partial plans are valid; user is not forced to fill all 7 days
- Shopping list can be exported or shared
- Bought item sync updates pantry before cooking guidance checks

### Exit State
A confirmed weekly meal plan is saved. Missing ingredients are in the shopping list, and bought items can be synced into pantry stock. User returns to the home dashboard with the plan visible.

---

## Flow 3: Guided Cooking

### Entry Trigger
- User taps a scheduled meal in the planner ("Cook now")
- User opens any recipe and taps "Start Cooking"

### Steps
1. Pre-cook checklist
   - App shows required ingredients with pantry quantities
   - Flags any missing items with substitution suggestions
   - User confirms readiness or swaps ingredients
2. Cooking mode activates
   - Step 1 of N displayed full-screen with clear action text
   - Each step shows: instruction, ingredient amounts involved, and estimated time
3. Per-step timer (optional, user-triggered)
   - Timer runs, alerts user when step time is up
   - User taps "Next Step" to progress
4. Parallel task prompts where applicable (e.g., "While the pasta boils, prepare the sauce")
5. Completion screen
   - "Meal complete" confirmation
   - Prompt: rate the recipe (quick 1–5 stars)
   - Option: log it as a household favorite
6. Pantry auto-update
   - Used ingredients are deducted from inventory
   - User can confirm or adjust quantities before saving

### Key Decisions
- If an ingredient is missing at pre-cook check, app offers: substitute, skip, or cancel
- Steps are scrollable if user prefers to read ahead
- Screen stays on during cooking mode

### Exit State
Meal is marked complete in the planner. Inventory is updated. Recipe optionally saved as a favorite.

---

## Flow 4: Inventory Management

### Entry Trigger
- User taps "Pantry" tab at any time
- Post-shopping: notification prompt "Just got groceries? Update your pantry"
- Low-stock alert notification
- User taps "Add Bought Items to Pantry" from Shopping List

### Steps
1. Pantry screen shows all items grouped by storage (fridge, freezer, pantry shelf)
2. Add items
   - Manual entry: name, quantity, unit, expiry date, storage location
   - Quick-add from common item list or recent history
   - (Post-MVP) Barcode scan or receipt import
3. Edit items
   - Tap any item to update quantity, expiry, or location
4. Remove items
   - Swipe to delete or mark as "used up"
5. Expiry alerts
   - Items expiring within 3 days surface in a "Use Soon" section at the top
   - Tapping a use-soon item suggests recipes that use it
6. Low-stock detection
   - Items below a set threshold flagged for restock
   - One-tap add to shopping list

### Key Decisions
- Expiry threshold (3 days) is user-configurable in settings
- Pantry data is the backbone of meal suggestions; incomplete inventory reduces recommendation quality
- Auto-deduction after cooking can be turned off in settings

### Exit State
Pantry reflects current household stock. Expiry alerts and low-stock items are visible and actionable.

---

## Flow 5: Waste Reduction

### Entry Trigger
- "Use Soon" notification as items near expiry
- Weekly waste summary prompt (Friday evening)
- User taps the "Reduce Waste" card on the home dashboard

### Steps
1. Waste Reduction screen shows two sections:
   - **Use Soon**: ingredients expiring within 3 days, sorted by urgency
   - **Leftovers**: meals recently cooked with remaining portions logged
2. For each use-soon ingredient, the app surfaces:
   - Recipes that primarily use that ingredient
   - Quick-use ideas (e.g., "Add spinach to scrambled eggs")
3. For leftover meals:
   - Suggestions for how to repurpose them (e.g., "Turn yesterday's chicken into a wrap")
   - User can log leftover portions used
4. Weekly waste summary (Friday prompt)
   - Shows items used before expiry vs. discarded
   - Highlights streaks ("You wasted nothing this week!")
   - Suggests adjustments to next week's plan (e.g., buy less of what was wasted)

### Key Decisions
- Users can mark an expired item as "discarded" to track waste accurately
- Waste data is private but used to improve future planning suggestions
- Positive reinforcement framing; never shaming about discarded items

### Exit State
User has acted on use-soon items (added to plan or used directly). Waste log is updated. Weekly insight is surfaced to improve next cycle.

---

## Flow Interconnections

| From Flow | Can Trigger |
|---|---|
| Onboarding | Weekly Planning, Inventory Management |
| Weekly Planning | Guided Cooking, Inventory Management |
| Guided Cooking | Inventory Management (auto-deduct), Waste Reduction |
| Inventory Management | Weekly Planning (suggestions update), Waste Reduction |
| Waste Reduction | Weekly Planning, Guided Cooking |
