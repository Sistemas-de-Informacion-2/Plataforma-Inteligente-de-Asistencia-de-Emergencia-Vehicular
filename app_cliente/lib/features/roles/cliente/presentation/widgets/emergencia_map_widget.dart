import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
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
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  // Coordenadas de Santa Cruz, Bolivia por defecto
  final LatLng _defaultLocation = const LatLng(-17.7833, -63.1821);

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EmergenciaMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userLocation != null &&
        widget.userLocation != oldWidget.userLocation) {
      _mapController.move(widget.userLocation!, 15.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = widget.userLocation ?? _defaultLocation;
    final provider = context.watch<EmergenciaProvider>();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: currentLocation,
        initialZoom: 14.0,
        keepAlive: true,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.it_nomads.app_cliente',
        ),
        
        // Capa de ruta
        if (provider.polylineCoords.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: provider.polylineCoords,
                color: AppTheme.primaryColor.withValues(alpha: 0.8),
                strokeWidth: 5.0,
              ),
            ],
          ),

        // Marcador del Cliente
        if (widget.userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.userLocation!,
                width: 72,
                height: 72,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.floatShadow,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.my_location_rounded,
                            color: AppTheme.danger,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

        // Marcador del Mecánico
        if (provider.mechanicLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: provider.mechanicLocation!,
                width: 60,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.floatShadow,
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.engineering_rounded,
                      color: AppTheme.primaryColor,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
