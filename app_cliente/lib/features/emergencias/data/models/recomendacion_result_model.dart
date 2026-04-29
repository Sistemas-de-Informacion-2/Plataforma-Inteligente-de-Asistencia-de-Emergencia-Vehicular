import 'package:fixo/features/emergencias/models/solicitud_model.dart';
import 'package:fixo/features/emergencias/models/diagnostico_model.dart';
import 'package:fixo/features/emergencias/domain/entities/recomendacion_result.dart';
import 'package:fixo/features/emergencias/data/models/sucursal_recomendada_model.dart';

/// Modelo de datos con deserialización JSON para [RecomendacionResult].
/// Parsea la respuesta completa `SolicitudRecomendacionOut` del backend.
class RecomendacionResultModel extends RecomendacionResult {
  RecomendacionResultModel({
    required super.solicitud,
    required super.diagnosticoIa,
    required super.sucursalesRecomendadas,
  });

  factory RecomendacionResultModel.fromJson(Map<String, dynamic> json) {
    // Parsear la solicitud
    final solicitud = SolicitudModel.fromJson(
      json['solicitud'] as Map<String, dynamic>,
    );

    // Parsear el diagnóstico IA (key = 'diagnostico_ia' en el backend)
    final diagnosticoIa = DiagnosticoModel.fromJson(
      json['diagnostico_ia'] as Map<String, dynamic>,
    );

    // Parsear la lista de sucursales recomendadas
    final sucursalesJson = json['sucursales_recomendadas'] as List<dynamic>? ?? [];
    final sucursales = sucursalesJson
        .map((s) => SucursalRecomendadaModel.fromJson(s as Map<String, dynamic>))
        .toList();

    return RecomendacionResultModel(
      solicitud: solicitud,
      diagnosticoIa: diagnosticoIa,
      sucursalesRecomendadas: sucursales,
    );
  }
}
