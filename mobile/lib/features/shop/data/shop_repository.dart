import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../domain/shop.dart';

class ShopRepository {
  ShopRepository(this._api);

  final ApiClient _api;

  /// Null when the user has not set up their shop yet.
  Future<Shop?> getShop() async {
    try {
      return Shop.fromJson(await _api.getJson('/shop'));
    } on ApiException catch (error) {
      if (error.isNotFound) return null;
      rethrow;
    }
  }

  Future<Shop> createShop(ShopInput input) async =>
      Shop.fromJson(await _api.postJson('/shop', body: input.toJson()));

  Future<Shop> updateShop(ShopInput input) async =>
      Shop.fromJson(await _api.patchJson('/shop', body: input.toJson()));
}
