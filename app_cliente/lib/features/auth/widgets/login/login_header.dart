import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fixo/core/theme/app_theme.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppTheme.softShadow,
            ),
            child: SvgPicture.asset(
              'assets/logo/logo-app-fixo.svg',
              height: 100,
              placeholderBuilder: (context) => const SizedBox(
                height: 100,
                width: 100,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          '¡Hola de nuevo!',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Te extrañamos. Ingresa tus credenciales para continuar.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}