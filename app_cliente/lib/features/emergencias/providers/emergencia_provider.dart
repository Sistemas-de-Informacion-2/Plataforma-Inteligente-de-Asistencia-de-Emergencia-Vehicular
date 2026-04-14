import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:app_cliente/core/network/api_client.dart';
import 'package:app_cliente/features/emergencias/models/incidente_response_model.dart';

class EmergenciaProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  bool isUploading = false;
  String errorMessage = '';
  bool advertirArchivosBorrados = false;
  IncidenteResponseModel? ultimoIncidente;

  Future<IncidenteResponseModel?> enviarEmergencia({
    required int? vehiculoId,
    required double latitud,
    required double longitud,
    String? descripcion,
    List<File> imagenes = const [],
    File? audio,
  }) async {
    isUploading = true;
    errorMessage = '';
    advertirArchivosBorrados = false;
    ultimoIncidente = null;
    notifyListeners();

    try {
      // Usar FormData para enviar archivos y texto mixto
      var formData = FormData.fromMap({
        'latitud': latitud.toString(),
        'longitud': longitud.toString(),
      });

      if (vehiculoId != null) {
        formData.fields.add(MapEntry('vehiculo_id', vehiculoId.toString()));
      }
      if (descripcion != null && descripcion.trim().isNotEmpty) {
        formData.fields.add(MapEntry('descripcion', descripcion.trim()));
      }

      // Adjuntar imágenes
      List<File> imagenesValidas = [];
      for (var file in imagenes) {
        if (await file.exists()) {
          imagenesValidas.add(file);
          formData.files.add(MapEntry(
            'imagenes',
            await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last),
          ));
        } else {
          advertirArchivosBorrados = true;
        }
      }

      // Adjuntar audio
      if (audio != null) {
        if (await audio.exists()) {
          formData.files.add(MapEntry(
            'audio',
            await MultipartFile.fromFile(audio.path, filename: audio.uri.pathSegments.last),
          ));
        } else {
          audio = null;
          advertirArchivosBorrados = true;
        }
      }

      final response = await _apiClient.instance.post(
        '/incidentes/',
        data: formData,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        isUploading = false;
        ultimoIncidente = IncidenteResponseModel.fromJson(response.data);
        notifyListeners();
        return ultimoIncidente;
      }
    } on DioException catch (e) {
      errorMessage = 'Error al enviar emergencia: ${e.message}';
    } catch (e) {
      errorMessage = 'Error inesperado al enviar: $e';
    }

    isUploading = false;
    notifyListeners();
    return null;
  }
}
