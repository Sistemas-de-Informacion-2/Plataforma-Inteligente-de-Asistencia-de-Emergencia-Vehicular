import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../data/models/diagnostico_model.dart';

/// Header del diagnostico de IA que se muestra en el BottomSheet de recomendaciones.
class AiDiagnosisHeader extends StatelessWidget {
  final DiagnosticoModel diagnostico;

  const AiDiagnosisHeader({super.key, required this.diagnostico});

  Color _gravedadColor(String? nivel) {
    switch (nivel?.toUpperCase()) {
      case 'CRITICO':
        return AppTheme.danger;
      case 'ALTO':
        return const Color(0xFFEA580C);
      case 'MEDIO':
        return AppTheme.warning;
      case 'BAJO':
        return AppTheme.success;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _gravedadIcon(String? nivel) {
    switch (nivel?.toUpperCase()) {
      case 'CRITICO':
        return Icons.gpp_maybe_rounded;
      case 'ALTO':
        return Icons.warning_amber_rounded;
      case 'MEDIO':
        return Icons.info_rounded;
      case 'BAJO':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.smart_toy_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _gravedadColor(diagnostico.nivelGravedad);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner superior con la gravedad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: color.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(
                    _gravedadIcon(diagnostico.nivelGravedad),
                    color: color,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'GRAVEDAD: ${diagnostico.nivelGravedad?.toUpperCase() ?? 'N/A'}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  if (diagnostico.prioridad != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        diagnostico.prioridad!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Contenido del Diagnostico
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.psychology_rounded,
                        color: AppTheme.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ANÁLISIS DE LA IA',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (diagnostico.problemaDetectado != null)
                    Text(
                      diagnostico.problemaDetectado!,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Footer sutil
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: Colors.amber.shade700,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sugerencia generada en tiempo real',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
