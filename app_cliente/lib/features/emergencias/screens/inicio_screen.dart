import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_cliente/core/theme/app_theme.dart';
import 'package:app_cliente/features/vehiculos/providers/vehiculo_provider.dart';
import 'package:app_cliente/features/emergencias/providers/emergencia_provider.dart';
import 'package:app_cliente/features/emergencias/providers/inicio_provider.dart';

import 'package:app_cliente/features/emergencias/widgets/emergencia_map_widget.dart';
import 'package:app_cliente/features/emergencias/widgets/map_circle_button.dart';
import 'package:app_cliente/features/emergencias/widgets/vehicle_pill_selector.dart';
import 'package:app_cliente/features/emergencias/widgets/sos_action_button.dart';
import 'package:app_cliente/features/emergencias/widgets/attachments_row.dart';
import 'package:app_cliente/features/emergencias/widgets/attach_option_tile.dart';
import 'package:app_cliente/features/emergencias/models/incidente_response_model.dart';

class InicioScreen extends StatefulWidget {
  /// Callback que abre el Drawer del [HomeScreen] padre.
  final VoidCallback? onOpenDrawer;
  const InicioScreen({super.key, this.onOpenDrawer});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> with SingleTickerProviderStateMixin {
  late AnimationController _sendBtnController;
  late Animation<double> _sendBtnScale;

  @override
  void initState() {
    super.initState();
    _sendBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _sendBtnScale = CurvedAnimation(
      parent: _sendBtnController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _sendBtnController.dispose();
    super.dispose();
  }

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

  Future<void> _enviarSOS(InicioProvider formProvider, EmergenciaProvider emProvider) async {
    await formProvider.validarAudioExistente();
    if (!formProvider.hasContent) return;

    // Paso A: Activa mensaje
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Obteniendo ubicación y enviando SOS...'),
        backgroundColor: AppTheme.primaryColor,
        duration: Duration(seconds: 2),
      ),
    );

    // Paso B: Lat y Lng real
    await formProvider.determinePosition();
    if (formProvider.userLocation == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la ubicación exacta. Por favor, habilite el GPS.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
      return;
    }

    // Paso C: Enviar Emergencia
    final result = await emProvider.enviarEmergencia(
      vehiculoId: formProvider.vehiculoSeleccionado?.id,
      latitud: formProvider.userLocation!.latitude,
      longitud: formProvider.userLocation!.longitude,
      descripcion: formProvider.descripcionController.text.trim(),
      imagenes: formProvider.imagenesSeleccionadas,
      audio: formProvider.recordedAudio,
    );

    if (mounted) {
      // Paso D: Mostrar resultado y limpiar
      if (result != null) {
        final estado = result.solicitud?.estado ?? '';

        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (emProvider.advertirArchivosBorrados) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Algunos archivos temporales fueron eliminados por el sistema y no se enviaron.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }

        if (estado == 'RECHAZADO_POR_IA' || estado == 'REQUIERE_VALIDACION') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La Inteligencia Artificial no pudo diagnosticar el problema con exactitud. Mostrando mecánicos cercanos por defecto.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          _showFallbackTalleresPanel();
        } else {
          _showAiSummaryPanel(result);
        }
        formProvider.limpiarFormulario();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(emProvider.errorMessage.isNotEmpty ? emProvider.errorMessage : 'Falló el envío de la emergencia.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _showAiSummaryPanel(IncidenteResponseModel result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Icon(Icons.check_circle_rounded, size: 64, color: AppTheme.success),
              const SizedBox(height: 16),
              const Text(
                '¡Emergencia Reportada!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              if (result.diagnostico != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.smart_toy_rounded, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Dictamen IA: ${result.diagnostico!.nivelGravedad}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.diagnostico!.problemaDetectado ?? 'Sin resumen detallado.',
                        style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (result.asignacionResultado != null && result.asignacionResultado!.sucursal != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.engineering_rounded, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Manejando tu incidencia: ${result.asignacionResultado!.sucursal!["nombre"]}.',
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFallbackTalleresPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Icon(Icons.build_circle_rounded, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Buscando Talleres Cercanos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Como la IA no pudo diagnosticar el problema con exactitud, estamos obteniendo una lista de los talleres más cercanos para que elijas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C2C2E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehiculoProvider = context.watch<VehiculoProvider>();
    final emergenciaProvider = context.watch<EmergenciaProvider>();
    final inicioProvider = context.watch<InicioProvider>();
    final mq = MediaQuery.of(context);

    // Auto-select first vehicle
    if (inicioProvider.vehiculoSeleccionado == null && vehiculoProvider.vehiculos.isNotEmpty) {
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
            child: EmergenciaMapWidget(userLocation: inicioProvider.userLocation),
          ),

          // ── 2. LOADING OVERLAY ─────────────────────────────
          if (emergenciaProvider.isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.55),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.danger, strokeWidth: 3),
                      SizedBox(height: 20),
                      Text(
                        'Evacuando señal SOS…',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── 3. HEADER FLOTANTE ───────────────────────────
          Positioned(
            top: mq.padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                MapCircleButton(
                  icon: Icons.menu_rounded,
                  onTap: widget.onOpenDrawer ?? () {},
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: VehiclePillSelector(
                    vehiculos: vehiculoProvider.vehiculos,
                    selected: inicioProvider.vehiculoSeleccionado,
                    onChanged: inicioProvider.setVehiculo,
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

          // ── 4. BARRA SOS INFERIOR ─────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: AppTheme.bottomBarShadow,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (inicioProvider.imagenesSeleccionadas.isNotEmpty || inicioProvider.recordedAudio != null)
                        AttachmentsRow(
                          imagenes: inicioProvider.imagenesSeleccionadas,
                          audio: inicioProvider.recordedAudio,
                          onRemoveImage: inicioProvider.removeImage,
                          onRemoveAudio: inicioProvider.removeAudio,
                          isPlayingAudio: inicioProvider.isPlayingAudio,
                          onToggleAudio: inicioProvider.toggleAudioPlayback,
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SOSActionButton(
                            icon: Icons.add_rounded,
                            backgroundColor: const Color(0xFF2C2C2E),
                            iconColor: Colors.white,
                            onTap: () => _showAttachmentOptions(inicioProvider),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: inicioProvider.isRecording
                                ? Container(
                                    height: 46,
                                    margin: const EdgeInsets.only(bottom: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.danger.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: const BoxDecoration(
                                            color: AppTheme.danger,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Grabando audio...',
                                          style: TextStyle(
                                            color: AppTheme.danger,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2F2F7),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: TextField(
                                      controller: inicioProvider.descripcionController,
                                      minLines: 1,
                                      maxLines: 5,
                                      style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                                      decoration: InputDecoration(
                                        hintText: 'Describe tu emergencia…',
                                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 10),
                          SOSActionButton(
                            icon: inicioProvider.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            backgroundColor: inicioProvider.isRecording ? AppTheme.danger : const Color(0xFF2C2C2E),
                            iconColor: Colors.white,
                            onTap: () => _handleGrabacion(inicioProvider),
                          ),
                          const SizedBox(width: 8),
                          SOSActionButton(
                            icon: Icons.send_rounded,
                            backgroundColor: inicioProvider.hasContent ? AppTheme.danger : Colors.grey.shade400,
                            iconColor: Colors.white,
                            onTap: inicioProvider.hasContent ? () => _enviarSOS(inicioProvider, emergenciaProvider) : () {},
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