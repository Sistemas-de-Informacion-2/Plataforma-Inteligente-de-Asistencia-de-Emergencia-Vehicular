import 'package:fixo/features/emergencias/domain/entities/sucursal_recomendada.dart';

/// Modelo de datos con deserialización JSON para [SucursalRecomendada].
/// Mapea directamente al schema `SucursalRecomendada` del backend.
class SucursalRecomendadaModel extends SucursalRecomendada {
  const SucursalRecomendadaModel({
    required super.id,
    required super.nombre,
    super.direccion,
    super.telefono,
    required super.latitud,
    required super.longitud,
    required super.tallerId,
    required super.tallerNombre,
    required super.distanciaKm,
    required super.tieneServicio,
    required super.tecnicosDisponibles,
    required super.score,
    required super.etaMinutos,
    required super.rating,
    required super.ratingCount,
  });

  factory SucursalRecomendadaModel.fromJson(Map<String, dynamic> json) {
    return SucursalRecomendadaModel(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      tallerId: json['taller_id'] as int,
      tallerNombre: json['taller_nombre'] as String,
      distanciaKm: (json['distancia_km'] as num).toDouble(),
      tieneServicio: json['tiene_servicio'] as bool,
      tecnicosDisponibles: json['tecnicos_disponibles'] as int,
      score: (json['score'] as num).toDouble(),
      etaMinutos: json['eta_minutos'] as int? ?? 15,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] as int? ?? 0,
    );
  }
}
