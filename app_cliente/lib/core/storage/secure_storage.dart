import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';

  // Guardar token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // Leer token
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Borrar token (Logout)
  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }
}
