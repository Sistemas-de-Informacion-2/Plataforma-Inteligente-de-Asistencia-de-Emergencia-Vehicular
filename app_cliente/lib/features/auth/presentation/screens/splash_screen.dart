import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Widgets de splash
import '../widgets/splash/splash_background.dart';
import '../widgets/splash/splash_content.dart';
import '../widgets/splash/splash_footer.dart';

/// SplashScreen ahora es puramente visual.
/// La lógica de redirección por rol se maneja en app_router.dart (redirect).
/// Cuando AuthProvider termina checkAuthStatus() y hace notifyListeners(),
/// GoRouter re-evalúa el redirect y navega automáticamente.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SplashBackground(
        child: Stack(
          children: [
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
      ),
    );
  }
}