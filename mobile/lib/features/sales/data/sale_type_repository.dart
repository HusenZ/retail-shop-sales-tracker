import '../../../core/api/api_client.dart';
import '../domain/sale_type.dart';

class SaleTypeRepository {
  SaleTypeRepository(this._api);

  final ApiClient _api;

  /// Default sale type first.
  Future<List<SaleType>> list({bool includeInactive = false}) async {
    final rows = await _api.getJsonList(
      '/sale-types',
      query: {'include_inactive': includeInactive},
    );
    return rows.map(SaleType.fromJson).toList();
  }

  Future<SaleType> create(String name, {bool isExchange = false}) async => SaleType.fromJson(
        await _api.postJson('/sale-types', body: {'name': name, 'is_exchange': isExchange}),
      );

  Future<SaleType> update(String id, {String? name, bool? isActive, bool? isDefault}) async {
    final body = {
      if (name != null) 'name': name,
      if (isActive != null) 'is_active': isActive,
      if (isDefault != null) 'is_default': isDefault,
    };
    return SaleType.fromJson(await _api.patchJson('/sale-types/$id', body: body));
  }
}
