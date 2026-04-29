import 'package:dio/dio.dart';
import 'package:fixo/core/config/environment.dart';
import 'package:fixo/core/storage/secure_storage.dart';

class ApiClient {
  late Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: Environment.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );

    // Añadir el interceptor de tokens
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Obtener el token del storage
          final token = await SecureStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          options.headers['Accept'] = 'application/json';
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // El token expiró o es inválido
            await SecureStorage.deleteToken();
            // TODO: Podríamos disparar un evento global o usar navigatorKey para redirigir al Login acá, 
            // pero lo manejaremos desde el AuthProvider para limpiar el estado
          }
          return handler.next(e);
        },
      ),
    );

    // Logger Interceptor (útil en desarrollo)
    if (!Environment.isProduccion) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: true,
      ));
    }
  }

  Dio get instance => dio;
}
