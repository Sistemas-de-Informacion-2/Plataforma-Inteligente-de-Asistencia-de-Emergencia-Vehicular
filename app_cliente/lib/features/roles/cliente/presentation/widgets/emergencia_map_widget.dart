// src/features/roles/cliente/presentation/widgets/emergencia_map_widget.dart
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

  // ── GlobalKey SOLO en el marcador del usuario (para preservar su
  //    AnimationController de pulso a través de rebuilds por cambio de posición)
  final GlobalKey _userMarkerKey = GlobalKey();

  // ── El marcador del mecánico ya NO necesita GlobalKey porque
  //    _SmoothMechanicLayer gestiona su propio ciclo de vida.
  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EmergenciaMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userLocation != null && widget.userLocation != oldWidget.userLocation) {
      _mapController.move(widget.userLocation!, _mapController.camera.zoom);
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
                Polyline(
                  points: polylineCoords,
                  color: Colors.black.withValues(alpha: 0.3),
                  strokeWidth: 8.0,
                  strokeCap: StrokeCap.round,
                  strokeJoin: StrokeJoin.round,
                ),
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
                // GlobalKey preserva la animación de pulso cuando cambia userLocation
                child: _UserLocationMarker(key: _userMarkerKey),
              ),
            ],
          ),

        // ── 4. MARCADOR DEL MECÁNICO — ANIMACIÓN SIN PARPADEO ─────────────
        //
        // FIX: Reemplazamos el Selector + TweenAnimationBuilder (que causaba
        // el parpadeo) por _SmoothMechanicLayer, un StatefulWidget que:
        //   a) Recibe la nueva posición vía didUpdateWidget (no recrea el widget)
        //   b) Guarda _from como la posición interpolada actual
        //   c) Anima suavemente de _from → _to con AnimatedBuilder
        //   d) Pasa _MechanicMarker como child: (construido UNA sola vez,
        //      su animación de entrada solo se ejecuta al primer montaje)
        Selector<EmergenciaProvider, LatLng?>(
          selector: (_, p) => p.mechanicLocation,
          builder: (_, loc, __) => _SmoothMechanicLayer(location: loc),
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

// ─────────────────────────────────────────────────────────────────────────────
// _SmoothMechanicLayer
//
// Gestiona la interpolación de posición del marcador del mecánico sin parpadeo.
//
// Por qué funciona:
//   • El Selector rebuilds cuando llega nueva ubicación → devuelve una nueva
//     instancia de _SmoothMechanicLayer con location distinto.
//   • Flutter detecta el mismo tipo en la misma posición del árbol → llama
//     didUpdateWidget en el State existente en lugar de recrearlo.
//   • didUpdateWidget captura la posición animada actual como _from, pone
//     newLoc como _to, y relanza el AnimationController desde 0.
//   • AnimatedBuilder solo rebuilds MarkerLayer (no _MechanicMarker), así
//     que el marcador NO se desmonta y su animación de entrada no se repite.
// ─────────────────────────────────────────────────────────────────────────────
class _SmoothMechanicLayer extends StatefulWidget {
  final LatLng? location;
  const _SmoothMechanicLayer({this.location});

  @override
  State<_SmoothMechanicLayer> createState() => _SmoothMechanicLayerState();
}

class _SmoothMechanicLayerState extends State<_SmoothMechanicLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  LatLng _from = const LatLng(0, 0);
  LatLng _to = const LatLng(0, 0);
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.location != null) {
      _from = widget.location!;
      _to = widget.location!;
      _initialized = true;
      _ctrl.value = 1.0; // sin animación en el primer punto
    }
  }

  @override
  void didUpdateWidget(_SmoothMechanicLayer old) {
    super.didUpdateWidget(old);
    final newLoc = widget.location;
    if (newLoc == null || newLoc == old.location) return;

    if (!_initialized) {
      // Primera ubicación recibida: aparece sin animación
      _from = newLoc;
      _to = newLoc;
      _initialized = true;
      _ctrl.value = 1.0;
    } else {
      // Ubicaciones siguientes: interpola desde donde está ahora
      _from = _currentPos; // captura posición actual de la animación en curso
      _to = newLoc;
      _ctrl.forward(from: 0); // reinicia y arranca la transición
    }
  }

  /// Posición interpolada actual según el valor del AnimationController.
  LatLng get _currentPos {
    final t = Curves.easeInOut.transform(_ctrl.value);
    return LatLng(
      _from.latitude + (_to.latitude - _from.latitude) * t,
      _from.longitude + (_to.longitude - _from.longitude) * t,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _ctrl,
      // child: se construye UNA sola vez y se reutiliza en cada frame.
      // Esto garantiza que _MechanicMarkerState NO se recrea en cada tick
      // y por ende su animación de entrada solo corre al primer montaje.
      child: const _MechanicMarker(),
      builder: (context, child) {
        return MarkerLayer(
          markers: [
            Marker(
              point: _currentPos,
              width: 44,
              height: 44,
              child: child!,
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Marcadores (sin cambios en su lógica, solo se garantiza que se montan
// una sola vez gracias al patrón corregido arriba)
// ─────────────────────────────────────────────────────────────────────────────

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
            Container(
              width: 88 * _animCtrl.value,
              height: 88 * _animCtrl.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor
                    .withValues(alpha: (1.0 - _animCtrl.value) * 0.4),
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.person_rounded, color: Colors.white, size: 20),
            ),
          ],
        );
      },
    );
  }
}

class _MechanicMarker extends StatefulWidget {
  // Sin GlobalKey: _SmoothMechanicLayerState ya garantiza que este widget
  // vive en el árbol de forma estable (no se desmonta entre actualizaciones).
  const _MechanicMarker();

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
    // Esta animación de entrada ahora solo corre UNA vez: cuando el mecánico
    // aparece por primera vez. No se repite con cada actualización de posición.
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.car_repair_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
          ),
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppTheme.success,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.success.withValues(alpha: 0.4),
                    blurRadius: 4,
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
