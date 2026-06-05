import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/emergencia_provider.dart';
import '../providers/inicio_provider.dart';
import '../widgets/emergencia_map_widget.dart';
import 'package:lottie/lottie.dart';
import '../../../../../core/theme/app_theme.dart';

import 'tracking_screen.dart';

class RadarEsperaScreen extends StatefulWidget {
  const RadarEsperaScreen({super.key});

  @override
  State<RadarEsperaScreen> createState() => _RadarEsperaScreenState();
}

class _RadarEsperaScreenState extends State<RadarEsperaScreen> {
  bool _iaExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final emProvider = context.read<EmergenciaProvider>();
      emProvider.onPujaAceptadaCallback = () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const TrackingScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final emProvider = context.watch<EmergenciaProvider>();
    final pujas = emProvider.pujasActivas;
    final isWaiting = emProvider.flowState == EmergenciaFlowState.waitingForMechanic;
    final hasIaDiagnosis = emProvider.recomendaciones?.diagnosticoIa != null;
    final hasPujas = pujas.isNotEmpty && !isWaiting;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: AppTheme.floatShadow,
            ),
            child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. Mapa de fondo
          Positioned.fill(
            child: EmergenciaMapWidget(
              userLocation: context.read<InicioProvider>().userLocation,
            ),
          ),

          // 2. Zona central: Lottie + texto de estado (sin solapar)
          if (!hasPujas)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lottie radar animation — libre y visible
                  IgnorePointer(
                    child: Lottie.asset(
                      'assets/animaciones/location-search.json',
                      width: 240,
                      height: 240,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Pill status debajo de la animación
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.floatShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isWaiting
                                ? AppTheme.warning.withValues(alpha: 0.15)
                                : AppTheme.primaryColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isWaiting ? Icons.hourglass_top_rounded : Icons.radar_rounded,
                            color: isWaiting ? AppTheme.warning : AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isWaiting ? 'Esperando confirmación...' : 'Buscando talleres cercanos',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isWaiting
                                    ? 'El taller asignará a un técnico pronto'
                                    : 'Recibiendo ofertas en tiempo real',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
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

          // 3. Panel inferior: IA diagnosis + cancelar (cuando NO hay pujas)
          if (!hasPujas)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: AppTheme.bottomBarShadow,
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),

                        // IA Diagnosis expandable
                        if (hasIaDiagnosis && !isWaiting) ...[
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _iaExpanded = !_iaExpanded);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3EEFF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFB388FF).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFB388FF).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.smart_toy_rounded, color: Color(0xFF7C4DFF), size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Text(
                                          'Diagnóstico IA',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF7C4DFF),
                                          ),
                                        ),
                                      ),
                                      if (emProvider.recomendaciones!.diagnosticoIa.nivelGravedad != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.danger.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            emProvider.recomendaciones!.diagnosticoIa.nivelGravedad!,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.danger,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      Icon(
                                        _iaExpanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        color: AppTheme.textSecondary,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                  if (_iaExpanded) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      emProvider.recomendaciones!.diagnosticoIa.problemaDetectado ?? 'Evaluando...',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondary,
                                        fontStyle: FontStyle.italic,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Cancel button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () async {
                              HapticFeedback.mediumImpact();
                              final confirmar = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppTheme.surfaceColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: const Text(
                                    'Cancelar Solicitud',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  content: const Text(
                                    '¿Estás seguro de que deseas cancelar tu solicitud de emergencia?',
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('No', style: TextStyle(color: AppTheme.textSecondary)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Sí, Cancelar', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmar == true) {
                                await emProvider.cancelarSolicitud();
                                if (context.mounted) {
                                  Navigator.popUntil(context, (route) => route.isFirst);
                                }
                              }
                            },
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Cancelar Solicitud'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.danger,
                              backgroundColor: AppTheme.dangerSoft,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 4. Panel de ofertas con DraggableScrollableSheet (cuando HAY pujas)
          if (hasPujas)
            DraggableScrollableSheet(
              initialChildSize: 0.45,
              minChildSize: 0.25,
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.25, 0.45, 0.85],
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: AppTheme.bottomBarShadow,
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${pujas.length} Oferta${pujas.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, color: AppTheme.success, size: 8),
                                  SizedBox(width: 6),
                                  Text(
                                    'En vivo',
                                    style: TextStyle(
                                      color: AppTheme.success,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(color: Colors.grey.shade200, height: 1),
                      // List
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: pujas.length,
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          itemBuilder: (context, index) {
                            return PujaCardItem(
                              key: ValueKey(pujas[index]['id']),
                              puja: pujas[index],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PujaCardItem — Tarjeta de oferta individual con timer y acciones
// ─────────────────────────────────────────────────────────────────────────────

class PujaCardItem extends StatefulWidget {
  final Map<String, dynamic> puja;

  const PujaCardItem({super.key, required this.puja});

  @override
  State<PujaCardItem> createState() => _PujaCardItemState();
}

class _PujaCardItemState extends State<PujaCardItem> with SingleTickerProviderStateMixin {
  late AnimationController _timerController;
  final int _totalSeconds = 30;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    )..forward();

    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          context.read<EmergenciaProvider>().rechazarPuja(widget.puja['id']);
        }
      }
    });
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emProvider = context.read<EmergenciaProvider>();
    final puja = widget.puja;
    final tallerNombre = puja['taller_nombre'] ?? puja['sucursal_nombre'] ?? 'Taller Mecánico';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: const Icon(Icons.handyman_rounded, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 14),
                // Info del Taller
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tallerNombre,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _InfoTag(
                            icon: Icons.star_rounded,
                            iconColor: AppTheme.warning,
                            text: puja['rating']?.toString() ?? '5.0',
                          ),
                          _InfoTag(
                            icon: Icons.location_on_rounded,
                            iconColor: AppTheme.textSecondary,
                            text: '${puja['distancia_km']} km',
                          ),
                          _InfoTag(
                            icon: Icons.timer_rounded,
                            iconColor: AppTheme.textSecondary,
                            text: '${puja['tiempo_llegada_minutos']} min',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Precio
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Bs. ${puja['precio_estimado']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedBuilder(
                      animation: _timerController,
                      builder: (context, child) {
                        final remaining = _totalSeconds - (_timerController.value * _totalSeconds).floor();
                        final isCritical = remaining <= 5;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isCritical
                                ? AppTheme.dangerSoft
                                : AppTheme.muted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${remaining}s',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isCritical ? AppTheme.danger : AppTheme.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Timer progress bar
          AnimatedBuilder(
            animation: _timerController,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: 1.0 - _timerController.value,
                backgroundColor: AppTheme.muted,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _timerController.value > 0.8 ? AppTheme.danger : AppTheme.success,
                ),
                minHeight: 3,
              );
            },
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14, top: 12),
            child: Row(
              children: [
                // Reject button
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    emProvider.rechazarPuja(puja['id']);
                  },
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.muted,
                    foregroundColor: AppTheme.textSecondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size(50, 50),
                  ),
                ),
                const SizedBox(width: 12),
                // Accept button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      emProvider.aceptarPuja(puja['id']);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Aceptar Oferta',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Small reusable info tag (icon + text)
class _InfoTag extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _InfoTag({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
