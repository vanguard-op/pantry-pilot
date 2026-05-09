#!/usr/bin/env python3
"""
Validation script for recipes.json
Checks JSON structure, RecipeCreate schema compliance, and starter/plus categorization
"""

import json
from pathlib import Path
from typing import List, Dict, Any

def validate_recipes():
    """Validate recipes.json structure and content."""
    recipes_file = Path(__file__).parent / "recipes.json"
    
    # Load and parse JSON
    try:
        with open(recipes_file, 'r') as f:
            recipes = json.load(f)
    except json.JSONDecodeError as e:
        print(f"❌ JSON Parse Error: {e}")
        return False
    except FileNotFoundError:
        print(f"❌ File not found: {recipes_file}")
        return False
    
    print(f"✓ JSON parsed successfully")
    print(f"✓ Total recipes: {len(recipes)}")
    
    # Validate structure
    required_fields = {"title", "description", "prep_minutes", "cook_minutes", "servings", "difficulty", "tags", "ingredients", "steps"}
    
    errors = []
    starter_count = 0
    plus_count = 0
    
    for idx, recipe in enumerate(recipes):
        # Check required fields
        missing = required_fields - set(recipe.keys())
        if missing:
            errors.append(f"Recipe {idx} ({recipe.get('title', 'UNKNOWN')}): Missing fields {missing}")
            continue
        
        # Validate field types
        if not isinstance(recipe["title"], str) or not recipe["title"]:
            errors.append(f"Recipe {idx}: Invalid title")
        if not isinstance(recipe["description"], str) or not recipe["description"]:
            errors.append(f"Recipe {idx}: Invalid description")
        if not isinstance(recipe["prep_minutes"], int) or recipe["prep_minutes"] < 0:
            errors.append(f"Recipe {idx}: Invalid prep_minutes")
        if not isinstance(recipe["cook_minutes"], int) or recipe["cook_minutes"] < 0:
            errors.append(f"Recipe {idx}: Invalid cook_minutes")
        if not isinstance(recipe["servings"], int) or recipe["servings"] < 1:
            errors.append(f"Recipe {idx}: Invalid servings")
        if recipe["difficulty"] not in ["Beginner", "Intermediate", "Confident"]:
            errors.append(f"Recipe {idx}: Invalid difficulty")
        if not isinstance(recipe["tags"], list):
            errors.append(f"Recipe {idx}: tags must be list")
        if not isinstance(recipe["ingredients"], list):
            errors.append(f"Recipe {idx}: ingredients must be list")
        if not isinstance(recipe["steps"], list):
            errors.append(f"Recipe {idx}: steps must be list")
        
        # Validate steps structure
        for step_idx, step in enumerate(recipe["steps"]):
            if not isinstance(step, dict):
                errors.append(f"Recipe {idx}, step {step_idx}: step must be object")
                continue
            if "description" not in step or "duration_minutes" not in step or "ingredient_mentions" not in step:
                errors.append(f"Recipe {idx}, step {step_idx}: Missing required fields (description, duration_minutes, ingredient_mentions)")
            if not isinstance(step.get("duration_minutes"), int):
                errors.append(f"Recipe {idx}, step {step_idx}: duration_minutes must be int")
            if not isinstance(step.get("ingredient_mentions"), list):
                errors.append(f"Recipe {idx}, step {step_idx}: ingredient_mentions must be list")
        
        # Categorize as starter or plus
        total_time = recipe["prep_minutes"] + recipe["cook_minutes"]
        ingredient_count = len(recipe["ingredients"])
        difficulty = recipe["difficulty"]
        
        is_starter = (
            total_time <= 20 and
            ingredient_count <= 7 and
            difficulty in ["Beginner", "Intermediate"]
        )
        
        if is_starter:
            starter_count += 1
        else:
            plus_count += 1
    
    if errors:
        print(f"\n❌ Validation errors ({len(errors)}):")
        for error in errors:
            print(f"  - {error}")
        return False
    
    print(f"\n✓ All recipes have valid schema")
    print(f"\n📊 Recipe Classification:")
    print(f"  Starter recipes: {starter_count}")
    print(f"  Plus recipes: {plus_count}")
    
    if starter_count != 50:
        print(f"⚠️  Warning: Expected 50 starter recipes, got {starter_count}")
    if plus_count != 50:
        print(f"⚠️  Warning: Expected 50 plus recipes, got {plus_count}")
    
    if starter_count == 50 and plus_count == 50:
        print(f"\n✓ Perfect balance: 50 starter + 50 plus = 100 total recipes")
    
    # Sample recipes
    print(f"\n📝 Sample Recipes:")
    print(f"  First recipe: {recipes[0]['title']} (Starter: {recipes[0]['prep_minutes'] + recipes[0]['cook_minutes']} min, {len(recipes[0]['ingredients'])} ingredients)")
    print(f"  Middle recipe: {recipes[50]['title']} (Plus: {recipes[50]['prep_minutes'] + recipes[50]['cook_minutes']} min, {len(recipes[50]['ingredients'])} ingredients)")
    print(f"  Last recipe: {recipes[-1]['title']} (Plus: {recipes[-1]['prep_minutes'] + recipes[-1]['cook_minutes']} min, {len(recipes[-1]['ingredients'])} ingredients)")
    
    return True

if __name__ == "__main__":
    success = validate_recipes()
    exit(0 if success else 1)
