import 'package:dio/dio.dart';

abstract class TecnicoDatasource {
  Future<Map<String, dynamic>> responderAsignacion(int asignacionId, bool aceptar, String? motivo);
  Future<Map<String, dynamic>> obtenerSolicitud(int solicitudId);
  Future<Map<String, dynamic>> marcarLlegada(int asignacionId);
  Future<Map<String, dynamic>?> obtenerAsignacionActiva();
  Future<List<dynamic>> obtenerHistorial();
  Future<void> enviarUbicacion(int asignacionId, double latitud, double longitud);
  Future<Map<String, dynamic>> finalizarTrabajo(int asignacionId, double montoTotal);
}

class TecnicoDatasourceImpl implements TecnicoDatasource {
  final Dio dio;

  TecnicoDatasourceImpl(this.dio);

  @override
  Future<Map<String, dynamic>> responderAsignacion(int asignacionId, bool aceptar, String? motivo) async {
    final response = await dio.post(
      '/asignaciones/$asignacionId/respuesta',
      data: {
        'aceptar': aceptar,
        if (motivo != null && motivo.isNotEmpty) 'motivo_rechazo': motivo,
      },
    );
    return response.data;
  }

  @override
  Future<Map<String, dynamic>> obtenerSolicitud(int solicitudId) async {
    final response = await dio.get('/solicitudes/$solicitudId');
    return response.data;
  }

  @override
  Future<Map<String, dynamic>> marcarLlegada(int asignacionId) async {
    final response = await dio.post('/asignaciones/$asignacionId/llegada');
    return response.data;
  }

  @override
  Future<Map<String, dynamic>?> obtenerAsignacionActiva() async {
    try {
      final response = await dio.get('/asignaciones/me/activa');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> obtenerHistorial() async {
    final response = await dio.get('/asignaciones/me/historial');
    return response.data;
  }

  @override
  Future<void> enviarUbicacion(int asignacionId, double latitud, double longitud) async {
    await dio.post(
      '/asignaciones/$asignacionId/ubicacion',
      data: {
        'latitud': latitud,
        'longitud': longitud,
      },
    );
  }

  @override
  Future<Map<String, dynamic>> finalizarTrabajo(int asignacionId, double montoTotal) async {
    final response = await dio.post(
      '/asignaciones/$asignacionId/finalizar',
      data: {
        'monto_total': montoTotal,
      },
    );
    return response.data;
  }
}
