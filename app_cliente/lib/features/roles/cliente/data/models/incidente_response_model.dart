import 'solicitud_model.dart';
import 'diagnostico_model.dart';
import 'asignacion_model.dart';

class IncidenteResponseModel {
  final SolicitudModel? solicitud;
  final DiagnosticoModel? diagnostico;
  final AsignacionModel? asignacionResultado;
  final List<dynamic>? evidencias;

  IncidenteResponseModel({
    this.solicitud,
    this.diagnostico,
    this.asignacionResultado,
    this.evidencias,
  });

  factory IncidenteResponseModel.fromJson(Map<String, dynamic> json) {
    return IncidenteResponseModel(
      solicitud: json['solicitud'] != null
          ? SolicitudModel.fromJson(json['solicitud'])
          : null,
      diagnostico: json['diagnostico'] != null
          ? DiagnosticoModel.fromJson(json['diagnostico'])
          : null,
      asignacionResultado: json['asignacion_resultado'] != null
          ? AsignacionModel.fromJson(json['asignacion_resultado'])
          : null,
      evidencias: json['evidencias'] as List<dynamic>?,
    );
  }
}
