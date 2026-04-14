class AsignacionModel {
  final Map<String, dynamic>? sucursal;
  final Map<String, dynamic>? tecnicoAsignado;
  final double? distanciaKm;
  final double? tiempoEstimado;

  AsignacionModel({
    this.sucursal,
    this.tecnicoAsignado,
    this.distanciaKm,
    this.tiempoEstimado,
  });

  factory AsignacionModel.fromJson(Map<String, dynamic> json) {
    return AsignacionModel(
      sucursal: json['sucursal'] as Map<String, dynamic>?,
      tecnicoAsignado: json['tecnico_asignado'] as Map<String, dynamic>?,
      distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
      tiempoEstimado: (json['tiempo_estimado'] as num?)?.toDouble(),
    );
  }
}
