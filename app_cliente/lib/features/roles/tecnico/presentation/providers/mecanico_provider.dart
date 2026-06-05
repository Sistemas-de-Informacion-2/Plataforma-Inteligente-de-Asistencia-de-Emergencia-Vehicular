import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/websocket_service.dart';
import '../../../../../core/utils/polyline_decoder.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/asignacion_entity.dart';
import '../../domain/repositories/tecnico_repository.dart';
import '../../data/datasources/tecnico_datasource.dart';
import '../../data/repositories/tecnico_repository_impl.dart';
import '../../data/repositories/routing_repository.dart';

enum MecanicoStateStatus { idle, sosRecibido, enRuta, enSitio }

class MecanicoState {
  final MecanicoStateStatus status;
  final AsignacionEntity? asignacion;
  final List<AsignacionEntity> historial;
  final bool isLoading;
  final String? error;
  final List<LatLng> polylineCoords;

  MecanicoState({
    this.status = MecanicoStateStatus.idle,
    this.asignacion,
    this.historial = const [],
    this.isLoading = false,
    this.error,
    this.polylineCoords = const [],
  });

  MecanicoState copyWith({
    MecanicoStateStatus? status,
    AsignacionEntity? asignacion,
    List<AsignacionEntity>? historial,
    bool? isLoading,
    String? error,
    List<LatLng>? polylineCoords,
  }) {
    return MecanicoState(
      status: status ?? this.status,
      asignacion: asignacion ?? this.asignacion,
      historial: historial ?? this.historial,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      polylineCoords: polylineCoords ?? this.polylineCoords,
    );
  }
}

// Provider del repositorio
final tecnicoRepositoryProvider = Provider<TecnicoRepository>((ref) {
  final dio = ApiClient().instance;
  final datasource = TecnicoDatasourceImpl(dio);
  return TecnicoRepositoryImpl(datasource);
});

// Provider del WebSocket
final mecanicoWsProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

class MecanicoNotifier extends Notifier<MecanicoState> {
  Timer? _locationTimer;
  final RoutingRepository _routingRepository = RoutingRepository();
  final Distance _distanceCalc = const Distance();

  @override
  MecanicoState build() {
    return MecanicoState();
  }

  void connectWebSocket() {
    final ws = ref.read(mecanicoWsProvider);
    ws.connect();
    ws.messageStream.listen((data) {
      try {
        if (data['type'] == 'NUEVA_ASIGNACION_TECNICO') {
          final asignacionId = data['asignacion_id'];
          final solicitudId = data['solicitud_id'];
          _fetchAsignacionDetails(solicitudId, asignacionId);
          fetchHistorial();
        } else if (data['type'] == 'ASIGNACION_TIMEOUT') {
          // Si el servidor cancela nuestra asignación actual por timeout, volvemos a idle
          final asignacionId = data['asignacion_id'];
          if (state.asignacion?.id == asignacionId) {
            state = state.copyWith(status: MecanicoStateStatus.idle, asignacion: null);
            fetchHistorial();
          }
        }
      } catch (e) {
        debugPrint("Error procesando WS Mecanico: $e");
      }
    });
  }

  Future<void> fetchHistorial() async {
    try {
      final repo = ref.read(tecnicoRepositoryProvider);
      final list = await repo.obtenerHistorial();
      state = state.copyWith(historial: list);
    } catch (e) {
      debugPrint("Error obteniendo historial: $e");
    }
  }

  bool _isTrackingLocation = false;

  void _startLocationTracking() async {
    if (_isTrackingLocation) return;
    _isTrackingLocation = true;
    _stopLocationTracking();
    
    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _isTrackingLocation = false;
        return;
      }
    }

    _stopLocationTracking(); // Limpiar por si acaso hubo una llamada paralela
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (state.asignacion == null || state.status != MecanicoStateStatus.enRuta) {
        _stopLocationTracking();
        return;
      }
      try {
        final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high,), );
        final repo = ref.read(tecnicoRepositoryProvider);
        await repo.enviarUbicacion(
          asignacionId: state.asignacion!.id, 
          latitud: position.latitude, 
          longitud: position.longitude
        );
        
        await _fetchRouteIfNeeded(position);
        
        // Validación Off-Route Local
        if (state.polylineCoords.isNotEmpty && state.asignacion!.latitud != null) {
          final currentLatLng = LatLng(position.latitude, position.longitude);
          if (_isOffRoute(currentLatLng, state.polylineCoords)) {
            debugPrint("Off-route detectado! Recalculando ruta...");
            final routeData = await _routingRepository.recalcularRuta(
              lng1: position.longitude,
              lat1: position.latitude,
              lng2: state.asignacion!.longitud!,
              lat2: state.asignacion!.latitud!,
              solicitudId: state.asignacion!.solicitudId,
            );
            if (routeData != null && routeData['polyline'] != null) {
              final decoded = PolylineDecoder.decode(routeData['polyline']);
              state = state.copyWith(polylineCoords: decoded);
            }
          }
        }
      } catch (e) {
        debugPrint("Error al enviar ubicación: $e");
      }
    });
  }

  Future<void> _fetchRouteIfNeeded(Position position) async {
    if (state.asignacion == null || state.asignacion!.latitud == null || state.asignacion!.longitud == null) return;
    
    if (state.polylineCoords.isEmpty) {
      final routeData = await _routingRepository.obtenerRuta(
        lng1: position.longitude,
        lat1: position.latitude,
        lng2: state.asignacion!.longitud!,
        lat2: state.asignacion!.latitud!,
      );
      if (routeData != null && routeData['polyline'] != null) {
        final decoded = PolylineDecoder.decode(routeData['polyline']);
        state = state.copyWith(polylineCoords: decoded);
      }
    }
  }

  bool _isOffRoute(LatLng currentPos, List<LatLng> polyline) {
    if (polyline.isEmpty) return false;
    double minDistance = double.infinity;
    for (var point in polyline) {
      final d = _distanceCalc.as(LengthUnit.Meter, currentPos, point);
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance > 200;
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isTrackingLocation = false;
  }

  Future<void> _fetchAsignacionDetails(int solicitudId, int asignacionId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(tecnicoRepositoryProvider);
      final asignacion = await repo.obtenerDetalleSolicitud(
        solicitudId: solicitudId, 
        asignacionId: asignacionId
      );
      state = state.copyWith(
        status: MecanicoStateStatus.sosRecibido,
        asignacion: asignacion,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Solo para test de UI
  void simulateSosRecibido() {
    state = state.copyWith(
      status: MecanicoStateStatus.sosRecibido,
      asignacion: AsignacionEntity(
        id: 999,
        solicitudId: 999,
        estado: 'PENDIENTE',
        problemaDetectado: 'Fallo de motor (Simulado)',
        clienteNombre: 'Cliente Simulado',
        vehiculoInfo: 'Toyota Simulador - XYZ-123',
        distanciaKm: 1.5,
      ),
    );
  }

  Future<void> acceptJob(int asignacionId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(tecnicoRepositoryProvider);
      final updated = await repo.responderAsignacion(
        asignacionId: asignacionId, 
        aceptar: true,
      );
      state = state.copyWith(
        status: MecanicoStateStatus.enRuta,
        asignacion: updated,
        isLoading: false,
      );
      _startLocationTracking();
      fetchHistorial();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> rejectJob(int asignacionId, String reason) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(tecnicoRepositoryProvider);
      await repo.responderAsignacion(
        asignacionId: asignacionId, 
        aceptar: false,
        motivoRechazo: reason,
      );
      
      // Si la que rechazó era la activa global, volvemos a idle
      if (state.asignacion?.id == asignacionId) {
        state = state.copyWith(status: MecanicoStateStatus.idle, asignacion: null, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
      fetchHistorial();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchActiveAssignment() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(tecnicoRepositoryProvider);
      final asignacion = await repo.obtenerAsignacionActiva();
      
      if (asignacion != null) {
        MecanicoStateStatus newStatus = MecanicoStateStatus.idle;
        if (asignacion.estado == 'PENDIENTE') {
          newStatus = MecanicoStateStatus.sosRecibido;
        } else if (asignacion.estado == 'ACEPTADA' || asignacion.estado == 'EN_CAMINO') {
          newStatus = MecanicoStateStatus.enRuta;
          _startLocationTracking();
        } else if (asignacion.estado == 'EN_SITIO') {
          newStatus = MecanicoStateStatus.enSitio; 
          _stopLocationTracking(); // Ya llegó, no hace falta location tan seguido (o sí, pero lo apagamos)
        }

        state = state.copyWith(
          status: newStatus,
          asignacion: asignacion,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, status: MecanicoStateStatus.idle, asignacion: null);
      }
      fetchHistorial();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> arriveAtLocation() async {
    if (state.asignacion == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(tecnicoRepositoryProvider);
      final updated = await repo.marcarLlegada(asignacionId: state.asignacion!.id);
      
      state = state.copyWith(
        status: MecanicoStateStatus.enSitio,
        asignacion: updated,
        isLoading: false,
      );
      _stopLocationTracking();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> finalizarTrabajo(double montoTotal) async {
    if (state.asignacion == null) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(tecnicoRepositoryProvider);
      await repo.finalizarTrabajo(
        asignacionId: state.asignacion!.id, 
        montoTotal: montoTotal,
      );
      
      state = MecanicoState(); // Volvemos a idle
      fetchHistorial();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final mecanicoControllerProvider = NotifierProvider<MecanicoNotifier, MecanicoState>(() {
  return MecanicoNotifier();
});

class IsOnlineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void setStatus(bool isOnline) {
    state = isOnline;
    // Si se conecta, conectamos el WS y buscamos asignación activa
    if (isOnline) {
      ref.read(mecanicoControllerProvider.notifier).connectWebSocket();
      ref.read(mecanicoControllerProvider.notifier).fetchActiveAssignment();
    }
  }
}

final isOnlineProvider = NotifierProvider<IsOnlineNotifier, bool>(() {
  return IsOnlineNotifier();
});
