import json

# Read the current recipes
with open('app/core/recipes.json', 'r', encoding='utf-8') as f:
    recipes = json.load(f)

# Group recipes by difficulty
starter_recipes = [r for r in recipes if r.get('difficulty') in ['Beginner', 'Intermediate']]
plus_recipes = [r for r in recipes if r.get('difficulty') == 'Confident']

# Create grouped structure
grouped_recipes = {
    'starter': starter_recipes,
    'plus': plus_recipes
}

# Write back to file
with open('app/core/recipes.json', 'w', encoding='utf-8') as f:
    json.dump(grouped_recipes, f, indent=2, ensure_ascii=False)

print(f'✅ Successfully reorganized recipes.json')
print(f'✅ Starter recipes: {len(starter_recipes)}')
print(f'✅ Plus recipes: {len(plus_recipes)}')
print(f'✅ Total: {len(starter_recipes) + len(plus_recipes)}')
