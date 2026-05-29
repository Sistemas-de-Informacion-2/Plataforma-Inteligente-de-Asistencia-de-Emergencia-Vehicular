import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../../core/network/api_client.dart';
import '../../domain/entities/recomendacion_result.dart';
import '../../domain/repositories/incidente_repository.dart';
import '../models/recomendacion_result_model.dart';

/// Implementación concreta del [IncidenteRepository].
/// Usa [ApiClient] (Dio) para comunicarse con el backend.
class IncidenteRepositoryImpl implements IncidenteRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<RecomendacionResult> reportarEmergencia({
    required int? vehiculoId,
    required double latitud,
    required double longitud,
    String? descripcion,
    List<File> imagenes = const [],
    File? audio,
  }) async {
    // Construir FormData para el envío multipart
    final formData = FormData.fromMap({
      'latitud': latitud.toString(),
      'longitud': longitud.toString(),
    });

    if (vehiculoId != null) {
      formData.fields.add(MapEntry('vehiculo_id', vehiculoId.toString()));
    }
    if (descripcion != null && descripcion.trim().isNotEmpty) {
      formData.fields.add(MapEntry('descripcion', descripcion.trim()));
    }

    // Adjuntar imágenes (solo las que existan en disco)
    for (final file in imagenes) {
      if (await file.exists()) {
        formData.files.add(MapEntry(
          'imagenes',
          await MultipartFile.fromFile(
            file.path,
            filename: file.uri.pathSegments.last,
          ),
        ));
      }
    }

    // Adjuntar audio
    if (audio != null && await audio.exists()) {
      formData.files.add(MapEntry(
        'audio',
        await MultipartFile.fromFile(
          audio.path,
          filename: audio.uri.pathSegments.last,
        ),
      ));
    }

    final response = await _apiClient.instance.post(
      '/incidentes/',
      data: formData,
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return RecomendacionResultModel.fromJson(response.data);
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      message: 'Error inesperado: código ${response.statusCode}',
    );
  }

  @override
  Future<bool> seleccionarTaller({
    required int solicitudId,
    required int sucursalId,
  }) async {
    try {
      final response = await _apiClient.instance.post(
        '/incidentes/$solicitudId/seleccionar-taller',
        data: {'sucursal_id': sucursalId},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint('[IncidenteRepo] Error seleccionando taller: ${e.message}');
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> seleccionarPuja({
    required int solicitudId,
    required int pujaId,
  }) async {
    try {
      final response = await _apiClient.instance.post(
        '/incidentes/$solicitudId/seleccionar-puja',
        data: {'puja_id': pujaId},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Error al seleccionar la puja: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['detail'] ?? e.message;
      throw Exception('Error de red al aceptar oferta: $errorMessage');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  @override
  Future<void> rechazarPuja({
    required int pujaId,
  }) async {
    try {
      final response = await _apiClient.instance.post(
        '/pujas/$pujaId/rechazar',
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error al rechazar la puja: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['detail'] ?? e.message;
      throw Exception('Error de red al rechazar oferta: $errorMessage');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> obtenerDetalleIncidente(int solicitudId) async {
    try {
      final response = await _apiClient.instance.get('/incidentes/$solicitudId');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
    } on DioException catch (e) {
      debugPrint('[IncidenteRepo] Error obteniendo detalle: ${e.message}');
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> obtenerSolicitudActiva() async {
    try {
      final response = await _apiClient.instance.get('/incidentes/activa');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) {
        debugPrint('[IncidenteRepo] Error obteniendo activa: ${e.message}');
      }
    } catch (e) {
      debugPrint('[IncidenteRepo] Excepción obteniendo activa: $e');
    }
    return null;
  }

  @override
  Future<void> cancelarSolicitud(int solicitudId) async {
    try {
      final response = await _apiClient.instance.post('/incidentes/$solicitudId/cancelar');
      if (response.statusCode != 200) {
        throw Exception('Error al cancelar: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage = e.response?.data['detail'] ?? e.message;
      throw Exception('Error al cancelar: $errorMessage');
    } catch (e) {
      throw Exception('Error inesperado al cancelar: $e');
    }
  }
}
