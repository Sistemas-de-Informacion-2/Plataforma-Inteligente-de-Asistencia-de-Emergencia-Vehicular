import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fixo/features/auth/providers/auth_provider.dart';
import 'package:fixo/features/auth/screens/login_screen.dart';
import 'package:fixo/features/home/screens/home_screen.dart';

// Widgets de splash
import 'package:fixo/features/auth/widgets/splash/splash_background.dart';
import 'package:fixo/features/auth/widgets/splash/splash_content.dart';
import 'package:fixo/features/auth/widgets/splash/splash_footer.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  bool _minTimeElapsed = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _fadeController.forward();

    // Tiempo mínimo de 5 segundos para apreciar el diseño
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _minTimeElapsed = true;
        });
        
        final authProvider = context.read<AuthProvider>();
        authProvider.checkAuthStatus();

        // Si ya sabemos el estado, navegamos inmediatamente después de los 5s
        if (authProvider.authStatus == AuthStatus.authenticated) {
          _navigateTo(const HomeScreen());
        } else if (authProvider.authStatus == AuthStatus.unauthenticated) {
          _navigateTo(const LoginScreen());
        }
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _navigateTo(Widget screen) {
    if (!_minTimeElapsed) return; // No navegar hasta que pasen los 5 segundos

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => screen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          // Lógica de navegación
          if (authProvider.authStatus == AuthStatus.authenticated) {
            _navigateTo(const HomeScreen());
          } else if (authProvider.authStatus == AuthStatus.unauthenticated) {
            _navigateTo(const LoginScreen());
          }
          
          return SplashBackground(
            child: Stack(
              children: [
                // Contenido central animado
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: const SplashContent(),
                  ),
                ),
                
                // Footer pegado abajo animado
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: const SplashFooter(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}