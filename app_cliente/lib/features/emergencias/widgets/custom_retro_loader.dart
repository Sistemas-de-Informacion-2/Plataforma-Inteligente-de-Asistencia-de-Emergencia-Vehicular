import 'package:flutter/material.dart';
import 'package:fixo/core/theme/app_theme.dart';
import 'dart:math' as math;

/// Un loader premium estilo retro animado (1920s) con el personaje Mickey Mouse arreglando un auto.
class CustomRetroLoader extends StatefulWidget {
  final String text;

  const CustomRetroLoader({
    super.key,
    required this.text,
  });

  @override
  State<CustomRetroLoader> createState() => _CustomRetroLoaderState();
}

class _CustomRetroLoaderState extends State<CustomRetroLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Animación continua para los engranajes o elementos de carga
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Animación Retro + Engranajes ──
            SizedBox(
              height: 90,
              width: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Engranaje trasero (gira a la izquierda)
                  Positioned(
                    left: 0,
                    top: 10,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (_, child) {
                        return Transform.rotate(
                          angle: -_controller.value * 2 * math.pi,
                          child: Icon(
                            Icons.settings,
                            color: Colors.grey.shade300,
                            size: 32,
                          ),
                        );
                      },
                    ),
                  ),
                  // Engranaje superior derecho (gira a la derecha)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (_, child) {
                        return Transform.rotate(
                          angle: _controller.value * 2 * math.pi,
                          child: Icon(
                            Icons.settings,
                            color: AppTheme.warning.withOpacity(0.4),
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                  // Imagen retro (Mickey mecánico)
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      // Pequeño rebote (rubber hose style)
                      final offset = math.sin(_controller.value * math.pi * 4) * 3;
                      return Transform.translate(
                        offset: Offset(0, offset),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      'assets/images/retro_mechanic.png',
                      width: 65,
                      height: 65,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback si la imagen no se carga
                        return const CircularProgressIndicator(
                          color: AppTheme.danger,
                          strokeWidth: 3,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // ── Texto Dinámico ──
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.danger,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.text,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
