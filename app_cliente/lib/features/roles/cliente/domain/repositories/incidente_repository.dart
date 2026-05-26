import 'dart:io';
import '../entities/recomendacion_result.dart';

/// Contrato abstracto del repositorio de incidentes.
/// Define las operaciones que la capa de datos debe implementar.
abstract class IncidenteRepository {
  /// Envía el reporte de emergencia (SOS) al backend como multipart form.
  /// Retorna un [RecomendacionResult] con la solicitud, diagnóstico IA
  /// y la lista de sucursales recomendadas.
  Future<RecomendacionResult> reportarEmergencia({
    required int? vehiculoId,
    required double latitud,
    required double longitud,
    String? descripcion,
    List<File> imagenes,
    File? audio,
  });

  /// Envía la elección del cliente al backend.
  /// POST /api/v1/incidentes/{solicitudId}/seleccionar-taller
  /// Retorna `true` si la selección fue exitosa.
  Future<bool> seleccionarTaller({
    required int solicitudId,
    required int sucursalId,
  });

  /// Obtiene los detalles de un incidente (incluyendo la asignación)
  Future<Map<String, dynamic>?> obtenerDetalleIncidente(int solicitudId);
}
