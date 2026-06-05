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
  waitingForBids,
  waitingForMechanic,
  serviceInProgress,
  accepted,
  arrived,
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
  WebSocketService get wsService => _wsService;

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
  VoidCallback? onPujaAceptadaCallback;

  // ── Pujas (Bids) State ─────────────────────────────────────
  final List<Map<String, dynamic>> _pujasActivas = [];
  List<Map<String, dynamic>> get pujasActivas => _pujasActivas;
  
  bool _esperandoPujas = false;
  bool get esperandoPujas => _esperandoPujas;

  /// Compatibilidad: indica si hay una carga en curso.
  bool get isUploading => _flowState == EmergenciaFlowState.loadingIA;

  EmergenciaProvider() {
    _reportarUseCase = ReportarEmergenciaUseCase(_repository);
    _seleccionarUseCase = SeleccionarTallerUseCase(_repository);
  }

  // ── Recuperación de Estado ─────────────────────────────────
  Future<void> verificarSolicitudActiva() async {
    try {
      final data = await _repository.obtenerSolicitudActiva();
      if (data != null && data['id'] != null) {
        _solicitudId = data['id'];
        final estado = data['estado'];
        
        if (estado == 'ESPERANDO_PUJAS' || estado == 'PENDIENTE') {
          // Restaurar Radar
          _flowState = EmergenciaFlowState.waitingForBids;
          _esperandoPujas = true;
          // Si hay pujas anteriores, las cargamos (opcional, el WS igual mandará)
          if (data['pujas'] != null) {
            _pujasActivas.clear();
            for (var p in data['pujas']) {
              if (p['estado'] == 'PENDIENTE') {
                _pujasActivas.add(p);
              }
            }
          }
          await connectWebSocket();
          notifyListeners();
        } else if (estado == 'EN_PROCESO') {
          // Restaurar Seguimiento
          _flowState = EmergenciaFlowState.serviceInProgress;
          
          if (data['asignaciones'] != null && (data['asignaciones'] as List).isNotEmpty) {
            final asigActiva = (data['asignaciones'] as List).firstWhere(
              (a) => a['estado'] == 'ACEPTADA' || a['estado'] == 'EN_CAMINO' || a['estado'] == 'EN_SITIO',
              orElse: () => data['asignaciones'][0],
            );
            _asignacion = AsignacionModel.fromJson(asigActiva);
          }

          await connectWebSocket();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[EmergenciaProvider] Error al verificar solicitud activa: $e');
    }
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

    if (type == 'NUEVA_PUJA_RECIBIDA') {
      _pujasActivas.add({
        'id': msg['puja_id'],
        'sucursal_id': msg['sucursal_id'],
        'taller_nombre': msg['taller_nombre'],
        'sucursal_nombre': msg['sucursal_nombre'],
        'precio_estimado': (msg['precio_estimado'] as num).toDouble(),
        'tiempo_llegada_minutos': msg['tiempo_llegada_minutos'],
        'rating': (msg['rating'] as num).toDouble(),
        'distancia_km': msg['distancia_km'],
      });

      _pujasActivas.sort((a, b) {
        int cmp = a['precio_estimado'].compareTo(b['precio_estimado']);
        if (cmp != 0) return cmp;
        return a['tiempo_llegada_minutos'].compareTo(b['tiempo_llegada_minutos']);
      });

      notifyListeners();
    } 
    else if (type == 'PUJA_ACEPTADA') {
      _esperandoPujas = false;
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      _recomendaciones = null;
      
      // Parsear la asignación inicial (sucursal)
      if (msg['sucursal'] != null) {
        _asignacion = AsignacionModel(
          tiempoEstimado: (msg['tiempo_estimado'] as num?)?.toDouble(),
          sucursal: msg['sucursal'],
        );
      }

      // Nos quedamos esperando al mecánico
      _flowState = EmergenciaFlowState.waitingForMechanic;
      notifyListeners();
    }
    // Cuando el mecánico acepta la asignación
    else if (type == 'MECANICO_EN_CAMINO') {
      if (_solicitudId != null) {
        final detalle = await _repository.obtenerDetalleIncidente(_solicitudId!);
        final mecanicoData = msg['mecanico'];
        
        if (detalle != null && mecanicoData != null) {
          final latTaller = mecanicoData['latitud'] as double?;
          final lngTaller = mecanicoData['longitud'] as double?;
          final latCliente = detalle['latitud'] as double?;
          final lngCliente = detalle['longitud'] as double?;

          if (latTaller != null && lngTaller != null && latCliente != null && lngCliente != null) {
            _mechanicLocation = LatLng(latTaller, lngTaller);
            await _fetchRoute(lngTaller, latTaller, lngCliente, latCliente);
            // Ya no simulamos si vamos a recibir coords reales
            // _startMechanicSimulation(LatLng(latTaller, lngTaller), LatLng(latCliente, lngCliente));
          }
        }
      }

      _flowState = EmergenciaFlowState.accepted;
      onPujaAceptadaCallback?.call(); // Este trigger nos mandará al mapa de tracking
      notifyListeners();
    }
  // Mantener compatibilidad con el flujo antiguo temporalmente
    else if (type == 'SOLICITUD_ACEPTADA_TALLER') {
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      _recomendaciones = null; 
      
      if (msg['asignacion_resultado'] != null) {
        _asignacion = AsignacionModel.fromJson(msg['asignacion_resultado']);
      }

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
            // _startMechanicSimulation(LatLng(latTaller, lngTaller), LatLng(latCliente, lngCliente));
          }
        }
      }

      _flowState = EmergenciaFlowState.accepted;
      onPujaAceptadaCallback?.call();
      notifyListeners();
    } else if (type == 'MECANICO_UBICACION') {
      final lat = msg['latitud'] as double?;
      final lng = msg['longitud'] as double?;
      if (lat != null && lng != null) {
        _mechanicLocation = LatLng(lat, lng);
        notifyListeners();
      }
    } else if (type == 'MECANICO_EN_SITIO') {
      _flowState = EmergenciaFlowState.arrived;
      notifyListeners();
    } else if (type == 'SOLICITUD_RECHAZADA_TALLER') {
      _timeoutTimer?.cancel();
      _waitingSucursalId = null;
      _errorMessage = 'El taller rechazó la solicitud. Por favor, selecciona otro.';
      _flowState = EmergenciaFlowState.rejected;
      notifyListeners();
      
      Future.delayed(const Duration(milliseconds: 100), () {
        _flowState = EmergenciaFlowState.showRecommendations;
        notifyListeners();
      });
    } else if (type == 'SERVICIO_FINALIZADO') {
      _timeoutTimer?.cancel();
      _mechanicSimTimer?.cancel();
      
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
    _esperandoPujas = false;
    _pujasActivas.clear();
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
      _esperandoPujas = true;
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

  // ── Fase 3: Aceptar Puja ────────────────────────────
  Future<void> aceptarPuja(int pujaId) async {
    if (_solicitudId == null) return;
    try {
      await _repository.seleccionarPuja(
        solicitudId: _solicitudId!,
        pujaId: pujaId,
      );
      // La navegación se manejará al recibir PUJA_ACEPTADA por WebSocket
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Rechaza una puja explícitamente notificando al backend
  Future<void> rechazarPuja(int pujaId) async {
    // Actualización optimista para que desaparezca al instante
    _pujasActivas.removeWhere((p) => p['id'] == pujaId);
    notifyListeners();

    try {
      await _repository.rechazarPuja(pujaId: pujaId);
    } catch (e) {
      debugPrint('[EmergenciaProvider] Error rechazando puja: $e');
    }
  }

  // ── Cancelar Solicitud ─────────────────────────────────────
  Future<void> cancelarSolicitud() async {
    if (_solicitudId == null) return;
    try {
      await _repository.cancelarSolicitud(_solicitudId!);
      reset(); // Volver al inicio limpio
    } catch (e) {
      debugPrint('[EmergenciaProvider] Error cancelando solicitud: $e');
      _errorMessage = 'No se pudo cancelar: $e';
      notifyListeners();
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
