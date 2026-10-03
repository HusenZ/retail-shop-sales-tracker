import '../../../core/api/api_client.dart';
import '../domain/category.dart';

class CategoryRepository {
  CategoryRepository(this._api);

  final ApiClient _api;

  Future<List<Category>> list({bool includeInactive = false}) async {
    final rows = await _api.getJsonList(
      '/categories',
      query: {'include_inactive': includeInactive},
    );
    return rows.map(Category.fromJson).toList();
  }

  Future<Category> create(String name) async =>
      Category.fromJson(await _api.postJson('/categories', body: {'name': name}));

  Future<Category> update(String id, {String? name, bool? isActive}) async {
    final body = {
      if (name != null) 'name': name,
      if (isActive != null) 'is_active': isActive,
    };
    return Category.fromJson(await _api.patchJson('/categories/$id', body: body));
  }
}
