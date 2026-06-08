import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';

// Widget que representa un botón circular flotante sobre el mapa.
// Soporta glassmorphism, haptic feedback y un badge numérico opcional.
class MapCircleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  /// Si se provee, muestra un badge rojo con el número en la esquina superior derecha.
  final int? badge;
  /// Color de acento del ícono cuando el botón está activo (presionado).
  final Color accentColor;

  const MapCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.badge,
    this.accentColor = AppTheme.primaryColor,
  });

  @override
  State<MapCircleButton> createState() => _MapCircleButtonState();
}

class _MapCircleButtonState extends State<MapCircleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnim;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    _pressController.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    _pressController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Cuerpo principal con glassmorphism
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isPressed
                        ? Colors.white.withValues(alpha: 0.98)
                        : Colors.white.withValues(alpha: 0.88),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isPressed
                          ? widget.accentColor.withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                    boxShadow: _isPressed
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.07),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : AppTheme.floatShadow,
                  ),
                  child: Icon(
                    widget.icon,
                    size: 22,
                    color: _isPressed
                        ? widget.accentColor
                        : AppTheme.textPrimary,
                  ),
                ),
              ),
            ),

            // Badge numérico (opcional)
            if (widget.badge != null && widget.badge! > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.danger.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    widget.badge! > 9 ? '9+' : '${widget.badge}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
