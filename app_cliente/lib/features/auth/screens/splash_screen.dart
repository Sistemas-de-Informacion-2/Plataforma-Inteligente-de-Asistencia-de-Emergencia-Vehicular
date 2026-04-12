import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_cliente/features/auth/providers/auth_provider.dart';
import 'package:app_cliente/features/auth/screens/login_screen.dart';
import 'package:app_cliente/features/home/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Añadimos un pequeño delay para que se vea el logo/splash (es la versión temporal)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        context.read<AuthProvider>().checkAuthStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          // Escuchamos el estado, si cambia a authenticated vamos as Home
          if (authProvider.authStatus == AuthStatus.authenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            });
          } else if (authProvider.authStatus == AuthStatus.unauthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            });
          }
          
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.car_crash,
                  size: 100,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Cargando...',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
