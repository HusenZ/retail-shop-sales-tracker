import '../../../core/api/api_client.dart';
import '../../../core/format/dates.dart';
import '../domain/report.dart';

class ReportRepository {
  ReportRepository(this._api);

  final ApiClient _api;

  /// Both days are included.
  Future<ReportSummary> summary({required DateTime firstDay, required DateTime lastDay}) async =>
      ReportSummary.fromJson(
        await _api.getJson(
          '/reports/summary',
          query: {'date_from': apiDate(firstDay), 'date_to': apiDate(lastDay)},
        ),
      );
}
