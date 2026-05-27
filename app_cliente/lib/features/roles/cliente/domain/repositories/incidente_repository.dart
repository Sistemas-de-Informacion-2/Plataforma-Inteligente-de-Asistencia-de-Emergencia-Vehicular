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

  /// Envía la elección de la puja ganadora por parte del cliente.
  /// POST /api/v1/incidentes/{solicitudId}/seleccionar-puja
  /// Retorna un mapa con los datos de la asignación y la sucursal.
  Future<Map<String, dynamic>> seleccionarPuja({
    required int solicitudId,
    required int pujaId,
  });

  /// Obtiene los detalles de un incidente (incluyendo la asignación)
  Future<Map<String, dynamic>?> obtenerDetalleIncidente(int solicitudId);
}
