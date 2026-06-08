import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/offline_utils.dart';
import '../providers/mecanico_provider.dart';
import '../../domain/entities/asignacion_entity.dart';

// ── Screen ────────────────────────────────────────────────────────────────────
class AsignacionesScreen extends ConsumerStatefulWidget {
  const AsignacionesScreen({super.key});

  @override
  ConsumerState<AsignacionesScreen> createState() => _AsignacionesScreenState();
}

class _AsignacionesScreenState extends ConsumerState<AsignacionesScreen>
    with SingleTickerProviderStateMixin {
  final _rejectReasonController = TextEditingController();
  late final TabController _tabController;
  bool _isRejecting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _rejectReasonController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers de estado ────────────────────────────────────────────────────────
  ({Color color, IconData icon, String label}) _estadoMeta(String estado) {
    return switch (estado) {
      'RECHAZADA'            => (color: AppTheme.danger,         icon: CupertinoIcons.xmark_circle_fill,    label: 'Rechazada'),
      'COMPLETADA' ||
      'FINALIZADO'           => (color: AppTheme.success,        icon: CupertinoIcons.checkmark_seal_fill,  label: 'Completada'),
      'PENDIENTE'            => (color: AppTheme.warning,        icon: CupertinoIcons.clock_fill,           label: 'Pendiente'),
      'ACEPTADA'  ||
      'EN_CAMINO' ||
      'EN_SITIO'             => (color: AppTheme.primaryColor,   icon: CupertinoIcons.location_fill,        label: estado.replaceAll('_', ' ')),
      _                      => (color: AppTheme.textSecondary,  icon: CupertinoIcons.info_circle_fill,     label: estado),
    };
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            error ? CupertinoIcons.xmark_circle : CupertinoIcons.checkmark_circle,
            color: Colors.white, size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: error ? AppTheme.danger : AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mecanicoControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.inkDark,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Mis Asignaciones',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Activas'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActivesTab(state: state, onRejecting: _setRejecting, isRejecting: _isRejecting, rejectCtrl: _rejectReasonController, showSnack: _showSnack),
          _HistorialTab(state: state, estadoMeta: _estadoMeta),
        ],
      ),
    );
  }

  void _setRejecting(bool v) => setState(() => _isRejecting = v);
}

// ── Actives Tab ───────────────────────────────────────────────────────────────

class _ActivesTab extends ConsumerWidget {
  final MecanicoState state;
  final bool isRejecting;
  final TextEditingController rejectCtrl;
  final void Function(bool) onRejecting;
  final void Function(String, {bool error}) showSnack;

  const _ActivesTab({
    required this.state,
    required this.isRejecting,
    required this.rejectCtrl,
    required this.onRejecting,
    required this.showSnack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.asignacion == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (state.status == MecanicoStateStatus.idle || state.asignacion == null) {
      return const _EmptyState(
        icon: CupertinoIcons.checkmark_shield,
        message: 'Sin asignaciones pendientes',
        subtitle: 'Cuando recibas un trabajo aparecerá aquí',
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: switch (state.status) {
        MecanicoStateStatus.enRuta  => _EnRutaCard(key: const ValueKey('enRuta'),   asignacion: state.asignacion!),
        MecanicoStateStatus.enSitio => _EnSitioCard(key: const ValueKey('enSitio'), asignacion: state.asignacion!, showSnack: showSnack),
        _                           => _SosCard(
            key: const ValueKey('sos'),
            asignacion: state.asignacion!,
            isRejecting: isRejecting,
            rejectCtrl: rejectCtrl,
            onRejecting: onRejecting,
            showSnack: showSnack,
          ),
      },
    );
  }
}

// ── Historial Tab ─────────────────────────────────────────────────────────────

class _HistorialTab extends StatelessWidget {
  final MecanicoState state;
  final ({Color color, IconData icon, String label}) Function(String) estadoMeta;

  const _HistorialTab({required this.state, required this.estadoMeta});

  @override
  Widget build(BuildContext context) {
    final historial = state.historial;

    if (historial.isEmpty) {
      return const _EmptyState(
        icon: CupertinoIcons.time,
        message: 'Sin historial aún',
        subtitle: 'Tus trabajos completados aparecerán aquí',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: historial.length,
      itemBuilder: (context, index) {
        final item = historial[index];
        final meta = estadoMeta(item.estado);
        return _HistorialCard(asignacion: item, meta: meta);
      },
    );
  }
}

// ── SOS Card (nueva asignación) ───────────────────────────────────────────────

class _SosCard extends ConsumerWidget {
  final dynamic asignacion;
  final bool isRejecting;
  final TextEditingController rejectCtrl;
  final void Function(bool) onRejecting;
  final void Function(String, {bool error}) showSnack;

  const _SosCard({
    super.key,
    required this.asignacion,
    required this.isRejecting,
    required this.rejectCtrl,
    required this.onRejecting,
    required this.showSnack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Banner de alerta
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.dangerSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                      color: AppTheme.danger, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('¡Nueva asignación!',
                          style: TextStyle(fontWeight: FontWeight.w700,
                              color: AppTheme.danger, fontSize: 14)),
                      Text('Solicitud #${asignacion.solicitudId}',
                          style: TextStyle(fontSize: 12,
                              color: AppTheme.danger.withValues(alpha: 0.7))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Detalle
          _InfoCard(children: [
            _InfoRow(
              icon: CupertinoIcons.wrench_fill,
              iconColor: AppTheme.warning,
              label: 'Problema',
              value: asignacion.problemaDetectado,
            ),
            _InfoRow(
              icon: CupertinoIcons.car_fill,
              iconColor: AppTheme.primaryColor,
              label: 'Vehículo',
              value: asignacion.vehiculoInfo,
            ),
            _InfoRow(
              icon: CupertinoIcons.person_fill,
              iconColor: AppTheme.success,
              label: 'Cliente',
              value: asignacion.clienteNombre,
            ),
          ]),
          const SizedBox(height: 20),

          // Acciones
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: isRejecting
                ? _RejectForm(
                    key: const ValueKey('rejectForm'),
                    controller: rejectCtrl,
                    onCancel: () => onRejecting(false),
                    onConfirm: () async {
                      if (await OfflineUtils.checkOfflineAndShowDialog(context)) return;
                      if (rejectCtrl.text.trim().isEmpty) {
                        showSnack('Debes indicar un motivo de rechazo', error: true);
                        return;
                      }
                      ref.read(mecanicoControllerProvider.notifier)
                          .rejectJob(asignacion.id, rejectCtrl.text);
                      onRejecting(false);
                      rejectCtrl.clear();
                    },
                  )
                : _ActionButtons(
                    key: const ValueKey('actionButtons'),
                    onReject: () => onRejecting(true),
                    onAccept: () async {
                      if (await OfflineUtils.checkOfflineAndShowDialog(context)) return;
                      ref.read(mecanicoControllerProvider.notifier)
                          .acceptJob(asignacion.id);
                      if (context.mounted && Navigator.canPop(context)) context.pop();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── En Ruta Card ──────────────────────────────────────────────────────────────

class _EnRutaCard extends ConsumerWidget {
  final dynamic asignacion;

  const _EnRutaCard({super.key, required this.asignacion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(CupertinoIcons.location_fill,
                      color: AppTheme.success, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Servicio en curso',
                          style: TextStyle(fontWeight: FontWeight.w700,
                              color: AppTheme.success, fontSize: 14)),
                      Text('Dirígete al punto de asistencia',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InfoCard(children: [
            _InfoRow(
              icon: CupertinoIcons.person_fill,
              iconColor: AppTheme.primaryColor,
              label: 'Cliente',
              value: asignacion.clienteNombre,
            ),
            _InfoRow(
              icon: CupertinoIcons.wrench_fill,
              iconColor: AppTheme.warning,
              label: 'Asistencia',
              value: asignacion.problemaDetectado,
            ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(CupertinoIcons.checkmark_circle_fill),
              label: const Text('Llegué al destino',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () async {
                if (await OfflineUtils.checkOfflineAndShowDialog(context)) return;
                ref.read(mecanicoControllerProvider.notifier).arriveAtLocation();
                if (context.mounted && Navigator.canPop(context)) context.pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── En Sitio Card ─────────────────────────────────────────────────────────────

class _EnSitioCard extends ConsumerStatefulWidget {
  final dynamic asignacion;
  final void Function(String, {bool error}) showSnack;

  const _EnSitioCard({super.key, required this.asignacion, required this.showSnack});

  @override
  ConsumerState<_EnSitioCard> createState() => _EnSitioCardState();
}

class _EnSitioCardState extends ConsumerState<_EnSitioCard> {
  // Controller propio del widget — se crea y destruye con él
  final _montoController = TextEditingController();

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(CupertinoIcons.wrench_fill,
                      color: AppTheme.warning, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trabajando en el sitio',
                          style: TextStyle(fontWeight: FontWeight.w700,
                              color: AppTheme.warning, fontSize: 14)),
                      Text('Ingresa el monto al finalizar',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InfoCard(children: [
            _InfoRow(
              icon: CupertinoIcons.person_fill,
              iconColor: AppTheme.primaryColor,
              label: 'Cliente',
              value: widget.asignacion.clienteNombre,
            ),
            _InfoRow(
              icon: CupertinoIcons.wrench_fill,
              iconColor: AppTheme.warning,
              label: 'Asistencia',
              value: widget.asignacion.problemaDetectado,
            ),
          ]),
          const SizedBox(height: 20),

          // Monto
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monto total a cobrar',
                    style: TextStyle(fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary, fontSize: 14)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _montoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    prefixText: 'Bs. ',
                    prefixStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.4),
                      fontSize: 22,
                    ),
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppTheme.textSecondary.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryColor, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(CupertinoIcons.money_dollar_circle_fill),
              label: const Text('Finalizar y cobrar',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () async {
                if (await OfflineUtils.checkOfflineAndShowDialog(context)) return;
                final montoStr = _montoController.text.trim();
                if (montoStr.isEmpty) {
                  widget.showSnack('Por favor ingresa el monto cobrado', error: true);
                  return;
                }
                final monto = double.tryParse(montoStr);
                if (monto == null || monto <= 0) {
                  widget.showSnack('Monto inválido', error: true);
                  return;
                }
                ref.read(mecanicoControllerProvider.notifier).finalizarTrabajo(monto);
                if (context.mounted && Navigator.canPop(context)) context.pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Historial Card ────────────────────────────────────────────────────────────

class _HistorialCard extends StatelessWidget {
  final AsignacionEntity asignacion;
  final ({Color color, IconData icon, String label}) meta;

  const _HistorialCard({required this.asignacion, required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(meta.icon, color: meta.color, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Asignación #${asignacion.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    meta.label,
                    style: TextStyle(
                      color: meta.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1,
              color: AppTheme.textSecondary.withValues(alpha: 0.08)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              children: [
                _InfoRow(
                  icon: CupertinoIcons.person_fill,
                  iconColor: AppTheme.primaryColor,
                  label: 'Cliente',
                  value: asignacion.clienteNombre,
                ),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: CupertinoIcons.wrench_fill,
                  iconColor: AppTheme.warning,
                  label: 'Problema',
                  value: asignacion.problemaDetectado,
                ),
                if (asignacion.estado == 'RECHAZADA' &&
                    asignacion.motivoRechazo != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(CupertinoIcons.chat_bubble_text_fill,
                            size: 14, color: AppTheme.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Motivo: ${asignacion.motivoRechazo}',
                            style: const TextStyle(
                              color: AppTheme.danger, fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reject Form ───────────────────────────────────────────────────────────────

class _RejectForm extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _RejectForm({
    super.key,
    required this.controller,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Motivo del rechazo',
              style: TextStyle(fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary, fontSize: 14)),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Describe el motivo...',
              hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                  fontSize: 13),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppTheme.textSecondary.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppTheme.primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(
                        color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancelar',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Confirmar rechazo',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Action Buttons ────────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final VoidCallback onReject;
  final VoidCallback onAccept;

  const _ActionButtons({super.key, required this.onReject, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(CupertinoIcons.xmark_circle, size: 18),
            label: const Text('Rechazar',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onReject,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(CupertinoIcons.checkmark_circle_fill, size: 18),
            label: const Text('Aceptar',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: onAccept,
          ),
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: children
            .expand((w) => [
                  w,
                  if (w != children.last)
                    Divider(
                      height: 20,
                      color: AppTheme.textSecondary.withValues(alpha: 0.08),
                    ),
                ])
            .toList(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38,
                  color: AppTheme.primaryColor.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}