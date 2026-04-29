/// Entidad de dominio: Sucursal candidata con metadata de ranking.
/// Mapeada al schema `SucursalRecomendada` del backend.
class SucursalRecomendada {
  final int id;
  final String nombre;
  final String? direccion;
  final String? telefono;
  final double latitud;
  final double longitud;
  final int tallerId;
  final String tallerNombre;
  final double distanciaKm;
  final bool tieneServicio;
  final int tecnicosDisponibles;
  final double score;
  final int etaMinutos;
  final double rating;
  final int ratingCount;

  const SucursalRecomendada({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    required this.latitud,
    required this.longitud,
    required this.tallerId,
    required this.tallerNombre,
    required this.distanciaKm,
    required this.tieneServicio,
    required this.tecnicosDisponibles,
    required this.score,
    required this.etaMinutos,
    required this.rating,
    required this.ratingCount,
  });
}
