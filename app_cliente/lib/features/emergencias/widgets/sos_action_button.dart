import 'package:flutter/material.dart';

class SOSActionButton extends StatefulWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const SOSActionButton({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<SOSActionButton> createState() => _SOSActionButtonState();
}

class _SOSActionButtonState extends State<SOSActionButton> {
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.backgroundColor.withValues(alpha: 0.85),
                widget.backgroundColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              // Sombra principal que se reduce al presionar
              BoxShadow(
                color: widget.backgroundColor.withValues(alpha: _isPressed ? 0.15 : 0.35),
                blurRadius: _isPressed ? 6 : 14,
                offset: Offset(0, _isPressed ? 2 : 6),
              ),
              // Sombra blanca superior (inner glow simulado) para dar efecto 3D
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.25),
                offset: const Offset(-1.5, -1.5),
                blurRadius: 2,
              ),
            ],
          ),
          child: Icon(
            widget.icon, 
            color: widget.iconColor, 
            size: 24, // Icono un poco más grande
          ),
        ),
      ),
    );
  }
}
