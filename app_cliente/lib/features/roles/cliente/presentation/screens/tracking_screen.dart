import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../../core/theme/app_theme.dart';
import '../providers/emergencia_provider.dart';
import '../providers/inicio_provider.dart';
import '../widgets/emergencia_map_widget.dart';
import '../widgets/review_modal.dart';
import 'payment_screen.dart';
import '../../../../shared/call/presentation/screens/call_screen.dart';
import 'dart:async';

// Pantalla principal de seguimiento de emergencia
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  EmergenciaFlowState? _lastFlowState;
  StreamSubscription? _wsCallSub;

  void _onProviderChange() {
    final provider = context.read<EmergenciaProvider>();
    if (_lastFlowState != provider.flowState) {
      if (_lastFlowState != null &&
          provider.flowState == EmergenciaFlowState.arrived) {
        _audioPlayer.play(AssetSource('sounds/notificacion-user.mp3'));
      }
      _lastFlowState = provider.flowState;
    }
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioPlayer.play(AssetSource('sounds/notificacion-user.mp3'));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<EmergenciaProvider>();
      _lastFlowState = provider.flowState;
      provider.addListener(_onProviderChange);
      
      _wsCallSub = provider.wsService.messageStream.listen((msg) {
        if (msg['type'] == 'CALL_OFFER') {
          if (!mounted) return;
          final senderId = msg['sender_id'];
          final asignacion = provider.asignacion;
          final tecnico = asignacion?.tecnicoAsignado;
          final mecanicoNombre = tecnico != null ? '${tecnico['nombre']}' : 'Técnico';
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                wsService: provider.wsService,
                contactName: mecanicoNombre,
                targetId: int.tryParse(senderId.toString()) ?? 0,
                isIncoming: true,
              ),
            ),
          );
        }
      });

      provider.onServiceFinished = () async {
        debugPrint('[TrackingScreen] onServiceFinished called');
        if (!mounted) return;
        
        final sucursalId = provider.asignacion?.sucursal?['id'];
        if (sucursalId != null) {
          await ReviewModal.show(context, sucursalId);
        }
        
        if (!mounted) return;
        provider.reset();
        Navigator.popUntil(context, (route) => route.isFirst);
      };

      provider.onPaymentRequired = (Map<String, dynamic> pagoData) async {
        debugPrint('[TrackingScreen] onPaymentRequired: $pagoData');
        if (!mounted) return;
        
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              pagoId: pagoData['pago_id'] as int,
              montoTotal: (pagoData['monto_total'] as num).toDouble(),
              comision: (pagoData['comision'] as num).toDouble(),
              montoTaller: (pagoData['monto_taller'] as num).toDouble(),
            ),
          ),
        );

        if (!mounted) return;
        if (result == true) {
          final sucursalId = provider.asignacion?.sucursal?['id'];
          if (sucursalId != null) {
            await ReviewModal.show(context, sucursalId);
          }
          if (!mounted) return;
          provider.reset();
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      };
    });
  }

  @override
  void dispose() {
    final provider = context.read<EmergenciaProvider>();
    provider.removeListener(_onProviderChange);
    _wsCallSub?.cancel();
    _animController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo iniciar la llamada'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final emProvider = context.read<EmergenciaProvider>();
    final asignacion = emProvider.asignacion;

    final sucursal = asignacion?.sucursal;
    final tallerNombre = sucursal?['taller_nombre'] ?? 'Taller Asignado';
    final telefono = sucursal?['telefono'] ?? '';

    final tecnico = asignacion?.tecnicoAsignado;
    final bool esAdmin = tecnico?['es_admin'] == true;
    final mecanicoNombre = tecnico != null
        ? '${tecnico['nombre']}'
        : 'Técnico';

    // Colores del tema claro
    const Color sheetBg = AppTheme.surfaceColor;
    const Color textColor = AppTheme.textPrimary;
    const Color greenAction = AppTheme.success; 

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
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.textPrimary,
              size: 20,
            ),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppTheme.surfaceColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text('¿Volver al inicio?', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                content: const Text('La asistencia seguirá en curso.', style: TextStyle(color: AppTheme.textSecondary)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                      emProvider.reset();
                    },
                    child: const Text(
                      'Volver',
                      style: TextStyle(color: AppTheme.danger),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: EmergenciaMapWidget(
              userLocation: context.read<InicioProvider>().userLocation,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _animController,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: AppTheme.bottomBarShadow,
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle de arrastre
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 16),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Selector<EmergenciaProvider, EmergenciaFlowState>(
                              selector: (_, p) => p.flowState,
                              builder: (context, flowState, child) {
                                if (flowState == EmergenciaFlowState.arrived) {
                                  return const Text(
                                    'El técnico ha llegado\ny está revisando tu vehículo',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  );
                                }
                                return Selector<EmergenciaProvider, String>(
                                  selector: (_, p) => p.etaText,
                                  builder: (context, etaValue, child) {
                                    final finalEta = etaValue != '--'
                                        ? etaValue
                                        : '${asignacion?.tiempoEstimado?.toStringAsFixed(0) ?? '--'} min';
                                    return Text(
                                      'Llegará aproximadamente\nen $finalEta',
                                      style: const TextStyle(
                                        color: textColor,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tallerNombre,
                                      style: const TextStyle(
                                          color: textColor, fontSize: 16),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        esAdmin ? 'ADMIN TALLER' : 'MECÁNICO',
                                        style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.car_repair_rounded,
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                  size: 40,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(color: Colors.grey.shade200, height: 1),
                      ),

                      // Botones estilo inDrive (Conductor, Contactar, Seguridad)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Info Perfil
                            Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                      child: const Icon(
                                        Icons.person_rounded,
                                        color: AppTheme.primaryColor,
                                        size: 30,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: -6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.star_rounded, 
                                                color: AppTheme.warning, size: 12),
                                            SizedBox(width: 2),
                                            Text(
                                              '5.0',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  mecanicoNombre,
                                  style: const TextStyle(
                                      color: textColor, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),

                            // Contactar
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                final tecnicoId = tecnico?['usuario_id'] ?? tecnico?['id'];
                                if (tecnicoId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CallScreen(
                                        wsService: emProvider.wsService,
                                        contactName: mecanicoNombre,
                                        targetId: int.parse(tecnicoId.toString()),
                                      ),
                                    ),
                                  );
                                } else if (telefono.isNotEmpty) {
                                  _makePhoneCall(telefono);
                                }
                              },
                              child: Column(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: const BoxDecoration(
                                          color: greenAction,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.phone_in_talk_rounded,
                                          color: Colors.black87,
                                          size: 24,
                                        ),
                                      ),
                                      Positioned(
                                        top: -2,
                                        right: -2,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: AppTheme.danger,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: AppTheme.surfaceColor, width: 2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Contactar al\ntécnico',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Seguridad
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Funcionalidad de seguridad en desarrollo')),
                                );
                              },
                              child: Column(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: const BoxDecoration(
                                          color: greenAction,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.shield_outlined,
                                          color: Colors.black87,
                                          size: 24,
                                        ),
                                      ),
                                      Positioned(
                                        top: -2,
                                        right: -2,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: AppTheme.danger,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: AppTheme.surfaceColor, width: 2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Seguridad\n',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      
                      // Cancelar botón
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.dangerSoft,
                              foregroundColor: AppTheme.danger,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Cancelar asistencia',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
