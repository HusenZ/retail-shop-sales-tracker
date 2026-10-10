import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the login token in the device keystore, cached in memory after the first read.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'access_token';

  final FlutterSecureStorage _storage;
  String? _token;
  bool _loaded = false;

  Future<String?> read() async {
    if (!_loaded) {
      _token = await _storage.read(key: _key);
      _loaded = true;
    }
    return _token;
  }

  Future<void> write(String token) async {
    _token = token;
    _loaded = true;
    await _storage.write(key: _key, value: token);
  }

  Future<void> clear() async {
    _token = null;
    _loaded = true;
    await _storage.delete(key: _key);
  }
}
