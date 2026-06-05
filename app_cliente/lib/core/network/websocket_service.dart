import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../config/environment.dart';
import '../storage/secure_storage.dart';

/// Servicio de WebSocket para recibir notificaciones en tiempo real.
/// Se conecta al canal WS del backend usando el JWT almacenado.
/// Expone un [messageStream] broadcast para que múltiples listeners
/// puedan escuchar los eventos entrantes.
///
/// Incluye auto-reconexión con backoff exponencial en caso de
/// desconexión inesperada (ej: reinicio del servidor).
class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream público de mensajes parseados del WS.
  Stream<Map<String, dynamic>> get messageStream => _controller.stream;

  /// Indica si hay una conexión activa.
  bool get isConnected => _channel != null;

  // ── Reconexión ──────────────────────────────────────────────
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 15;
  static const int _maxBackoffSeconds = 30;
  Timer? _reconnectTimer;

  /// Conecta al WebSocket de notificaciones.
  Future<void> connect() async {
    // Evitar conexiones duplicadas
    if (_channel != null) {
      debugPrint('[WS] Ya conectado, ignorando reconexión.');
      return;
    }

    final token = await SecureStorage.getToken();
    if (token == null) {
      debugPrint('[WS] No hay token JWT, abortando conexión.');
      return;
    }

    // Asegurarse de reemplazar explícitamente http por ws (y https por wss)
    String wsUrl = Environment.baseUrl.replaceFirst('http', 'ws');
    if (!wsUrl.endsWith('/')) {
      wsUrl += '/';
    }
    // El backend recibe el ID desde el token, la ruta es /ws/notificaciones/
    wsUrl += 'ws/notificaciones/?token=$token';

    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;
      
      // Conexión exitosa — resetear contador de intentos
      _reconnectAttempts = 0;
      _shouldReconnect = true;
      debugPrint('[WS] ✅ Conexión establecida.');

      _channel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> message =
                jsonDecode(data as String) as Map<String, dynamic>;
            debugPrint('[WS] Mensaje recibido: ${message['type']}');
            _controller.add(message);
          } catch (e) {
            debugPrint('[WS] Error parseando mensaje: $e');
          }
        },
        onError: (error) {
          debugPrint('[WS] ⚠️ Error en stream: $error');
          _channel = null;
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[WS] Conexión cerrada por el servidor.');
          _channel = null;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[WS] ❌ Error al conectar: $e');
      _channel = null;
      _scheduleReconnect();
    }
  }

  /// Programa un intento de reconexión con backoff exponencial.
  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[WS] ⛔ Máximo de intentos alcanzado ($_maxReconnectAttempts). Deteniendo reconexión.');
      return;
    }

    _reconnectTimer?.cancel();

    // Backoff exponencial: 2s, 4s, 8s, 16s... hasta max 30s
    final delaySeconds = min(pow(2, _reconnectAttempts + 1).toInt(), _maxBackoffSeconds);
    _reconnectAttempts++;

    debugPrint('[WS] 🔄 Reconectando en ${delaySeconds}s (intento $_reconnectAttempts/$_maxReconnectAttempts)...');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      connect();
    });
  }

  /// Envía un mensaje JSON al backend si está conectado.
  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    } else {
      debugPrint('[WS] No se pudo enviar el mensaje, WebSocket no conectado.');
    }
  }

  /// Cierra la conexión WebSocket limpiamente.
  /// No intenta reconectar tras un cierre manual.
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _channel?.sink.close();
    _channel = null;
    debugPrint('[WS] Desconectado manualmente.');
  }

  /// Libera recursos del servicio.
  void dispose() {
    disconnect();
    _controller.close();
  }
}
