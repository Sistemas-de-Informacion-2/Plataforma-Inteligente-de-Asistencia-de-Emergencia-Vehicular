import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/network/push_notification_service.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  AuthStatus authStatus = AuthStatus.checking;
  String errorMessage = '';
  int? _userId;
  String? userRole;

  /// ID del usuario autenticado (cargado desde /usuarios/me).
  int? get userId => _userId;

  AuthProvider() {
    checkAuthStatus();
  }

  // Verifica si el token existe al abrir la app o si sigue siendo válido
  Future<void> checkAuthStatus() async {
    final token = await SecureStorage.getToken();
    if (token == null) {
      authStatus = AuthStatus.unauthenticated;
      userRole = null;
      notifyListeners();
      return;
    }

    _extractRoleFromToken(token);


    try {
      // Opcional: Podría llamar a /usuarios/me si queremos validar el token y traer datos del usuario.
      // Por ahora, si hay token, asumimos autenticado hasta que una llamada falle por 401.
      final response = await _apiClient.instance.get('/usuarios/me');
      if (response.statusCode == 200) {
        _userId = response.data['id'] as int?;
        authStatus = AuthStatus.authenticated;
        // Registrar token FCM tras confirmar autenticación
        PushNotificationService.registrarTokenEnBackend();
      } else {
        await logout();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
      } else {
        // Error de red, pero el token existe. Asumimos autenticado offline por ahora
        authStatus = AuthStatus.authenticated;
      }
    } catch (e) {
      authStatus = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  // Login
  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiClient.instance.post(
        '/auth/login',
        data: {
          'username': email,
          'password': password,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.statusCode == 200) {
        final token = response.data['access_token'];
        await SecureStorage.saveToken(token);
        
        _extractRoleFromToken(token);
        authStatus = AuthStatus.authenticated;
        errorMessage = '';
        notifyListeners();
        // Registrar token FCM tras login exitoso
        PushNotificationService.registrarTokenEnBackend();
        return true;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        errorMessage = 'Credenciales incorrectas';
      } else {
        errorMessage = 'Error de conexión: ${e.message}';
      }
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error inesperado';
      notifyListeners();
    }
    return false;
  }

  // Registro
  Future<bool> registro({
    required String nombre,
    required String email,
    required String password,
    required String ci,
    String? telefono,
  }) async {
    try {
      final data = {
        'nombre': nombre,
        'email': email,
        'password': password,
        'ci': ci,
      };
      
      if (telefono != null && telefono.isNotEmpty) {
        data['telefono'] = telefono;
      }

      final response = await _apiClient.instance.post(
        '/usuarios/',
        data: data,
        options: Options(
          contentType: Headers.jsonContentType,
        ),
      );

      if (response.statusCode == 201) {
        // Registro exitoso, podríamos desear iniciar sesión automáticamente, pero por ahora sólo notificamos
        errorMessage = '';
        return true;
      }
    } on DioException catch (e) {
        if (e.response?.statusCode == 400) {
            errorMessage = e.response?.data['detail'] ?? 'El usuario ya existe';
        } else {
            errorMessage = 'Error de conexión';
        }
        notifyListeners();
    } catch (e) {
      errorMessage = 'Error inesperado';
      notifyListeners();
    }
    return false;
  }

  // Logout
  Future<void> logout() async {
    await SecureStorage.deleteToken();
    _userId = null;
    userRole = null;
    authStatus = AuthStatus.unauthenticated;
    errorMessage = '';
    notifyListeners();
  }

  void _extractRoleFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return;
      final payload = parts[1];
      var normalized = base64Url.normalize(payload);
      var resp = utf8.decode(base64Url.decode(normalized));
      final decodedMap = json.decode(resp);
      // Suponemos que el JWT de FastAPI contiene el rol bajo 'rol' o similar.
      // Dependiendo de tu payload, ajusta esta llave:
      userRole = decodedMap['rol'] ?? decodedMap['role'] ?? 'CLIENTE';
    } catch (e) {
      userRole = 'CLIENTE'; // default
    }
  }
}
