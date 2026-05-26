class DiagnosticoModel {
  final int? id;
  final int? solicitudId;
  final String? problemaDetectado;
  final String? nivelGravedad;
  final String? prioridad;
  final double? costoEstimadoIa;

  DiagnosticoModel({
    this.id,
    this.solicitudId,
    this.problemaDetectado,
    this.nivelGravedad,
    this.prioridad,
    this.costoEstimadoIa,
  });

  factory DiagnosticoModel.fromJson(Map<String, dynamic> json) {
    return DiagnosticoModel(
      id: json['id'] as int?,
      solicitudId: json['solicitud_id'] as int?,
      problemaDetectado: json['problema_detectado'] as String?,
      nivelGravedad: json['nivel_gravedad'] as String?,
      prioridad: json['prioridad'] as String?,
      costoEstimadoIa: (json['costo_estimado_ia'] as num?)?.toDouble(),
    );
  }
}
