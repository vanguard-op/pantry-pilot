import '../api/api_client.dart';
import '../models/pantry_item.dart';
import '../models/shopping_list_item.dart';

class ShoppingRepository {
  ShoppingRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ShoppingListItem>> getShoppingList({int days = 7}) async {
    final response = await _apiClient.getObject(
      '/api/v1/shopping',
      queryParameters: <String, String>{'days': days.toString()},
    );

    final rawItems = (response['items'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);

    return rawItems
        .map(ShoppingListItem.fromMap)
        .where((item) => item.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<PantryItem>> syncBoughtItems(
    Map<String, double> bought,
    Map<String, String> units,
  ) async {
    final payload = bought.entries
        .where((entry) => entry.key.trim().isNotEmpty && entry.value > 0)
        .map(
          (entry) => <String, dynamic>{
            'name': entry.key.trim(),
            'quantity': entry.value,
            'unit': (units[entry.key] ?? 'pcs').trim().toLowerCase(),
          },
        )
        .toList(growable: false);

    final response = await _apiClient.postList(
      '/api/v1/shopping/sync-bought',
      body: payload,
    );

    return response
        .whereType<Map>()
        .map((item) => PantryItem.fromMap(item.cast<String, dynamic>()))
        .toList(growable: false);
  }
}
