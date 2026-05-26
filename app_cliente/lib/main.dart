import 'package:flutter/material.dart';

//notificaciones push
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/network/push_notification_service.dart';

import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/roles/cliente/presentation/providers/vehiculo_provider.dart';
import 'features/shared/presentation/providers/perfil_provider.dart';
import 'features/roles/cliente/presentation/providers/emergencia_provider.dart';
import 'features/roles/cliente/presentation/providers/inicio_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';

void main()  async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PushNotificationService.initializeApp();
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final authProvider = ref.watch(authNotifierProvider);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => VehiculoProvider()),
        ChangeNotifierProvider(create: (_) => PerfilProvider()),
        ChangeNotifierProvider(create: (_) => EmergenciaProvider()),
        ChangeNotifierProvider(create: (_) => InicioProvider()),
      ],
      child: MaterialApp.router(
        title: 'Fixo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
  }
}
