import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

// Widget que se muestra cuando el cliente no tiene vehículos registrados.
// Usa animación de entrada suave para una experiencia premium.
class EmptyGaraje extends StatefulWidget {
  final VoidCallback onAddTap;

  const EmptyGaraje({super.key, required this.onAddTap});

  @override
  State<EmptyGaraje> createState() => _EmptyGarajeState();
}

class _EmptyGarajeState extends State<EmptyGaraje>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _slideAnim;
  late final Animation<double> _iconAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _iconAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnim.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnim.value),
              child: child,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícono animado con capas concéntricas
              ScaleTransition(
                scale: _iconAnim,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Halo exterior difuso
                    Container(
                      width: 164,
                      height: 164,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Aro intermedio
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                    // Círculo central con gradiente
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.15),
                            AppTheme.primaryColor.withValues(alpha: 0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.12),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.garage_outlined,
                        size: 46,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Título
              const Text(
                'Tu Garaje está vacío',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              // Subtítulo
              Text(
                'Registra tus vehículos para que podamos\nasistirte mejor en caso de emergencia.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  height: 1.55,
                ),
              ),

              const SizedBox(height: 36),

              // Botón de acción primario
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: widget.onAddTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                  ).copyWith(
                    elevation: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.pressed)) return 0;
                      return 4;
                    }),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Añadir mi primer vehículo',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
