import '../../../core/api/api_client.dart';
import '../../../core/data_changes.dart';
import '../../../core/format/dates.dart';
import '../domain/expense.dart';

class ExpenseRepository with DataChanges {
  ExpenseRepository(this._api);

  static const _maxShown = 500;

  final ApiClient _api;

  Future<ExpenseList> list({required DateTime firstDay, required DateTime lastDay}) async =>
      ExpenseList.fromJson(
        await _api.getJson(
          '/expenses',
          query: {
            'date_from': apiDate(firstDay),
            'date_to': apiDate(lastDay),
            'limit': _maxShown,
          },
        ),
      );

  Future<void> create(ExpenseInput input) async {
    await _api.postJson('/expenses', body: input.toJson());
    notifyChanged();
  }

  Future<void> delete(String id) async {
    await _api.delete('/expenses/$id');
    notifyChanged();
  }
}
