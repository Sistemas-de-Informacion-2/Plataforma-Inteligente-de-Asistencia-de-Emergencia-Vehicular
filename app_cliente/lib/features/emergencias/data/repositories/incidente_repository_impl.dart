import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fixo/core/network/api_client.dart';
import 'package:fixo/features/emergencias/domain/entities/recomendacion_result.dart';
import 'package:fixo/features/emergencias/domain/repositories/incidente_repository.dart';
import 'package:fixo/features/emergencias/data/models/recomendacion_result_model.dart';

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
}
