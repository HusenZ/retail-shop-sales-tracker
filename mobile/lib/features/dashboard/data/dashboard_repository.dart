import '../../../core/api/api_client.dart';
import '../domain/dashboard.dart';

class DashboardRepository {
  DashboardRepository(this._api);

  final ApiClient _api;

  Future<Dashboard> load() async => Dashboard.fromJson(await _api.getJson('/dashboard'));
}
