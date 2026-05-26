import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../core/network/websocket_service.dart';
import '../../domain/entities/recomendacion_result.dart';
import '../../domain/usecases/reportar_emergencia_usecase.dart';
import '../../domain/usecases/seleccionar_taller_usecase.dart';
import '../../data/repositories/incidente_repository_impl.dart';
import '../../data/repositories/routing_repository.dart';
import '../../data/models/asignacion_model.dart';
import '../../../../../core/utils/polyline_decoder.dart';
import 'package:latlong2/latlong.dart';

/// Estados del flujo de emergencia (máquina de estados).
enum EmergenciaFlowState {
  initial,
  loadingIA,
  showRecommendations,
  sendingSelection,
  waitingForShopResponse,
  accepted,
  rejected,
  timeout,
  error,
}

/// Provider que gestiona el flujo completo de reporte de emergencia.
class EmergenciaProvider extends ChangeNotifier {
  final IncidenteRepositoryImpl _repository = IncidenteRepositoryImpl();
  final RoutingRepository _routingRepository = RoutingRepository();
  late final ReportarEmergenciaUseCase _reportarUseCase;
  late final SeleccionarTallerUseCase _seleccionarUseCase;
  final WebSocketService _wsService = WebSocketService();

  // ── Estado ──────────────────────────────────────────────────
  EmergenciaFlowState _flowState = EmergenciaFlowState.initial;
  EmergenciaFlowState get flowState => _flowState;

  RecomendacionResult? _recomendaciones;
  RecomendacionResult? get recomendaciones => _recomendaciones;

  int? _solicitudId;
  int? get solicitudId => _solicitudId;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool _advertirArchivosBorrados = false;
  bool get advertirArchivosBorrados => _advertirArchivosBorrados;

  int? _waitingSucursalId;
  int? get waitingSucursalId => _waitingSucursalId;

  AsignacionModel? _asignacion;
  AsignacionModel? get asignacion => _asignacion;

  List<LatLng> _polylineCoords = [];
  List<LatLng> get polylineCoords => _polylineCoords;

  LatLng? _mechanicLocation;
  LatLng? get mechanicLocation => _mechanicLocation;

  String _etaText = '--';
  String get etaText => _etaText;

  Timer? _timeoutTimer;
  Timer? _mechanicSimTimer;
  StreamSubscription? _wsSubscription;
  
  VoidCallback? onServiceFinished;
  void Function(Map<String, dynamic> pagoData)? onPaymentRequired;

  /// Compatibilidad: indica si hay una carga en curso.
  bool get isUploading => _flowState == EmergenciaFlowState.loadingIA;

  EmergenciaProvider() {
    _reportarUseCase = ReportarEmergenciaUseCase(_repository);
    _seleccionarUseCase = SeleccionarTallerUseCase(_repository);
  }

  // ── WebSockets ─────────────────────────────────────────────
  Future<void> connectWebSocket() async {
    await _wsService.connect();
    _wsSubscription?.cancel();
    _wsSubscription = _wsService.messageStream.listen(_onWsMessage);
  }

  void _onWsMessage(Map<String, dynamic> msg) async {
    debugPrint('[WS DEBUG] Provider onWsMessage: $msg');
    final type = msg['type'];
    if (type == 'SOLICITUD_ACEPTADA_TALLER') {
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      _recomendaciones = null; // Evita que se vuelva a abrir el BottomSheet
      
      // Parsear la asignación directamente del websocket
      if (msg['asignacion_resultado'] != null) {
        _asignacion = AsignacionModel.fromJson(msg['asignacion_resultado']);
      }

      // Obtener detalles del incidente para sacar coordenadas del cliente
      if (_solicitudId != null) {
        final detalle = await _repository.obtenerDetalleIncidente(_solicitudId!);
        if (detalle != null && _asignacion?.sucursal != null) {
          final latTaller = _asignacion!.sucursal!['latitud'] as double?;
          final lngTaller = _asignacion!.sucursal!['longitud'] as double?;
          final latCliente = detalle['latitud'] as double?;
          final lngCliente = detalle['longitud'] as double?;

          if (latTaller != null && lngTaller != null && latCliente != null && lngCliente != null) {
            _mechanicLocation = LatLng(latTaller, lngTaller);
            await _fetchRoute(lngTaller, latTaller, lngCliente, latCliente);
            _startMechanicSimulation(LatLng(latTaller, lngTaller), LatLng(latCliente, lngCliente));
          }
        }
      }

      _flowState = EmergenciaFlowState.accepted;
      notifyListeners();
    } else if (type == 'SOLICITUD_RECHAZADA_TALLER') {
      _timeoutTimer?.cancel();
      _waitingSucursalId = null;
      _errorMessage = 'El taller rechazó la solicitud. Por favor, selecciona otro.';
      _flowState = EmergenciaFlowState.rejected;
      notifyListeners();
      
      // Volver a mostrar recomendaciones tras un breve delay para que la UI procese el rejected
      Future.delayed(const Duration(milliseconds: 100), () {
        _flowState = EmergenciaFlowState.showRecommendations;
        notifyListeners();
      });
    } else if (type == 'SERVICIO_FINALIZADO') {
      _timeoutTimer?.cancel();
      _mechanicSimTimer?.cancel();
      
      // Llamar al callback ANTES de resetear para que TrackingScreen pueda leer asignacion.sucursal['id'] para el ReviewModal
      if (onServiceFinished != null) {
        onServiceFinished!();
      }
    } else if (type == 'UPDATE_LOCATION') {
      final lat = msg['latitud'];
      final lng = msg['longitud'];
      if (lat != null && lng != null) {
        _mechanicLocation = LatLng(lat, lng);
        notifyListeners();
      }
    } else if (type == 'PAGO_REQUERIDO') {
      debugPrint('[WS] Pago requerido recibido: $msg');
      if (onPaymentRequired != null) {
        onPaymentRequired!(msg);
      }
    }
  }

  Future<void> _fetchRoute(double lng1, double lat1, double lng2, double lat2) async {
    final routeData = await _routingRepository.obtenerRuta(
      lng1: lng1, lat1: lat1, lng2: lng2, lat2: lat2
    );
    if (routeData != null && routeData['polyline'] != null) {
      _polylineCoords = PolylineDecoder.decode(routeData['polyline']);
      final durationSecs = routeData['duration'] as num;
      _etaText = '${(durationSecs / 60).ceil()} min';
      notifyListeners();
    }
  }

  void _startMechanicSimulation(LatLng start, LatLng end) {
    _mechanicSimTimer?.cancel();
    
    // Simula movimiento cada 5 segundos interpolando hacia el destino
    double currentLat = start.latitude;
    double currentLng = start.longitude;
    final double stepLat = (end.latitude - start.latitude) / 20; // 20 pasos
    final double stepLng = (end.longitude - start.longitude) / 20;
    
    int step = 0;
    _mechanicSimTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (step >= 20) {
        timer.cancel();
        return;
      }
      step++;
      currentLat += stepLat;
      currentLng += stepLng;
      
      // Enviar al WS (Simulando que el mecánico lo envía, pero el WS del backend espera UPDATE_LOCATION)
      // Como esto es simulación de prueba en el cliente, actualizamos directo.
      _mechanicLocation = LatLng(currentLat, currentLng);
      // Simular reducción de ETA
      if (_polylineCoords.isNotEmpty) {
         _etaText = '${((20 - step) * 0.5).ceil()} min';
      }
      notifyListeners();
    });
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 120), () {
      if (_flowState == EmergenciaFlowState.waitingForShopResponse) {
        _waitingSucursalId = null;
        _errorMessage = 'El taller no respondió a tiempo. Intenta con otro.';
        _flowState = EmergenciaFlowState.timeout;
        notifyListeners();

        Future.delayed(const Duration(milliseconds: 100), () {
          _flowState = EmergenciaFlowState.showRecommendations;
          notifyListeners();
        });
      }
    });
  }

  // ── Fase 1: Enviar SOS → Obtener recomendaciones ──────────
  Future<RecomendacionResult?> enviarEmergencia({
    required int? vehiculoId,
    required double latitud,
    required double longitud,
    String? descripcion,
    List<File> imagenes = const [],
    File? audio,
  }) async {
    _flowState = EmergenciaFlowState.loadingIA;
    _errorMessage = '';
    _advertirArchivosBorrados = false;
    _recomendaciones = null;
    _solicitudId = null;
    _waitingSucursalId = null;
    _asignacion = null;
    notifyListeners();

    try {
      final imagenesValidas = <File>[];
      for (final file in imagenes) {
        if (await file.exists()) {
          imagenesValidas.add(file);
        } else {
          _advertirArchivosBorrados = true;
        }
      }

      if (audio != null && !(await audio.exists())) {
        audio = null;
        _advertirArchivosBorrados = true;
      }

      final result = await _reportarUseCase(
        vehiculoId: vehiculoId,
        latitud: latitud,
        longitud: longitud,
        descripcion: descripcion,
        imagenes: imagenesValidas,
        audio: audio,
      );

      _recomendaciones = result;
      _solicitudId = result.solicitud.id;
      _flowState = EmergenciaFlowState.showRecommendations;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = 'Error al enviar emergencia: $e';
      _flowState = EmergenciaFlowState.error;
      notifyListeners();
      return null;
    }
  }

  // ── Fase 2: Seleccionar taller ────────────────────────────
  Future<bool> seleccionarTaller(int sucursalId) async {
    if (_solicitudId == null) {
      _errorMessage = 'No hay solicitud activa para seleccionar taller.';
      _flowState = EmergenciaFlowState.error;
      notifyListeners();
      return false;
    }

    _flowState = EmergenciaFlowState.sendingSelection;
    _waitingSucursalId = sucursalId;
    notifyListeners();

    try {
      final success = await _seleccionarUseCase(
        solicitudId: _solicitudId!,
        sucursalId: sucursalId,
      );

      if (success) {
        _flowState = EmergenciaFlowState.waitingForShopResponse;
        _startTimeout();
      } else {
        _waitingSucursalId = null;
        _errorMessage = 'No se pudo procesar la selección. Intenta de nuevo.';
        _flowState = EmergenciaFlowState.error;
      }
      notifyListeners();
      return success;
    } catch (e) {
      _waitingSucursalId = null;
      _errorMessage = 'Error al seleccionar taller: $e';
      _flowState = EmergenciaFlowState.error;
      notifyListeners();
      return false;
    }
  }

  // ── Reset ─────────────────────────────────────────────────
  void reset() {
    _timeoutTimer?.cancel();
    _mechanicSimTimer?.cancel();
    _wsSubscription?.cancel();
    _wsService.disconnect();
    
    _flowState = EmergenciaFlowState.initial;
    _recomendaciones = null;
    _solicitudId = null;
    _waitingSucursalId = null;
    _asignacion = null;
    _polylineCoords = [];
    _mechanicLocation = null;
    _etaText = '--';
    _errorMessage = '';
    _advertirArchivosBorrados = false;
    notifyListeners();
  }
}
