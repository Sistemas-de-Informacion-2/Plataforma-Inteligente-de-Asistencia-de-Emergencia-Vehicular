import 'package:flutter/material.dart';
import 'package:fixo/core/theme/app_theme.dart';

class SplashBackground extends StatelessWidget {
  final Widget child;

  const SplashBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            AppTheme.backgroundColor.withOpacity(0.5),
          ],
        ),
      ),
      child: child,
    );
  }
}