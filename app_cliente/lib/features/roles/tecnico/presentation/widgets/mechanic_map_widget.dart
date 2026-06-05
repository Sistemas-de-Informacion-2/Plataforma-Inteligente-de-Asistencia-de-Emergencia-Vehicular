import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../../core/theme/app_theme.dart';
import '../providers/mecanico_provider.dart';

class MechanicMapWidget extends ConsumerStatefulWidget {
  const MechanicMapWidget({super.key});

  @override
  ConsumerState<MechanicMapWidget> createState() => _MechanicMapWidgetState();
}

class _MechanicMapWidgetState extends ConsumerState<MechanicMapWidget> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final GlobalKey _pulseMarkerKey = GlobalKey();
  final GlobalKey _clientMarkerKey = GlobalKey();
  LatLng _currentLocation = const LatLng(-17.7833, -63.1821); // Default Santa Cruz
  StreamSubscription<Position>? _positionStream;
  bool _isMapReady = false;

  late final AnimationController _mapAnimCtrl;
  
  @override
  void initState() {
    super.initState();
    _mapAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _initLocation();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    // Obtener la posición actual
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    if (mounted) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        if (_isMapReady) {
          _animatedMapMove(_currentLocation, 15.5);
        }
      });
    }

    // Escuchar cambios de ubicación con filtro de distancia
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      )
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    final Animation<double> animation = CurvedAnimation(parent: _mapAnimCtrl, curve: Curves.fastOutSlowIn);

    _mapAnimCtrl.reset();
    
    // Evitamos re-añadir listeners con una función local o escuchando
    void listener() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    }
    
    _mapAnimCtrl.addListener(listener);
    _mapAnimCtrl.forward().then((_) {
      _mapAnimCtrl.removeListener(listener);
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapAnimCtrl.dispose();
    super.dispose();
  }

  void _centerMap() {
    if (_isMapReady) {
      _animatedMapMove(_currentLocation, 16.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mechanicState = ref.watch(mecanicoControllerProvider);
    final hasEmergency = mechanicState.status != MecanicoStateStatus.idle && mechanicState.asignacion != null;
    final asignacion = mechanicState.asignacion;
    
    LatLng? emergencyLocation;
    if (hasEmergency && asignacion!.latitud != null && asignacion.longitud != null) {
      emergencyLocation = LatLng(asignacion.latitud!, asignacion.longitud!);
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 15.0,
            onMapReady: () {
              _isMapReady = true;
              _mapController.move(_currentLocation, 15.0);
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.example.app_cliente',
            ),
            if (hasEmergency && emergencyLocation != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [_currentLocation, emergencyLocation],
                    color: AppTheme.primaryColor.withValues(alpha: 0.8),
                    strokeWidth: 5.0,
                    pattern: StrokePattern.dashed(segments: const [10.0, 10.0]), // Linea punteada
                    borderStrokeWidth: 2.0,
                    borderColor: AppTheme.inkDark.withValues(alpha: 0.2),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (hasEmergency && emergencyLocation != null)
                  Marker(
                    point: emergencyLocation,
                    width: 70, height: 70,
                    child: _ClientMarker(key: _clientMarkerKey),
                  ),
                Marker(
                  point: _currentLocation,
                  width: 80, height: 80,
                  child: _PulseMarker(key: _pulseMarkerKey),
                ),
              ],
            ),
          ],
        ),
        
        // Efecto de sombreado en los bordes para mejorar el contraste
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.8),
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.0),
                  Colors.white.withValues(alpha: 0.8),
                ],
                stops: const [0.0, 0.15, 0.85, 1.0],
              ),
            ),
          ),
        ),

        // FAB Mi Ubicacion
        Positioned(
          bottom: 40,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: AppTheme.cardShadow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: FloatingActionButton(
              heroTag: 'mechanicCenterLocationBtn',
              backgroundColor: AppTheme.surfaceColor,
              foregroundColor: AppTheme.primaryColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: _centerMap,
              child: const Icon(CupertinoIcons.location_fill, size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Custom Markers ────────────────────────────────────────────────────────────
class _PulseMarker extends StatefulWidget {
  const _PulseMarker({super.key});

  @override
  State<_PulseMarker> createState() => _PulseMarkerState();
}

class _PulseMarkerState extends State<_PulseMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Onda expansiva
            Container(
              width: 80 * _animCtrl.value,
              height: 80 * _animCtrl.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: (1.0 - _animCtrl.value) * 0.4),
              ),
            ),
            // Marcador central
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: const Icon(CupertinoIcons.wrench_fill, color: Colors.white, size: 16),
            ),
          ],
        );
      },
    );
  }
}

class _ClientMarker extends StatelessWidget {
  const _ClientMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.danger,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: const Text(
            'Cliente',
            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppTheme.dangerSoft,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.danger, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: const Icon(CupertinoIcons.car_detailed, color: AppTheme.danger, size: 14),
        ),
      ],
    );
  }
}
