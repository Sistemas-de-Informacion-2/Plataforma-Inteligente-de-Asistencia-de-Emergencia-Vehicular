class AsignacionEntity {
  final int id;
  final int solicitudId;
  final String estado;
  final String problemaDetectado;
  final String clienteNombre;
  final String vehiculoInfo;
  final double? distanciaKm;
  final double? latitud;
  final double? longitud;
  final String? motivoRechazo;
  final int? clienteId;

  AsignacionEntity({
    required this.id,
    required this.solicitudId,
    required this.estado,
    required this.problemaDetectado,
    required this.clienteNombre,
    required this.vehiculoInfo,
    this.distanciaKm,
    this.latitud,
    this.longitud,
    this.motivoRechazo,
    this.clienteId,
  });

  factory AsignacionEntity.fromSolicitudMap(Map<String, dynamic> asignacionMap, Map<String, dynamic> solicitudMap) {
    final diagnostico = solicitudMap['diagnostico'] ?? {};
    final vehiculo = solicitudMap['vehiculo'] ?? {};
    final cliente = solicitudMap['cliente'] ?? {}; // Asumiendo que el cliente podría venir anidado o omitido

    return AsignacionEntity(
      id: asignacionMap['id'],
      solicitudId: asignacionMap['solicitud_id'] ?? solicitudMap['id'],
      estado: asignacionMap['estado'],
      problemaDetectado: diagnostico['problema_detectado'] ?? solicitudMap['descripcion'] ?? 'Emergencia General',
      clienteNombre: cliente['nombre_completo'] ?? 'Cliente #${solicitudMap['cliente_id'] ?? ''}',
      vehiculoInfo: '${vehiculo['marca'] ?? 'Auto'} ${vehiculo['modelo'] ?? ''} - ${vehiculo['placa'] ?? ''}'.trim(),
      distanciaKm: null, // Si no viene, se calcula o se usa otro campo
      latitud: (solicitudMap['latitud'] is num) ? (solicitudMap['latitud'] as num).toDouble() : null,
      longitud: (solicitudMap['longitud'] is num) ? (solicitudMap['longitud'] as num).toDouble() : null,
      motivoRechazo: asignacionMap['motivo_rechazo'],
      clienteId: solicitudMap['cliente_id'],
    );
  }
}
