import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_theme.dart';
import '../providers/emergencia_provider.dart';

class EmergenciaMapWidget extends StatefulWidget {
  final LatLng? userLocation;

  const EmergenciaMapWidget({
    super.key,
    this.userLocation,
  });

  @override
  State<EmergenciaMapWidget> createState() => _EmergenciaMapWidgetState();
}

class _EmergenciaMapWidgetState extends State<EmergenciaMapWidget>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  static const LatLng _defaultLocation = LatLng(-17.7833, -63.1821);

  // Animation handling for mechanic location
  LatLng? _oldMechanicLoc;
  late AnimationController _mechanicMoveController;
  late Animation<double> _mechanicMoveAnimation;

  final GlobalKey _mechanicMarkerKey = GlobalKey();
  final GlobalKey _userMarkerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _mechanicMoveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Suave transición de 1 seg
    );
    _mechanicMoveAnimation = CurvedAnimation(
      parent: _mechanicMoveController,
      curve: Curves.linear,
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _mechanicMoveController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EmergenciaMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userLocation != null &&
        widget.userLocation != oldWidget.userLocation) {
      _mapController.move(widget.userLocation!, 15.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = widget.userLocation ?? _defaultLocation;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: currentLocation,
        initialZoom: 15.0,
        minZoom: 5.0,
        maxZoom: 19.0,
        keepAlive: true,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.scrollWheelZoom,
        ),
      ),
      children: [
        // ── 1. CAPA DE TILES ──────────────────────────────────────────────
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.it_nomads.app_cliente',
          maxNativeZoom: 19,
          keepBuffer: 4,
          panBuffer: 2,
        ),

        // ── 2. CAPA DE RUTA ───────────────────────────────────────────────
        Selector<EmergenciaProvider, List<LatLng>>(
          selector: (_, p) => p.polylineCoords,
          builder: (context, polylineCoords, _) {
            if (polylineCoords.isEmpty) return const SizedBox.shrink();
            return PolylineLayer(
              polylines: [
                // Sombra inDrive (borde negro/oscuro)
                Polyline(
                  points: polylineCoords,
                  color: Colors.black.withValues(alpha: 0.3),
                  strokeWidth: 8.0,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
                // Línea inDrive (blanca o primaria clara)
                Polyline(
                  points: polylineCoords,
                  color: Colors.white,
                  strokeWidth: 5.0,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
              ],
            );
          },
        ),

        // ── 3. MARCADOR DEL CLIENTE ───────────────────────────────────────
        if (widget.userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.userLocation!,
                width: 88,
                height: 88,
                child: _UserLocationMarker(key: _userMarkerKey),
              ),
            ],
          ),

        // ── 4. MARCADOR DEL MECÁNICO (ANIMADO Y SIN FLICKER) ──────────────
        Selector<EmergenciaProvider, LatLng?>(
          selector: (_, p) => p.mechanicLocation,
          builder: (context, newLoc, _) {
            if (newLoc == null) return const SizedBox.shrink();

            if (_oldMechanicLoc != null && _oldMechanicLoc != newLoc) {
              _mechanicMoveController.forward(from: 0.0);
            }
            final oldLoc = _oldMechanicLoc ?? newLoc;
            _oldMechanicLoc = newLoc;

            return AnimatedBuilder(
              animation: _mechanicMoveAnimation,
              builder: (context, child) {
                // Interpolar coordenadas
                final currentLat = oldLoc.latitude +
                    (newLoc.latitude - oldLoc.latitude) *
                        _mechanicMoveAnimation.value;
                final currentLng = oldLoc.longitude +
                    (newLoc.longitude - oldLoc.longitude) *
                        _mechanicMoveAnimation.value;

                return MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(currentLat, currentLng),
                      width: 68,
                      height: 68,
                      child: _MechanicMarker(key: _mechanicMarkerKey),
                    ),
                  ],
                );
              },
            );
          },
        ),

        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
          alignment: AttributionAlignment.bottomLeft,
          popupInitialDisplayDuration: Duration.zero,
        ),
      ],
    );
  }
}

class _UserLocationMarker extends StatefulWidget {
  const _UserLocationMarker({super.key});

  @override
  State<_UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<_UserLocationMarker>
    with SingleTickerProviderStateMixin {
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
              width: 88 * _animCtrl.value,
              height: 88 * _animCtrl.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: (1.0 - _animCtrl.value) * 0.4),
              ),
            ),
            // Marcador central
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.5), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
            ),
          ],
        );
      },
    );
  }
}

class _MechanicMarker extends StatefulWidget {
  const _MechanicMarker({super.key});

  @override
  State<_MechanicMarker> createState() => _MechanicMarkerState();
}

class _MechanicMarkerState extends State<_MechanicMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _entryScale;
  late final Animation<double> _entryOpacity;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _entryScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.elasticOut),
    );
    _entryOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        return Transform.scale(
          scale: _entryScale.value,
          child: Opacity(
            opacity: _entryOpacity.value,
            child: child,
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Icono estilo inDrive (Carro / Grúa en vista cenital si se tiene)
          // Usaremos un estilo glassmorphism limpio
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.primaryColor,
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.car_repair_rounded,
                    color: AppTheme.primaryColor,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
          // Badge "En camino"
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.success.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
