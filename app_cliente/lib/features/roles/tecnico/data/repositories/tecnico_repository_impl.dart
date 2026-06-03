import '../../domain/entities/asignacion_entity.dart';
import '../../domain/repositories/tecnico_repository.dart';
import '../datasources/tecnico_datasource.dart';

class TecnicoRepositoryImpl implements TecnicoRepository {
  final TecnicoDatasource datasource;

  TecnicoRepositoryImpl(this.datasource);

  @override
  Future<AsignacionEntity> responderAsignacion({
    required int asignacionId,
    required bool aceptar,
    String? motivoRechazo,
  }) async {
    final asignacionMap = await datasource.responderAsignacion(asignacionId, aceptar, motivoRechazo);
    final solicitudId = asignacionMap['solicitud_id'];
    final solicitudMap = await datasource.obtenerSolicitud(solicitudId);
    return AsignacionEntity.fromSolicitudMap(asignacionMap, solicitudMap);
  }

  @override
  Future<AsignacionEntity> obtenerDetalleSolicitud({
    required int solicitudId,
    required int asignacionId,
  }) async {
    final solicitudMap = await datasource.obtenerSolicitud(solicitudId);
    // Como no tenemos el mapa completo de asignación del endpoint get_solicitud, 
    // construimos uno mínimo o lo buscamos dentro si viene.
    final asignaciones = solicitudMap['asignaciones'] as List<dynamic>? ?? [];
    final asignacionMap = asignaciones.firstWhere(
      (a) => a['id'] == asignacionId, 
      orElse: () => {'id': asignacionId, 'solicitud_id': solicitudId, 'estado': 'PENDIENTE'}
    );

    return AsignacionEntity.fromSolicitudMap(asignacionMap, solicitudMap);
  }

  @override
  Future<AsignacionEntity> marcarLlegada({required int asignacionId}) async {
    final asignacionMap = await datasource.marcarLlegada(asignacionId);
    final solicitudId = asignacionMap['solicitud_id'];
    final solicitudMap = await datasource.obtenerSolicitud(solicitudId);
    return AsignacionEntity.fromSolicitudMap(asignacionMap, solicitudMap);
  }

  @override
  Future<AsignacionEntity?> obtenerAsignacionActiva() async {
    final asignacionMap = await datasource.obtenerAsignacionActiva();
    if (asignacionMap == null) return null;
    
    final solicitudId = asignacionMap['solicitud_id'];
    final solicitudMap = await datasource.obtenerSolicitud(solicitudId);
    return AsignacionEntity.fromSolicitudMap(asignacionMap, solicitudMap);
  }

  @override
  Future<List<AsignacionEntity>> obtenerHistorial() async {
    final listDynamic = await datasource.obtenerHistorial();
    List<AsignacionEntity> result = [];
    for (var asignacionMap in listDynamic) {
      final solicitudMap = asignacionMap['solicitud'];
      if (solicitudMap != null) {
        result.add(AsignacionEntity.fromSolicitudMap(asignacionMap, solicitudMap));
      } else {
        // En caso de que no venga la relación completa, hacemos fetch individual (no debería pasar con el nuevo endpoint)
        final sId = asignacionMap['solicitud_id'];
        final sMap = await datasource.obtenerSolicitud(sId);
        result.add(AsignacionEntity.fromSolicitudMap(asignacionMap, sMap));
      }
    }
    return result;
  }

  @override
  Future<void> enviarUbicacion({
    required int asignacionId,
    required double latitud,
    required double longitud,
  }) async {
    await datasource.enviarUbicacion(asignacionId, latitud, longitud);
  }

  @override
  Future<AsignacionEntity> finalizarTrabajo({
    required int asignacionId,
    required double montoTotal,
  }) async {
    final asignacionMap = await datasource.finalizarTrabajo(asignacionId, montoTotal);
    final solicitudId = asignacionMap['solicitud_id'];
    final solicitudMap = await datasource.obtenerSolicitud(solicitudId);
    return AsignacionEntity.fromSolicitudMap(asignacionMap, solicitudMap);
  }
}
