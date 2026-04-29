import 'package:fixo/features/emergencias/domain/repositories/incidente_repository.dart';

/// Caso de uso: Seleccionar Taller.
/// Envía la elección del cliente al backend para confirmar
/// qué sucursal atenderá la emergencia.
class SeleccionarTallerUseCase {
  final IncidenteRepository _repository;

  SeleccionarTallerUseCase(this._repository);

  Future<bool> call({
    required int solicitudId,
    required int sucursalId,
  }) {
    return _repository.seleccionarTaller(
      solicitudId: solicitudId,
      sucursalId: sucursalId,
    );
  }
}
