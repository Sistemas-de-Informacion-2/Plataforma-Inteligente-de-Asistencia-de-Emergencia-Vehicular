import '../../data/models/solicitud_model.dart';
import '../../data/models/diagnostico_model.dart';
import 'sucursal_recomendada.dart';

/// Resultado completo del flujo de emergencia Fase 1.
/// Contiene la solicitud creada, el diagnóstico de IA,
/// y la lista de sucursales recomendadas para que el cliente elija.
class RecomendacionResult {
  final SolicitudModel solicitud;
  final DiagnosticoModel diagnosticoIa;
  final List<SucursalRecomendada> sucursalesRecomendadas;

  const RecomendacionResult({
    required this.solicitud,
    required this.diagnosticoIa,
    required this.sucursalesRecomendadas,
  });
}
