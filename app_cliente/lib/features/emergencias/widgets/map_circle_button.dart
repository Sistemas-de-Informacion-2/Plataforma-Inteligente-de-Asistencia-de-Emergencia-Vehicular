import 'package:flutter/material.dart';
import 'package:app_cliente/core/theme/app_theme.dart';

class MapCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const MapCircleButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: AppTheme.glassCircle(),
        child: Icon(icon, size: 22, color: AppTheme.textPrimary),
      ),
    );
  }
}
