import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

import '../../../../../core/theme/app_theme.dart';
import '../providers/mecanico_provider.dart';
import '../widgets/mechanic_map_widget.dart';
import '../widgets/mechanic_drawer_widget.dart';
import '../../../../shared/call/presentation/screens/call_screen.dart';

class TecnicoHomeScreen extends ConsumerStatefulWidget {
  const TecnicoHomeScreen({super.key});

  @override
  ConsumerState<TecnicoHomeScreen> createState() => _TecnicoHomeScreenState();
}

class _TecnicoHomeScreenState extends ConsumerState<TecnicoHomeScreen> 
    with WidgetsBindingObserver {
  bool _isDialogShowing = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _wsCallSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wsService = ref.read(mecanicoWsProvider);
      _wsCallSub = wsService.messageStream.listen((msg) {
        if (msg['type'] == 'CALL_OFFER') {
          if (!mounted) return;
          final senderId = msg['sender_id'];
          final state = ref.read(mecanicoControllerProvider);
          final clienteNombre = state.asignacion?.clienteNombre ?? 'Cliente';
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                wsService: wsService,
                contactName: clienteNombre,
                targetId: int.tryParse(senderId.toString()) ?? 0,
                isIncoming: true,
              ),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wsCallSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Forzar reconexión del WebSocket al volver del background
      final isOnline = ref.read(isOnlineProvider);
      if (isOnline) {
        ref.read(mecanicoWsProvider).forceReconnect();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(isOnlineProvider);

    // Escuchamos los cambios de estado para lanzar el Dialog cuando llegue un SOS
    ref.listen<MecanicoState>(mecanicoControllerProvider, (previous, next) {
      if (next.status == MecanicoStateStatus.sosRecibido && !_isDialogShowing && next.asignacion != null) {
        _isDialogShowing = true;
        _audioPlayer.play(AssetSource('sounds/uber2.mp3'));
        _mostrarDialogoAsignacion(context, next);
      } else if (next.status == MecanicoStateStatus.idle && _isDialogShowing) {
        // Si se cancela o hay timeout por parte del servidor, cerrar el diálogo
        _audioPlayer.stop();
        Navigator.of(context, rootNavigator: true).pop();
        _isDialogShowing = false;
      }
    });

    return Scaffold(
      drawer: const MechanicDrawerWidget(),
      body: Stack(
        children: [
          // Capa Fondo: Mapa Animado
          const MechanicMapWidget(),

          // Capa Superior: Top Bar Flotante
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Botón para abrir el menu
                  Builder(
                    builder: (context) {
                      return _GlassButton(
                        icon: CupertinoIcons.bars,
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      );
                    }
                  ),
                  
                  // Indicador de Turno / Conexión
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: AppTheme.cardShadow,
                      border: Border.all(
                        color: isOnline 
                            ? AppTheme.success.withValues(alpha: 0.3) 
                            : AppTheme.textSecondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isOnline ? AppTheme.success : AppTheme.textSecondary.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                            boxShadow: isOnline ? [
                              BoxShadow(color: AppTheme.success.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)
                            ] : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOnline ? 'En línea' : 'Desconectado',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: -0.2,
                            color: isOnline ? AppTheme.success : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Botón de notificaciones
                  _GlassButton(
                    icon: CupertinoIcons.bell_fill,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Próximamente: Historial de Notificaciones')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Overlay Inferior si está en ruta
          _buildEnRutaOverlay(),
        ],
      ),
    );
  }

  Widget _buildEnRutaOverlay() {
    final state = ref.watch(mecanicoControllerProvider);
    if (state.status != MecanicoStateStatus.enRuta || state.asignacion == null) {
      return const SizedBox.shrink();
    }
    
    return Align(
      alignment: Alignment.bottomCenter,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 100), // Espacio por si el FAB del mapa está debajo
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.success.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.location_fill, color: AppTheme.success, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'En ruta al cliente',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.success),
                        ),
                        Text(
                          'Dirígete al punto indicado',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente: ${state.asignacion!.clienteNombre}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Problema: ${state.asignacion!.problemaDetectado}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(CupertinoIcons.checkmark_alt_circle_fill),
                      label: const Text('Llegué al Destino', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        ref.read(mecanicoControllerProvider.notifier).arriveAtLocation();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  _GlassButton(
                    icon: CupertinoIcons.phone_fill,
                    onPressed: () {
                      if (state.asignacion?.clienteId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ID de cliente no disponible')),
                        );
                        return;
                      }
                      final wsService = ref.read(mecanicoWsProvider);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallScreen(
                            wsService: wsService,
                            contactName: state.asignacion!.clienteNombre,
                            targetId: state.asignacion!.clienteId!,
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
      ),
    );
  }

  void _mostrarDialogoAsignacion(BuildContext context, MecanicoState state) {
    final asignacion = state.asignacion;
    if (asignacion == null) return;
    
    final rejectReasonController = TextEditingController();
    bool isRejecting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      // Header de Alerta
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: AppTheme.danger, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '¡Nueva Emergencia!',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.danger, letterSpacing: -0.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      
                      // Detalles del cliente
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DialogInfoRow(icon: CupertinoIcons.car_fill, label: 'Vehículo', value: asignacion.vehiculoInfo),
                            const Divider(height: 24),
                            _DialogInfoRow(icon: CupertinoIcons.person_fill, label: 'Cliente', value: asignacion.clienteNombre),
                            const SizedBox(height: 16),
                            _ExpandableAiDiagnosisRow(diagnosis: asignacion.problemaDetectado),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Animación cruzada entre botones normales y formulario de rechazo
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: isRejecting
                            ? _buildRejectForm(
                                ctx, rejectReasonController, 
                                onCancel: () => setStateDialog(() => isRejecting = false),
                                onConfirm: () {
                                  if (rejectReasonController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Debes indicar un motivo de rechazo')),
                                    );
                                    return;
                                  }
                                  _audioPlayer.stop();
                                  ref.read(mecanicoControllerProvider.notifier).rejectJob(asignacion.id, rejectReasonController.text);
                                  Navigator.of(ctx).pop();
                                  _isDialogShowing = false;
                                }
                              )
                            : _buildAcceptRejectButtons(
                                ctx, asignacion.id,
                                onReject: () => setStateDialog(() => isRejecting = true),
                                onAccept: () {
                                  _audioPlayer.stop();
                                  ref.read(mecanicoControllerProvider.notifier).acceptJob(asignacion.id);
                                  Navigator.of(ctx).pop();
                                  _isDialogShowing = false;
                                }
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildAcceptRejectButtons(BuildContext ctx, int asignacionId, {required VoidCallback onReject, required VoidCallback onAccept}) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: onAccept,
            child: const Text('Aceptar Trabajo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onReject,
            child: const Text('Rechazar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildRejectForm(BuildContext ctx, TextEditingController controller, {required VoidCallback onCancel, required VoidCallback onConfirm}) {
    return Column(
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Motivo de rechazo (Obligatorio)',
            hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 13),
            filled: true,
            fillColor: AppTheme.backgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.12))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.danger, width: 1.5)),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Componentes Auxiliares ───────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        boxShadow: AppTheme.cardShadow,
      ),
      child: IconButton(
        icon: Icon(icon, color: AppTheme.inkDark, size: 22),
        onPressed: onPressed,
      ),
    );
  }
}

class _DialogInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DialogInfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpandableAiDiagnosisRow extends StatefulWidget {
  final String diagnosis;
  const _ExpandableAiDiagnosisRow({required this.diagnosis});

  @override
  State<_ExpandableAiDiagnosisRow> createState() => _ExpandableAiDiagnosisRowState();
}

class _ExpandableAiDiagnosisRowState extends State<_ExpandableAiDiagnosisRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: const Icon(Icons.psychology_rounded, color: AppTheme.primaryColor),
          title: const Text(
            'Diagnóstico IA',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
          ),
          onExpansionChanged: (val) => setState(() => _expanded = val),
          trailing: Icon(
            _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            color: AppTheme.primaryColor,
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.diagnosis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
