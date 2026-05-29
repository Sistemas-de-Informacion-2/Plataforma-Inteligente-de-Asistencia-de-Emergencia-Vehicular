import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/theme/app_theme.dart';
import '../providers/vehiculo_provider.dart';
import '../providers/emergencia_provider.dart';
import '../providers/inicio_provider.dart';
//import '../../../../auth/presentation/providers/auth_provider.dart';
import 'tracking_screen.dart';
import 'radar_espera_screen.dart';

import '../widgets/emergencia_map_widget.dart';
import '../widgets/map_circle_button.dart';
import '../widgets/vehicle_pill_selector.dart';
import '../widgets/attach_option_tile.dart';
import '../widgets/sos_bottom_bar.dart';

class InicioScreen extends StatefulWidget {
  /// Callback que abre el Drawer del [HomeScreen] padre.
  final VoidCallback? onOpenDrawer;
  const InicioScreen({super.key, this.onOpenDrawer});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  EmergenciaProvider? _emProvider;

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _onEmergenciaStateChanged() {
    if (!mounted || _emProvider == null) return;

    final flowState = _emProvider!.flowState;
    if (flowState == EmergenciaFlowState.waitingForBids) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Evitar doble navegación
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
      // Cierra el BottomSheet si está abierto
      if (Navigator.canPop(context)) Navigator.pop(context);
      // Navega al TrackingScreen
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
    // final authProvider = context.read<AuthProvider>();

    await formProvider.validarAudioExistente();
    if (!formProvider.hasContent) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Obteniendo ubicación y enviando SOS...'),
        backgroundColor: AppTheme.primaryColor,
        duration: Duration(seconds: 2),
      ),
    );

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
      // Navegar a la pantalla de Radar para esperar las pujas en tiempo real
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

          // ── 2. GRADIENT OVERLAYS (For readability) ──────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: mq.padding.top + 80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── 3. LOADING OVERLAY ─────────────────────────────
          if (emergenciaProvider.isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          color: AppTheme.danger,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'ENVIANDO SEÑAL SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Analizando situación con IA...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── 4. HEADER FLOTANTE ────────────────────────────
          Positioned(
            top: mq.padding.top + 12,
            left: 16,
            right: 16,
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
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
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

          // ── 5. BARRA SOS INFERIOR ─────────────────────────
          SosBottomBar(
            inicioProvider: inicioProvider,
            emergenciaProvider: emergenciaProvider,
            onSendSOS: _enviarSOS,
            onRecord: _handleGrabacion,
            onShowAttachments: _showAttachmentOptions,
          ),
        ],
      ),
    );
  }
}
