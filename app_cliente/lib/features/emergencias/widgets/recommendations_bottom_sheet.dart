import 'package:flutter/material.dart';
import 'package:fixo/core/theme/app_theme.dart';
import 'package:fixo/features/emergencias/domain/entities/recomendacion_result.dart';
import 'package:fixo/features/emergencias/domain/entities/sucursal_recomendada.dart';
import 'package:fixo/features/emergencias/widgets/ai_diagnosis_header.dart';
import 'package:fixo/features/emergencias/widgets/shop_recommendation_card.dart';

/// Bottom sheet scrollable con la lista de talleres recomendados.
class RecommendationsBottomSheet extends StatefulWidget {
  final RecomendacionResult result;
  final bool isSending;
  final int? selectedSucursalId;
  final int? waitingSucursalId;
  final ValueChanged<SucursalRecomendada> onSelectShop;

  const RecommendationsBottomSheet({
    super.key,
    required this.result,
    required this.onSelectShop,
    this.isSending = false,
    this.selectedSucursalId,
    this.waitingSucursalId,
  });

  @override
  State<RecommendationsBottomSheet> createState() => _RecommendationsBottomSheetState();
}

class _RecommendationsBottomSheetState extends State<RecommendationsBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sucursales = widget.result.sucursalesRecomendadas;
    final hasSucursales = sucursales.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.80,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ─────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Título ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Emergencia Reportada!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Elige un taller para atenderte',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Contenido scrollable ───────────────────────────
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shrinkWrap: true,
              children: [
                // Diagnóstico IA
                ExpansionTile(
                  title: const Text(
                    'Ver Diagnóstico IA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 16),
                  iconColor: AppTheme.primaryColor,
                  collapsedIconColor: AppTheme.textSecondary,
                  children: [
                    AiDiagnosisHeader(diagnostico: widget.result.diagnosticoIa),
                  ],
                ),
                const SizedBox(height: 12),

                // Título de sección
                Row(
                  children: [
                    const Icon(Icons.store_rounded, size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      hasSucursales
                          ? 'Talleres recomendados (${sucursales.length})'
                          : 'Sin talleres disponibles',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Lista de tarjetas con animación staggered
                if (hasSucursales)
                  ...List.generate(sucursales.length, (index) {
                    final delay = index * 0.12;
                    final itemAnimation = CurvedAnimation(
                      parent: _entranceController,
                      curve: Interval(
                        delay.clamp(0.0, 0.8),
                        (delay + 0.4).clamp(0.0, 1.0),
                        curve: Curves.easeOutCubic,
                      ),
                    );

                    return AnimatedBuilder(
                      animation: itemAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - itemAnimation.value)),
                          child: Opacity(
                            opacity: itemAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: ShopRecommendationCard(
                        sucursal: sucursales[index],
                        isSelected: widget.selectedSucursalId == sucursales[index].id,
                        isLoading: widget.isSending &&
                            widget.selectedSucursalId == sucursales[index].id,
                        isWaiting: widget.waitingSucursalId == sucursales[index].id,
                        isDisabled: widget.waitingSucursalId != null &&
                            widget.waitingSucursalId != sucursales[index].id,
                        onTap: () => widget.onSelectShop(sucursales[index]),
                      ),
                    );
                  })
                else
                  _buildEmptyState(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Estado vacío: no se encontraron talleres cercanos.
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.15)),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppTheme.warning),
          SizedBox(height: 12),
          Text(
            'No encontramos talleres cercanos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Intenta de nuevo más tarde o contacta soporte.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
