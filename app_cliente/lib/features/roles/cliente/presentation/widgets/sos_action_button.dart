import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Widget que representa un botón de acción secundario dentro de la barra SOS.
// Usa AnimationController para un press feedback suave con haptic.
class SOSActionButton extends StatefulWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  /// Etiqueta opcional debajo del botón (útil para accesibilidad).
  final String? tooltip;

  const SOSActionButton({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
    this.tooltip,
  });

  @override
  State<SOSActionButton> createState() => _SOSActionButtonState();
}

class _SOSActionButtonState extends State<SOSActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.87).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.backgroundColor.withValues(alpha: 0.8),
                widget.backgroundColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.backgroundColor.withValues(alpha: 0.38),
                blurRadius: 14,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.22),
                offset: const Offset(-1, -1),
                blurRadius: 3,
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: widget.iconColor,
            size: 24,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}
