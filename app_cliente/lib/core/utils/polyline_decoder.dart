import 'package:latlong2/latlong.dart';

/// Utilidad pura para decodificar cadenas de Polyline (algoritmo de codificación de Google)
/// Devuelve una lista de coordenadas [LatLng] listas para usarse en flutter_map.
class PolylineDecoder {
  static List<LatLng> decode(String encodedPath) {
    int len = encodedPath.length;
    int index = 0;
    List<LatLng> path = [];
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int result = 1;
      int shift = 0;
      int b;
      do {
        b = encodedPath.codeUnitAt(index++) - 63 - 1;
        result += b << shift;
        shift += 5;
      } while (b >= 0x1f);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      result = 1;
      shift = 0;
      do {
        b = encodedPath.codeUnitAt(index++) - 63 - 1;
        result += b << shift;
        shift += 5;
      } while (b >= 0x1f);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      path.add(LatLng(lat * 1e-5, lng * 1e-5));
    }

    return path;
  }
}
