import 'package:flutter/material.dart';

//notificaciones push
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:fixo/features/notificaciones/services/push_notification_service.dart';

import 'package:provider/provider.dart';
import 'package:fixo/core/theme/app_theme.dart';
import 'package:fixo/features/auth/providers/auth_provider.dart';
import 'package:fixo/features/vehiculos/providers/vehiculo_provider.dart';
import 'package:fixo/features/perfil/providers/perfil_provider.dart';
import 'package:fixo/features/emergencias/providers/emergencia_provider.dart';
import 'package:fixo/features/emergencias/providers/inicio_provider.dart';
import 'package:fixo/features/auth/screens/splash_screen.dart';

void main()  async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PushNotificationService.initializeApp();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VehiculoProvider()),
        ChangeNotifierProvider(create: (_) => PerfilProvider()),
        ChangeNotifierProvider(create: (_) => EmergenciaProvider()),
        ChangeNotifierProvider(create: (_) => InicioProvider()),
      ],
      child: MaterialApp(
        title: 'Fixo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
