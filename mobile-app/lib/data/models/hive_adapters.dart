import 'package:hive/hive.dart';

import 'pantry_item.dart';
import 'planned_meal.dart';
import 'recipe.dart';
import 'recipe_step.dart';

class PantryItemAdapter extends TypeAdapter<PantryItem> {
  @override
  final int typeId = 0;

  @override
  PantryItem read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final quantity = reader.readDouble();
    final unit = reader.readString();
    final storageLocation = reader.readString();
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final lowStockThreshold = reader.readDouble();

    return PantryItem(
      id: id,
      name: name,
      quantity: quantity,
      unit: unit,
      storageLocation: storageLocation,
      expiryDate: expiryDate,
      lowStockThreshold: lowStockThreshold,
    );
  }

  @override
  void write(BinaryWriter writer, PantryItem obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeDouble(obj.quantity);
    writer.writeString(obj.unit);
    writer.writeString(obj.storageLocation);
    writer.writeInt(obj.expiryDate.millisecondsSinceEpoch);
    writer.writeDouble(obj.lowStockThreshold);
  }
}

class RecipeStepAdapter extends TypeAdapter<RecipeStep> {
  @override
  final int typeId = 1;

  @override
  RecipeStep read(BinaryReader reader) {
    return RecipeStep(
      description: reader.readString(),
      durationMinutes: reader.readInt(),
      ingredientMentions: reader.readList().cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, RecipeStep obj) {
    writer.writeString(obj.description);
    writer.writeInt(obj.durationMinutes);
    writer.writeList(obj.ingredientMentions);
  }
}

class RecipeAdapter extends TypeAdapter<Recipe> {
  @override
  final int typeId = 2;

  @override
  Recipe read(BinaryReader reader) {
    return Recipe(
      id: reader.readString(),
      title: reader.readString(),
      description: reader.readString(),
      prepMinutes: reader.readInt(),
      cookMinutes: reader.readInt(),
      servings: reader.readInt(),
      difficulty: reader.readString(),
      tags: reader.readList().cast<String>(),
      ingredients: reader.readList().cast<String>(),
      steps: reader.readList().cast<RecipeStep>(),
      isFavorite: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, Recipe obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.description);
    writer.writeInt(obj.prepMinutes);
    writer.writeInt(obj.cookMinutes);
    writer.writeInt(obj.servings);
    writer.writeString(obj.difficulty);
    writer.writeList(obj.tags);
    writer.writeList(obj.ingredients);
    writer.writeList(obj.steps);
    writer.writeBool(obj.isFavorite);
  }
}

class PlannedMealAdapter extends TypeAdapter<PlannedMeal> {
  @override
  final int typeId = 3;

  @override
  PlannedMeal read(BinaryReader reader) {
    return PlannedMeal(
      id: reader.readString(),
      recipeId: reader.readString(),
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      slot: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, PlannedMeal obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.recipeId);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeString(obj.slot);
  }
}
