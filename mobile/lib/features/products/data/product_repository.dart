import '../../../core/api/api_client.dart';
import '../../../core/data_changes.dart';
import '../domain/product.dart';

class ProductRepository with DataChanges {
  ProductRepository(this._api);

  final ApiClient _api;

  Future<List<Product>> list({
    String? search,
    String? categoryId,
    StockStatus? stockStatus,
    bool includeInactive = false,
  }) async {
    final rows = await _api.getJsonList(
      '/products',
      query: {
        'search': search,
        'category_id': categoryId,
        'stock_status': stockStatus?.apiValue,
        'include_inactive': includeInactive,
      },
    );
    return rows.map(Product.fromJson).toList();
  }

  Future<Product> get(String id) async => Product.fromJson(await _api.getJson('/products/$id'));

  Future<Product> create(ProductInput input) => _changed(
        _api.postJson('/products', body: input.toCreateJson()),
      );

  Future<Product> update(String id, ProductInput input) => _changed(
        _api.patchJson('/products/$id', body: input.toUpdateJson()),
      );

  /// Positive to add received stock, negative to remove.
  Future<Product> adjustStock(String id, int change) => _changed(
        _api.postJson('/products/$id/stock-adjustment', body: {'change': change}),
      );

  Future<Product> _changed(Future<Json> request) async {
    final product = Product.fromJson(await request);
    notifyChanged();
    return product;
  }
}
