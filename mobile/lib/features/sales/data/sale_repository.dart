import 'package:decimal/decimal.dart';

import '../../../core/api/api_client.dart';
import '../../../core/data_changes.dart';
import '../domain/sale.dart';

class SaleRepository with DataChanges {
  SaleRepository(this._api);

  final ApiClient _api;

  Future<SaleDetail> create(NewSale sale) async {
    final created = SaleDetail.fromJson(await _api.postJson('/sales', body: sale.toJson()));
    notifyChanged();
    return created;
  }

  Future<List<SaleSummary>> list({
    SaleFilters filters = const SaleFilters(),
    required int limit,
    int offset = 0,
  }) async {
    final rows = await _api.getJsonList(
      '/sales',
      query: {...filters.toQuery(), 'limit': limit, 'offset': offset},
    );
    return rows.map(SaleSummary.fromJson).toList();
  }

  Future<SaleDetail> get(String id) async => SaleDetail.fromJson(await _api.getJson('/sales/$id'));

  Future<SaleDetail> recordPayment(
    String saleId, {
    required Decimal amount,
    required PaymentMethod method,
  }) async {
    final sale = SaleDetail.fromJson(
      await _api.postJson(
        '/sales/$saleId/payments',
        body: {'amount': amount.toString(), 'method': method.apiValue},
      ),
    );
    notifyChanged();
    return sale;
  }

  Future<PendingPayments> pending() async =>
      PendingPayments.fromJson(await _api.getJson('/payments/pending'));
}
