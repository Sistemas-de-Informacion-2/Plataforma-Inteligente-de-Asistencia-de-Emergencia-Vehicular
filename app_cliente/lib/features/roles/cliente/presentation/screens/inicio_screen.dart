import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/theme/app_theme.dart';
import '../providers/vehiculo_provider.dart';
import '../providers/emergencia_provider.dart';
import '../providers/inicio_provider.dart';
import 'tracking_screen.dart';
import 'radar_espera_screen.dart';

import '../widgets/emergencia_map_widget.dart';
import '../widgets/map_circle_button.dart';
import '../widgets/vehicle_pill_selector.dart';
import '../widgets/attach_option_tile.dart';
import '../widgets/sos_bottom_bar.dart';

class InicioScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const InicioScreen({super.key, this.onOpenDrawer});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> with SingleTickerProviderStateMixin {
  EmergenciaProvider? _emProvider;
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    // Animación de entrada fluida para la UI
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _emProvider = context.read<EmergenciaProvider>();
        _emProvider?.addListener(_onEmergenciaStateChanged);
        
        // Al montar el mapa, verificamos si dejamos una solicitud "en el aire"
        _emProvider?.verificarSolicitudActiva();
      }
    });
  }

  @override
  void dispose() {
    _emProvider?.removeListener(_onEmergenciaStateChanged);
    _entranceController.dispose();
    super.dispose();
  }

  void _onEmergenciaStateChanged() {
    if (!mounted || _emProvider == null) return;

    final flowState = _emProvider!.flowState;
    if (flowState == EmergenciaFlowState.waitingForBids) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ModalRoute.of(context)?.settings.name != '/radar') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const RadarEsperaScreen(),
              settings: const RouteSettings(name: '/radar'),
            ),
          );
        }
      });
    } else if (flowState == EmergenciaFlowState.accepted || flowState == EmergenciaFlowState.serviceInProgress) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ModalRoute.of(context)?.settings.name != '/tracking') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TrackingScreen(),
              settings: const RouteSettings(name: '/tracking'),
            ),
          );
        }
      });
    } else if (flowState == EmergenciaFlowState.rejected ||
        flowState == EmergenciaFlowState.timeout) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_emProvider!.errorMessage),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  // ── Attachment Options ─────────────────────────────────────
  void _showAttachmentOptions(InicioProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AttachOptionTile(
                icon: Icons.camera_alt_rounded,
                label: 'Cámara',
                color: colorScheme.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  provider.pickFromCamera();
                },
              ),
              const SizedBox(height: 8),
              AttachOptionTile(
                icon: Icons.photo_library_rounded,
                label: 'Galería',
                color: colorScheme.secondary,
                onTap: () {
                  Navigator.pop(ctx);
                  provider.pickImages();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Audio Recording ────────────────────────────────────────
  Future<void> _handleGrabacion(InicioProvider provider) async {
    if (provider.isRecording) {
      await provider.detenerGrabacion();
    } else {
      final error = await provider.iniciarGrabacion();
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppTheme.warning),
        );
      }
    }
  }

  // ── Send SOS ───────────────────────────────────────────────
  Future<void> _enviarSOS() async {
    final formProvider = context.read<InicioProvider>();
    final emProvider = context.read<EmergenciaProvider>();

    await formProvider.validarAudioExistente();
    if (!formProvider.hasContent) return;
    if (!mounted) return;

    await formProvider.determinePosition();
    if (formProvider.userLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación. Habilite el GPS.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
      return;
    }

    final result = await emProvider.enviarEmergencia(
      vehiculoId: formProvider.vehiculoSeleccionado?.id,
      latitud: formProvider.userLocation!.latitude,
      longitud: formProvider.userLocation!.longitude,
      descripcion: formProvider.descripcionController.text.trim(),
      imagenes: formProvider.imagenesSeleccionadas,
      audio: formProvider.recordedAudio,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (emProvider.advertirArchivosBorrados) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Algunos archivos fueron eliminados y no se enviaron.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }

    if (result != null) {
      emProvider.connectWebSocket();
      formProvider.limpiarFormulario();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RadarEsperaScreen()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            emProvider.errorMessage.isNotEmpty
                ? emProvider.errorMessage
                : 'Falló el envío de la emergencia.',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  // Build 
  @override
  Widget build(BuildContext context) {
    final vehiculoProvider = context.watch<VehiculoProvider>();
    final emergenciaProvider = context.watch<EmergenciaProvider>();
    final inicioProvider = context.watch<InicioProvider>();
    final mq = MediaQuery.of(context);

    // Auto-select first vehicle
    if (inicioProvider.vehiculoSeleccionado == null &&
        vehiculoProvider.vehiculos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && inicioProvider.vehiculoSeleccionado == null) {
          inicioProvider.setVehiculo(vehiculoProvider.vehiculos.first);
        }
      });
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── 1. MAPA INMERSIVO ──────────────────────────────
          Positioned.fill(
            child: EmergenciaMapWidget(
              userLocation: inicioProvider.userLocation,
            ),
          ),

          // ── 2. GRADIENT OVERLAYS (Mejor legibilidad y estética) ──────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mq.padding.top + 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── 3. HEADER FLOTANTE ANIMADO ────────────────────────────
          Positioned(
            top: mq.padding.top + 12,
            left: 16,
            right: 16,
            child: AnimatedBuilder(
              animation: _entranceController,
              builder: (context, child) {
                final val = Curves.easeOutBack.transform(_entranceController.value);
                return Transform.translate(
                  offset: Offset(0, -50 * (1 - val)),
                  child: Opacity(
                    opacity: val.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Row(
                children: [
                  MapCircleButton(
                    icon: Icons.menu_rounded,
                    onTap: widget.onOpenDrawer ?? () {},
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: VehiclePillSelector(
                        vehiculos: vehiculoProvider.vehiculos,
                        selected: inicioProvider.vehiculoSeleccionado,
                        onChanged: inicioProvider.setVehiculo,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  MapCircleButton(
                    icon: Icons.my_location_rounded,
                    onTap: inicioProvider.determinePosition,
                  ),
                ],
              ),
            ),
          ),

          // ── 4. BARRA SOS INFERIOR ANIMADA ─────────────────────────
          AnimatedBuilder(
            animation: _entranceController,
            builder: (context, child) {
              final val = Curves.easeOutCubic.transform(_entranceController.value);
              return Transform.translate(
                offset: Offset(0, 100 * (1 - val)),
                child: Opacity(
                  opacity: val.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: SosBottomBar(
              inicioProvider: inicioProvider,
              emergenciaProvider: emergenciaProvider,
              onSendSOS: _enviarSOS,
              onRecord: _handleGrabacion,
              onShowAttachments: _showAttachmentOptions,
            ),
          ),

          // ── 5. LOADING OVERLAY (Lottie + Glassmorphism) ───────────
          if (emergenciaProvider.isUploading)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: child,
                  );
                },
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: AppTheme.primaryColor.withValues(alpha: 0.85), // Fondo premium
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Lottie Animation
                            Lottie.asset(
                              'assets/animaciones/tuerca-cargando.json',
                              width: 160,
                              height: 160,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 24),
                            // Texto Animado Pulsante
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.6, end: 1.0),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeInOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Opacity(
                                    opacity: value,
                                    child: child,
                                  ),
                                );
                              },
                              onEnd: () {
                                // Para hacer un efecto de pulsación continua tendríamos que usar un controller,
                                // pero el Tween estático le da un toque suave al aparecer.
                              },
                              child: const Text(
                                'ENVIANDO SEÑAL SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Analizando situación con IA...',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
