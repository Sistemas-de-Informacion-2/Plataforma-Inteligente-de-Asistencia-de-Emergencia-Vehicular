import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// IMPORTANTE: Esta función debe estar fuera de la clase (top-level)
// Es la encargada de recibir notificaciones cuando la app está cerrada
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("[FCM] Mensaje recibido en background: ${message.messageId}");
}

// Instancia global de flutter_local_notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'emergencias', // id
  'Emergencias', // title
  description: 'Este canal se usa para notificaciones importantes de emergencias.', // description
  importance: Importance.max,
  playSound: true,
);

class PushNotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static String? _currentToken;

  /// Token FCM actual del dispositivo.
  static String? get currentToken => _currentToken;

  static Future<void> initializeApp() async {
    // 1. Pedir permisos al usuario
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Configurar flutter_local_notifications para notificaciones en foreground
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // 2. Obtener el Token del dispositivo
    _currentToken = await _firebaseMessaging.getToken();
    debugPrint('🔑 Token FCM del dispositivo: $_currentToken');

    // 3. Configurar los "escuchadores" de mensajes
    
    // A. App en Background o Cerrada
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // B. App Abierta (Foreground)
    FirebaseMessaging.onMessage.listen(_onMessageHandler);

    // C. Cuando el usuario toca la notificación (Background -> App)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenApp);

    // 4. Escuchar cambios de token (Firebase puede rotarlo)
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      debugPrint('🔑 Token FCM renovado: $newToken');
      _currentToken = newToken;
      _registrarTokenEnBackend(newToken);
    });
  }

  /// Envía el token FCM al backend para asociarlo con el usuario autenticado.
  /// Debe llamarse después del login exitoso.
  static Future<void> registrarTokenEnBackend() async {
    if (_currentToken == null) {
      debugPrint('[FCM] No hay token FCM disponible.');
      return;
    }
    await _registrarTokenEnBackend(_currentToken!);
  }

  static Future<void> _registrarTokenEnBackend(String token) async {
    try {
      final apiClient = ApiClient();
      await apiClient.instance.post(
        '/dispositivos/registrar-token',
        data: {'token': token},
      );
      debugPrint('[FCM] ✅ Token registrado en backend.');
    } catch (e) {
      debugPrint('[FCM] ⚠️ Error registrando token en backend: $e');
    }
  }

  static void _onMessageHandler(RemoteMessage message) {
    debugPrint('📩 Push en foreground: ${message.notification?.title} - ${message.notification?.body}');
    
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        id: notification.hashCode, 
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: android.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  }

  static void _onMessageOpenApp(RemoteMessage message) {
    debugPrint('👆 El usuario tocó la notificación: ${message.data}');
    // TODO: Navegar a la pantalla correspondiente según message.data
  }
}