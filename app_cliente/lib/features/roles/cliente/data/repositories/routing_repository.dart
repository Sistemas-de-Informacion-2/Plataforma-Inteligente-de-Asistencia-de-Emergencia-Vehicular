import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../../core/network/api_client.dart';

class RoutingRepository {
  final ApiClient _apiClient = ApiClient();

  /// Obtiene la ruta entre dos puntos llamando a nuestro backend (proxy a OSRM).
  Future<Map<String, dynamic>?> obtenerRuta({
    required double lng1,
    required double lat1,
    required double lng2,
    required double lat2,
  }) async {
    try {
      final response = await _apiClient.instance.get(
        '/rutas/',
        queryParameters: {
          'lng1': lng1,
          'lat1': lat1,
          'lng2': lng2,
          'lat2': lat2,
        },
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
    } on DioException catch (e) {
      debugPrint('[RoutingRepo] Error obteniendo ruta: ${e.message}');
    }
    return null;
  }
}
