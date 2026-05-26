import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import 'dart:ui';

class MapCircleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const MapCircleButton({super.key, required this.icon, required this.onTap});

  @override
  State<MapCircleButton> createState() => _MapCircleButtonState();
}

class _MapCircleButtonState extends State<MapCircleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _isPressed ? 0.95 : 0.85),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isPressed ? 0.05 : 0.15),
                    blurRadius: _isPressed ? 4 : 12,
                    offset: Offset(0, _isPressed ? 2 : 6),
                  ),
                ],
              ),
              child: Icon(
                widget.icon, 
                size: 24, 
                color: _isPressed ? AppTheme.primaryColor : AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
