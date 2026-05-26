import 'dart:io';
import '../entities/recomendacion_result.dart';
import '../repositories/incidente_repository.dart';

/// Caso de uso: Reportar Emergencia (SOS).
/// Envía el formulario multipart al backend y retorna
/// la lista de recomendaciones de talleres.
class ReportarEmergenciaUseCase {
  final IncidenteRepository _repository;

  ReportarEmergenciaUseCase(this._repository);

  Future<RecomendacionResult> call({
    required int? vehiculoId,
    required double latitud,
    required double longitud,
    String? descripcion,
    List<File> imagenes = const [],
    File? audio,
  }) {
    return _repository.reportarEmergencia(
      vehiculoId: vehiculoId,
      latitud: latitud,
      longitud: longitud,
      descripcion: descripcion,
      imagenes: imagenes,
      audio: audio,
    );
  }
}
