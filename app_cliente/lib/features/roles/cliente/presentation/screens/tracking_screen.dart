import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lottie/lottie.dart';
import '../../../../../core/theme/app_theme.dart';
import '../providers/emergencia_provider.dart';
import '../providers/inicio_provider.dart';
import '../widgets/emergencia_map_widget.dart';
import '../widgets/review_modal.dart';
import 'payment_screen.dart';
import '../../../../shared/call/presentation/screens/call_screen.dart';
import 'dart:async';

/// Pantalla principal de seguimiento de emergencia.
/// Muestra el mapa con la ubicación del mecánico y un bottom sheet
/// con la información del servicio según el estado del flujo.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  EmergenciaFlowState? _lastFlowState;
  StreamSubscription? _wsCallSub;

  // ── Datos estáticos cacheados (no cambian durante el tracking) ──
  late final String _tallerNombre;
  late final String _telefono;
  late final String _mecanicoNombre;
  late final bool _esAdmin;
  late final Map<String, dynamic>? _tecnico;

  void _onProviderChange() {
    final provider = context.read<EmergenciaProvider>();
    if (_lastFlowState != provider.flowState) {
      if (_lastFlowState != null &&
          provider.flowState == EmergenciaFlowState.arrived) {
        _audioPlayer.play(AssetSource('sounds/notificacion-user.mp3'));
      }
      _lastFlowState = provider.flowState;
      if (mounted) setState(() {}); // Rebuild bottom sheet for state change
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    _audioPlayer.play(AssetSource('sounds/notificacion-user.mp3'));

    // Cachear datos estáticos que NO cambian durante el tracking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<EmergenciaProvider>();
      final asignacion = provider.asignacion;
      final sucursal = asignacion?.sucursal;

      _tallerNombre = sucursal?['taller_nombre'] ?? 'Taller Asignado';
      _telefono = sucursal?['telefono'] ?? '';
      _tecnico = asignacion?.tecnicoAsignado;
      _esAdmin = _tecnico?['es_admin'] == true;
      _mecanicoNombre = _tecnico != null ? '${_tecnico['nombre']}' : 'Técnico';

      _lastFlowState = provider.flowState;
      provider.addListener(_onProviderChange);

      _wsCallSub = provider.wsService.messageStream.listen((msg) {
        if (msg['type'] == 'CALL_OFFER') {
          if (!mounted) return;
          final senderId = msg['sender_id'];
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                wsService: provider.wsService,
                contactName: _mecanicoNombre,
                targetId: int.tryParse(senderId.toString()) ?? 0,
                isIncoming: true,
              ),
            ),
          );
        }
      });

      // Ya no usamos onServiceFinished para abrir reseña.
      // SERVICIO_FINALIZADO ahora solo cambia el flowState a serviceFinished.
      // La reseña se abre DESPUÉS del pago.
      provider.onServiceFinished = null;

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
          // Pago exitoso → Mostrar reseña
          final sucursalId = provider.asignacion?.sucursal?['id'];
          if (sucursalId != null) {
            await ReviewModal.show(context, sucursalId);
          }
          if (!mounted) return;
          // Primero navegar, luego resetear (evita el crash _elements.contains)
          Navigator.popUntil(context, (route) => route.isFirst);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.reset();
          });
        }
      };
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final provider = context.read<EmergenciaProvider>();
    provider.removeListener(_onProviderChange);
    _wsCallSub?.cancel();
    _animController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Forzar reconexión del WebSocket al volver del background
      final provider = context.read<EmergenciaProvider>();
      provider.wsService.forceReconnect();
    }
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
            final emProvider = context.read<EmergenciaProvider>();
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
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        emProvider.reset();
                      });
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
                  color: AppTheme.surfaceColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: AppTheme.bottomBarShadow,
                ),
                child: SafeArea(
                  top: false,
                  child: _buildBottomSheetContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el contenido del bottom sheet según el flowState actual.
  Widget _buildBottomSheetContent() {
    return Selector<EmergenciaProvider, EmergenciaFlowState>(
      selector: (_, p) => p.flowState,
      builder: (context, flowState, _) {
        if (flowState == EmergenciaFlowState.arrived) {
          return _buildArrivedContent();
        } else if (flowState == EmergenciaFlowState.serviceFinished) {
          return _buildServiceFinishedContent();
        } else {
          return _buildTrackingContent();
        }
      },
    );
  }

  /// Estado: Mecánico en camino (ETA, info del taller, botones)
  Widget _buildTrackingContent() {
    const Color textColor = AppTheme.textPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDragHandle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ETA text — solo esto se reconstruye con cada update
              Selector<EmergenciaProvider, String>(
                selector: (_, p) => p.etaText,
                builder: (context, etaValue, child) {
                  final provider = context.read<EmergenciaProvider>();
                  final asignacion = provider.asignacion;
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
              ),
              const SizedBox(height: 16),
              _buildTallerInfo(textColor),
            ],
          ),
        ),
        _buildDivider(),
        _buildActionButtons(textColor),
        const SizedBox(height: 24),
        _buildCancelButton(),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Estado: Mecánico ha llegado y está trabajando
  Widget _buildArrivedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDragHandle(),
        // Animación Lottie auto-user
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SizedBox(
            height: 120,
            child: Lottie.asset(
              'assets/animaciones/auto-user.json',
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              Text(
                'El técnico ha llegado',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Mecánico trabajando en tu vehículo',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Solo botón de contactar al técnico
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.phone_in_talk_rounded),
              label: const Text('Contactar al técnico', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                final tecnicoId = _tecnico?['usuario_id'] ?? _tecnico?['id'];
                if (tecnicoId != null) {
                  final provider = context.read<EmergenciaProvider>();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CallScreen(
                        wsService: provider.wsService,
                        contactName: _mecanicoNombre,
                        targetId: int.parse(tecnicoId.toString()),
                      ),
                    ),
                  );
                } else if (_telefono.isNotEmpty) {
                  _makePhoneCall(_telefono);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Estado: Servicio finalizado, esperando datos de pago
  Widget _buildServiceFinishedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDragHandle(),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
          ),
          child: const Column(
            children: [
              Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 48),
              SizedBox(height: 12),
              Text(
                'Servicio Finalizado',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Procesando cobro...\nEn unos segundos te aparecerán las opciones de pago.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Componentes reutilizables ─────────────────────────────────

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 16),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildTallerInfo(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tallerNombre,
                style: TextStyle(color: textColor, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _esAdmin ? 'ADMIN TALLER' : 'MECÁNICO',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.car_repair_rounded,
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          size: 40,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Divider(color: Colors.grey.shade200, height: 1),
    );
  }

  Widget _buildActionButtons(Color textColor) {
    return Padding(
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
                    child: const Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: 30),
                  ),
                  Positioned(
                    bottom: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, color: AppTheme.warning, size: 12),
                          SizedBox(width: 2),
                          Text('5.0', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _mecanicoNombre,
                style: TextStyle(color: textColor, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),

          // Contactar
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              final tecnicoId = _tecnico?['usuario_id'] ?? _tecnico?['id'];
              if (tecnicoId != null) {
                final provider = context.read<EmergenciaProvider>();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallScreen(
                      wsService: provider.wsService,
                      contactName: _mecanicoNombre,
                      targetId: int.parse(tecnicoId.toString()),
                    ),
                  ),
                );
              } else if (_telefono.isNotEmpty) {
                _makePhoneCall(_telefono);
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
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.phone_in_talk_rounded, color: Colors.black87, size: 24),
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
                          border: Border.all(color: AppTheme.surfaceColor, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Contactar al\ntécnico',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor, fontSize: 13, height: 1.1),
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
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: Colors.black87, size: 24),
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
                          border: Border.all(color: AppTheme.surfaceColor, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Seguridad\n',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor, fontSize: 13, height: 1.1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
