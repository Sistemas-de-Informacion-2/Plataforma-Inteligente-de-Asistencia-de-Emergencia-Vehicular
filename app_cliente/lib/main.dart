import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_cliente/core/theme/app_theme.dart';
import 'package:app_cliente/features/auth/providers/auth_provider.dart';
import 'package:app_cliente/features/vehiculos/providers/vehiculo_provider.dart';
import 'package:app_cliente/features/perfil/providers/perfil_provider.dart';
import 'package:app_cliente/features/emergencias/providers/emergencia_provider.dart';
import 'package:app_cliente/features/auth/screens/splash_screen.dart';

void main() {
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
      ],
      child: MaterialApp(
        title: 'App de Emergencias',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
