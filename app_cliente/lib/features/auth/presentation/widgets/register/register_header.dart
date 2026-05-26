import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/theme/app_theme.dart';

class RegisterHeader extends StatelessWidget {
  const RegisterHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Center(
          child: Hero(
            tag: 'logo',
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: AppTheme.softShadow,
              ),
              child: SvgPicture.asset(
                'assets/logo/logo-app-fixo.svg',
                height: 60,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Crea tu cuenta',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Únete a la red de asistencia mecánica más grande del país.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}