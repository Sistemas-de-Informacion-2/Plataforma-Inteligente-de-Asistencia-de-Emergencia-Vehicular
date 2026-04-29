import 'package:flutter/material.dart';
import 'package:fixo/core/theme/app_theme.dart';

class SplashFooter extends StatelessWidget {
  const SplashFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'FIXO',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Color(0xFF0A1F44),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tu taller de confianza en un toque',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}