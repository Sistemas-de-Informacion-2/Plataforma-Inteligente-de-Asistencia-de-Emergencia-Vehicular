import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../../core/theme/app_theme.dart';
import '../providers/emergencia_provider.dart';
import '../providers/inicio_provider.dart';
import '../widgets/emergencia_map_widget.dart';
import 'widgets/review_modal.dart';
import 'payment_screen.dart';

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

  void _onProviderChange() {
    final provider = context.read<EmergenciaProvider>();
    if (_lastFlowState != provider.flowState) {
      if (_lastFlowState != null && provider.flowState == EmergenciaFlowState.arrived) {
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

    // Optimización: Pre-cargar y configurar modo
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
    
    // Reproducir inmediatamente al montar
    _audioPlayer.play(AssetSource('sounds/notificacion-user.mp3'));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<EmergenciaProvider>();
      _lastFlowState = provider.flowState;
      provider.addListener(_onProviderChange);

      // Callback para cuando el servicio finaliza → Reseña → Home
      provider.onServiceFinished = () async {
        debugPrint('[TrackingScreen] onServiceFinished called');
        if (mounted) {
          final sucursalId = provider.asignacion?.sucursal?['id'];
          if (sucursalId != null) {
            await ReviewModal.show(context, sucursalId);
          }

          provider.reset();

          if (mounted) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        }
      };

      // Callback para cuando el admin establece el monto → Pantalla de pago
      provider.onPaymentRequired = (Map<String, dynamic> pagoData) async {
        debugPrint('[TrackingScreen] onPaymentRequired: $pagoData');
        if (mounted) {
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

          if (result == true && mounted) {
            final sucursalId = provider.asignacion?.sucursal?['id'];
            if (sucursalId != null) {
              await ReviewModal.show(context, sucursalId);
            }
            provider.reset();
            if (mounted) {
              Navigator.popUntil(context, (route) => route.isFirst);
            }
          }
        }
      };
    });
  }

  @override
  void dispose() {
    // Remover listener de forma segura
    final provider = context.read<EmergenciaProvider>();
    provider.removeListener(_onProviderChange);
    
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
    // Leemos una sola vez los datos estáticos de la asignación para no recargar toda la pantalla
    final emProvider = context.read<EmergenciaProvider>();
    final asignacion = emProvider.asignacion;

    // Extraer datos si están disponibles
    final sucursal = asignacion?.sucursal;
    final tallerNombre = sucursal?['taller_nombre'] ?? 'Taller Asignado';
    final sucursalNombre = sucursal?['nombre'] ?? '';
    final telefono = sucursal?['telefono'] ?? '';

    final tecnico = asignacion?.tecnicoAsignado;
    final bool esAdmin = tecnico?['es_admin'] == true;
    final mecanicoNombre = tecnico != null
        ? '${tecnico['nombre']}${tecnico['apellidos']?.isNotEmpty == true ? ' ${tecnico['apellidos']}' : ''}'
        : 'Ayuda en camino';
    final mecanicoRol = esAdmin
        ? 'Administrador del taller'
        : 'Técnico asignado';

    // El ETA y la ubicación del mecánico se actualizarán localmente con Consumers/Selectors

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: AppTheme.glassCircle(),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.textPrimary,
              size: 20,
            ),
          ),
          onPressed: () {
            // Confirmación antes de salir
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text('¿Volver al inicio?'),
                content: const Text('La asistencia seguirá en curso.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      emProvider.reset();
                      Navigator.pop(context);
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
          // Mapa de fondo estático (sus marcadores internos escuchan los cambios)
          Positioned.fill(
            child: EmergenciaMapWidget(
              userLocation: context.read<InicioProvider>().userLocation,
            ),
          ),

          // Tarjeta inferior (estilo Uber)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _animController,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header: Icono + Ayuda en Camino + ETA
                      Selector<EmergenciaProvider, EmergenciaFlowState>(
                        selector: (_, p) => p.flowState,
                        builder: (context, flowState, child) {
                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: flowState == EmergenciaFlowState.arrived
                                      ? Colors.orange.withValues(alpha: 0.1)
                                      : AppTheme.success.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  flowState == EmergenciaFlowState.arrived
                                      ? Icons.build_circle_rounded
                                      : Icons.check_circle_rounded,
                                  color: flowState == EmergenciaFlowState.arrived
                                      ? Colors.orange
                                      : AppTheme.success,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      flowState == EmergenciaFlowState.arrived
                                          ? 'Técnico trabajando'
                                          : '¡Ayuda en Camino!',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (flowState == EmergenciaFlowState.arrived)
                                      const Text(
                                        'Revisando tu vehículo...',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else
                                      Selector<EmergenciaProvider, String>(
                                        selector: (_, p) => p.etaText,
                                        builder: (context, etaValue, child) {
                                          final finalEta = etaValue != '--'
                                              ? etaValue
                                              : '${asignacion?.tiempoEstimado?.toStringAsFixed(0) ?? '--'} min';
                                          return Text(
                                            'Llegada aprox: $finalEta',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: AppTheme.primaryColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Info del Mecánico/Taller
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: esAdmin
                                  ? AppTheme.warning.withValues(alpha: 0.1)
                                  : AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                              child: Icon(
                                esAdmin
                                    ? Icons.admin_panel_settings_rounded
                                    : Icons.engineering_rounded,
                                color: esAdmin
                                    ? AppTheme.warning
                                    : AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mecanicoNombre,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mecanicoRol,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: esAdmin
                                          ? AppTheme.warning
                                          : AppTheme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$tallerNombre - $sucursalNombre',
                                    style: const TextStyle(
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
                      const SizedBox(height: 24),

                      // Botones de acción
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: telefono.isNotEmpty
                                  ? () => _makePhoneCall(telefono)
                                  : null,
                              icon: const Icon(Icons.phone_rounded, size: 20),
                              label: const Text('Llamar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
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
