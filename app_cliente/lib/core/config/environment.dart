class Environment {
  static const String devBaseUrl = 'http://192.168.107.94:8000/api/v1';
  static const String prodBaseUrl = 'https://tu-api-prod.com/api/v1'; 

  // Determinar el ambiente actual (puede cambiarse a gusto o por variables de entorno)
  static const bool isProduccion = false;

  static String get baseUrl => isProduccion ? prodBaseUrl : devBaseUrl;
}
