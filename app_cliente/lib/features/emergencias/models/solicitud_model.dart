class SolicitudModel {
  final int? id;
  final int? clienteId;
  final int? vehiculoId;
  final double? latitud;
  final double? longitud;
  final String? descripcion;
  final String? estado;
  final String? fechaCreacion;

  SolicitudModel({
    this.id,
    this.clienteId,
    this.vehiculoId,
    this.latitud,
    this.longitud,
    this.descripcion,
    this.estado,
    this.fechaCreacion,
  });

  factory SolicitudModel.fromJson(Map<String, dynamic> json) {
    return SolicitudModel(
      id: json['id'] as int?,
      clienteId: json['cliente_id'] as int?,
      vehiculoId: json['vehiculo_id'] as int?,
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
      descripcion: json['descripcion'] as String?,
      estado: json['estado'] as String?,
      fechaCreacion: json['fecha_creacion'] as String?,
    );
  }
}
