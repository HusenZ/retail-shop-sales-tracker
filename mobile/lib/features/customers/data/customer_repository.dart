import '../../../core/api/api_client.dart';
import '../../../core/data_changes.dart';
import '../domain/customer.dart';

class CustomerRepository with DataChanges {
  CustomerRepository(this._api);

  final ApiClient _api;

  Future<List<Customer>> list({String? search, bool pendingOnly = false}) async {
    final rows = await _api.getJsonList(
      '/customers',
      query: {'search': search, 'pending_only': pendingOnly},
    );
    return rows.map(Customer.fromJson).toList();
  }

  Future<Customer> get(String id) async =>
      Customer.fromJson(await _api.getJson('/customers/$id'));

  Future<Customer> create(CustomerInput input) async {
    final customer = Customer.fromJson(await _api.postJson('/customers', body: input.toJson()));
    notifyChanged();
    return customer;
  }

  Future<Customer> update(String id, CustomerInput input) async {
    final customer =
        Customer.fromJson(await _api.patchJson('/customers/$id', body: input.toJson()));
    notifyChanged();
    return customer;
  }
}
