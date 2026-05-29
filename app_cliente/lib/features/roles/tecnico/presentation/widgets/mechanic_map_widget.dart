import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MechanicMapWidget extends StatelessWidget {
  const MechanicMapWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Integrar métodos de geolocalización y WebSockets aquí o a través de providers
    // TODO: Escuchar la posición actual del mecánico

    return FlutterMap(
      options: const MapOptions(
        initialCenter: LatLng(-17.7833, -63.1821), // Centro mockeado (ej. Santa Cruz)
        initialZoom: 14.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.app_cliente',
        ),
        MarkerLayer(
          markers: [
            // Marcador del mecánico
            Marker(
              point: const LatLng(-17.7833, -63.1821),
              width: 40,
              height: 40,
              child: const Icon(
                Icons.build_circle,
                color: Colors.blue,
                size: 40,
              ),
            ),
            // Marcador de la emergencia mockeado
            Marker(
              point: const LatLng(-17.7850, -63.1800),
              width: 40,
              height: 40,
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 40,
              ),
            ),
          ],
        ),
        PolylineLayer(
          polylines: [
            // Ruta mockeada
            Polyline(
              points: const [
                LatLng(-17.7833, -63.1821),
                LatLng(-17.7850, -63.1800),
              ],
              color: Colors.blue,
              strokeWidth: 4.0,
            ),
          ],
        ),
      ],
    );
  }
}
