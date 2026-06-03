import '../entities/asignacion_entity.dart';

abstract class TecnicoRepository {
  Future<AsignacionEntity> responderAsignacion({
    required int asignacionId,
    required bool aceptar,
    String? motivoRechazo,
  });

  Future<AsignacionEntity> marcarLlegada({
    required int asignacionId,
  });

  Future<AsignacionEntity> obtenerDetalleSolicitud({
    required int solicitudId,
    required int asignacionId,
  });

  Future<AsignacionEntity?> obtenerAsignacionActiva();

  Future<List<AsignacionEntity>> obtenerHistorial();

  Future<void> enviarUbicacion({
    required int asignacionId,
    required double latitud,
    required double longitud,
  });

  Future<AsignacionEntity> finalizarTrabajo({
    required int asignacionId,
    required double montoTotal,
  });
}
