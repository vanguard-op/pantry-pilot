# PantryPilot Screen Inventory

## Overview
All screens are listed below, grouped by flow. Each entry includes the screen name, purpose, primary actions, and which other screens it can navigate to.

---

## Onboarding Screens

### 1. Welcome Screen
- **Purpose**: Introduce the app and build initial trust
- **Content**: App name, tagline, brief value proposition (3 bullets max)
- **Actions**: "Get Started" → launches Cognito hosted UI for authentication
- **Note**: Sign-in, sign-up, social login, and MFA are all handled by Cognito. No in-app auth screen.
- **Navigates to**: Household Profile Setup (on successful Cognito session)

### 2. Household Profile Setup Screen
- **Purpose**: Personalize the experience for the household
- **Content**: Household size, dietary restrictions, cooking skill selector
- **Actions**: Fill fields, skip individual fields, "Next"
- **Navigates to**: Pantry Seed Screen

### 3. Pantry Seed Screen
- **Purpose**: Bootstrap initial inventory for better first-use recommendations
- **Content**: Common staples checklist, manual entry option, skip option
- **Actions**: Toggle staple items, tap "Add manually", "Skip for now", "Done"
- **Navigates to**: Home Dashboard (with optional detour to Weekly Planner)

---

## Core Navigation

### 5. Home Dashboard
- **Purpose**: Central hub showing the user's current kitchen state at a glance
- **Content**: Today's planned meals, use-soon alerts, quick actions, weekly plan progress
- **Actions**: "Plan My Week", "Cook Now" (on today's meal), "View Pantry", "Reduce Waste"
- **Navigates to**: Weekly Planner, Recipe Detail (for "Cook Now"), Pantry, Waste Reduction

---

## Weekly Planning Screens

### 6. Weekly Planner Screen
- **Purpose**: View and build the 7-day meal plan
- **Content**: 7-day grid, meal slots, recommended meal cards, plan completion indicator
- **Actions**: Accept suggestion, swap meal, tap to inspect recipe, confirm plan
- **Navigates to**: Recipe Detail, Shopping List, Home Dashboard

### 7. Meal Suggestion Panel
- **Purpose**: Show context-aware meal options for a selected day/slot
- **Content**: Ranked recipe suggestions with tags (time, skill, uses-soon ingredient)
- **Actions**: Tap to preview, swipe to dismiss, "Search all recipes"
- **Navigates to**: Recipe Detail (preview mode), Recipe Search

### 8. Shopping List Screen
- **Purpose**: Show auto-generated list of missing ingredients for the planned week
- **Content**: Grouped ingredient list (by category), quantity, checkboxes
- **Actions**: Check off items, mark item as "Bought", confirm bought quantity, add custom items, remove items, share/export list, "Add Bought Items to Pantry"
- **Note**: Shopping List sync updates pantry ingredients only; leftovers/Cooked Meals cannot be created from this screen
- **Navigates to**: Pantry (to cross-reference and ingredient purchase sync), Weekly Planner

---

## Recipe Screens

### 9. Recipe Search Screen
- **Purpose**: Browse and filter all available recipes
- **Content**: Search bar, filters (time, skill, diet, ingredient), recipe card grid
- **Actions**: Search, apply filters, tap recipe card
- **Navigates to**: Recipe Detail

### 10. Recipe Detail Screen
- **Purpose**: Give full information about a recipe before committing to cook
- **Content**: Photo, description, ingredient list with pantry coverage indicators, readiness status for missing ingredients, steps overview, tags
- **Actions**: Review missing ingredients, accept substitutions, swap from pantry-backed substitute options, "Start Cooking", "Add to Plan", "Save to Favorites", "Back"
- **Navigates to**: Guided Cooking, Weekly Planner (add to slot), Favorites

---

## Guided Cooking Screens

### 11. Cooking Step Screen
- **Purpose**: Display one step at a time for focused, confident cooking
- **Content**: Step number, instruction text, relevant ingredient amounts, step timer (optional)
- **Actions**: "Start Timer", "Next Step", "Previous Step", scroll to read ahead
- **Navigates to**: Next/Previous Step, Completion Screen

### 12. Meal Completion Screen
- **Purpose**: Mark the meal done, collect quick feedback, update pantry, and log leftovers
- **Content**: Completion message, star rating prompt, "Save as Favorite" toggle, leftover prompt ("Did you save any leftovers?"), portions/servings input, consume-by date input, pantry deduction summary
- **Actions**: Rate recipe, toggle favorite, set leftover portions/servings, set consume-by date, confirm or adjust pantry deductions, "Done"
- **Note**: Logged leftovers are stored in pantry under Cooked Meals and appear in the Waste Reduction screen immediately
- **Navigates to**: Home Dashboard, Pantry (if deductions need review)

---

## Inventory Management Screens

### 13. Pantry Screen
- **Purpose**: Full view and management of household inventory
- **Content**: Ingredients grouped by storage (fridge, freezer, pantry shelf), Cooked Meals section (leftovers), Use Soon section at top
- **Actions**: Tap item to edit, swipe to delete, "Add Item" (ingredient or cooked meal), tap use-soon ingredient for recipe suggestions, tap cooked meal for repurpose/eat-soon suggestions
- **Note**: Cooked Meals may be auto-created from Meal Completion leftover logging or added manually via Add Item
- **Navigates to**: Add/Edit Item Screen, Recipe Search (filtered by ingredient)

### 14. Add / Edit Item Screen
- **Purpose**: Create or update a pantry item
- **Content**: Item type selector (Ingredient or Cooked Meal), name, quantity/servings, storage location, expiry/consume-by date fields
- **Actions**: Select item type, fill fields, save, cancel
- **Navigates to**: Pantry Screen

---

## Waste Reduction Screens

### 15. Waste Reduction Screen
- **Purpose**: Surface actionable steps to use near-expiry items and leftovers
- **Content**: Use Soon list (sorted by urgency), Leftovers list sourced from pantry Cooked Meals, recipe/repurpose suggestions per item
- **Actions**: Tap ingredient for recipe ideas, tap cooked meal for repurpose ideas, mark leftover portions used, mark item as discarded, "Plan these meals"
- **Navigates to**: Recipe Detail, Weekly Planner, Pantry

### 16. Weekly Waste Summary Screen
- **Purpose**: Close the loop on weekly food usage and build better habits
- **Content**: Items used before expiry vs. discarded, streak indicator, next-week suggestions
- **Actions**: "Adjust next week's plan", "Dismiss", view historical summaries
- **Navigates to**: Weekly Planner, Home Dashboard

---

## Supporting Screens

### 17. Settings Screen
- **Purpose**: Manage preferences and household configuration
- **Content**: Household profile, dietary settings, notification preferences, expiry threshold, pantry auto-deduct toggle
- **Actions**: Edit fields, toggle switches, save
- **Navigates to**: Household Profile Setup (re-run), Home Dashboard

### 18. Favorites Screen
- **Purpose**: Quick access to saved and frequently used recipes
- **Content**: Favorited recipe cards, usage frequency, last cooked date
- **Actions**: Tap to view, add to plan, remove from favorites
- **Navigates to**: Recipe Detail, Weekly Planner

---

## Screen Count Summary

| Flow | Screens |
|---|---|
| Onboarding | 3 (auth delegated to Cognito hosted UI) |
| Core Navigation | 1 |
| Weekly Planning | 3 |
| Recipe | 2 |
| Guided Cooking | 2 |
| Inventory Management | 2 |
| Waste Reduction | 2 |
| Supporting | 2 |
| **Total** | **17** |
