import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import '../../../../../core/theme/app_theme.dart';

class SplashContent extends StatelessWidget {
  const SplashContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Hero(
          tag: 'logo',
          child: SvgPicture.asset('assets/logo/logo-app-fixo.svg', height: 120),
        ),
        const SizedBox(height: 10),

        // Animación Lottie (La tuerca)
        Lottie.asset(
          'assets/animaciones/tuerca-cargando.json',
          width: 180,
          height: 180,
          fit: BoxFit.contain,
        ),

        const SizedBox(height: 20),

        // Texto de carga sutil
        Text(
          'PREPARANDO ASISTENCIA',
          style: TextStyle(
            color: AppTheme.primaryColor.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 3.0,
          ),
        ),
      ],
    );
  }
}
