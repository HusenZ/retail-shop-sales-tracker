import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStorage _tokens;

  Future<bool> hasSavedSession() async => await _tokens.read() != null;

  Future<User> login({required String email, required String password}) =>
      _authenticate('/auth/login', {'email': email, 'password': password});

  Future<User> register({
    required String fullName,
    required String email,
    required String password,
  }) =>
      _authenticate('/auth/register', {
        'full_name': fullName,
        'email': email,
        'password': password,
      });

  Future<User> currentUser() async => User.fromJson(await _api.getJson('/auth/me'));

  /// Logging out only forgets the token; the server keeps no session.
  Future<void> logout() => _tokens.clear();

  Future<User> _authenticate(String path, Json body) async {
    final json = await _api.postJson(path, body: body);
    await _tokens.write(json['access_token'] as String);
    return User.fromJson(json['user'] as Json);
  }
}
