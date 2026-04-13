import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:app_cliente/core/theme/app_theme.dart';
import 'package:app_cliente/features/vehiculos/providers/vehiculo_provider.dart';
import 'package:app_cliente/features/vehiculos/models/vehiculo.dart';
import 'package:app_cliente/features/emergencias/providers/emergencia_provider.dart';
import 'package:app_cliente/features/emergencias/widgets/emergencia_map_widget.dart';

class InicioScreen extends StatefulWidget {
  /// Callback que abre el Drawer del [HomeScreen] padre.
  final VoidCallback? onOpenDrawer;

  const InicioScreen({super.key, this.onOpenDrawer});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _descripcionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<File> _imagenesSeleccionadas = [];
  Vehiculo? _vehiculoSeleccionado;
  LatLng? _userLocation;

  File? _recordedAudio;
  bool _isRecording = false;
  late final AudioRecorder _audioRecorder;

  late AnimationController _sendBtnController;
  late Animation<double> _sendBtnScale;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    
    _sendBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _sendBtnScale = CurvedAnimation(
      parent: _sendBtnController,
      curve: Curves.easeOutBack,
    );

    _descripcionController.addListener(() => setState(() {}));
    _determinePosition();
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _sendBtnController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ── Location ────────────────────────────────────────────────
  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    if (mounted) {
      setState(
          () => _userLocation = LatLng(position.latitude, position.longitude));
    }
  }

  // ── Media ────────────────────────────────────────────────────
  void _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() =>
          _imagenesSeleccionadas.addAll(images.map((x) => File(x.path))));
    }
  }

  void _pickFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() => _imagenesSeleccionadas.add(File(image.path)));
    }
  }

  void _showAttachmentOptions() {
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
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _AttachOptionTile(
                icon: Icons.camera_alt_rounded,
                label: 'Cámara',
                color: colorScheme.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),
              const SizedBox(height: 8),
              _AttachOptionTile(
                icon: Icons.photo_library_rounded,
                label: 'Galería',
                color: colorScheme.secondary,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImages();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage(int index) =>
      setState(() => _imagenesSeleccionadas.removeAt(index));

  // ── Audio Recording ──────────────────────────────────────────
  Future<void> _iniciarGrabacion() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/audio_sos_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _recordedAudio = null;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de micrófono denegado'), backgroundColor: AppTheme.warning),
          );
        }
      }
    } catch (e) {
      debugPrint("Error al grabar: \$e");
    }
  }

  Future<void> _detenerGrabacion() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        if (path != null) {
          _recordedAudio = File(path);
        }
      });
    } catch (e) {
      debugPrint("Error al detener grabación: \$e");
    }
  }

  // ── Submit ───────────────────────────────────────────────────
  Future<void> _enviarSOS() async {
    final bool hasContent = _descripcionController.text.trim().isNotEmpty ||
        _imagenesSeleccionadas.isNotEmpty || _recordedAudio != null;

    if (!hasContent) return;

    // Paso A: Activa mensaje
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Obteniendo ubicación y enviando SOS...'),
        backgroundColor: AppTheme.primaryColor,
        duration: Duration(seconds: 2),
      ),
    );

    // Paso B: Lat y Lng real
    await _determinePosition();
    if (_userLocation == null) {
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
    final provider = context.read<EmergenciaProvider>();
    final success = await provider.enviarEmergencia(
      vehiculoId: _vehiculoSeleccionado?.id,
      latitud: _userLocation!.latitude,
      longitud: _userLocation!.longitude,
      descripcion: _descripcionController.text.trim(),
      imagenes: _imagenesSeleccionadas,
      audio: _recordedAudio,
    );

    if (mounted) {
      // Paso D: Mostrar resultado y limpiar
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Emergencia reportada! Ayuda en camino.'),
            backgroundColor: AppTheme.success,
          ),
        );
        setState(() {
          _descripcionController.clear();
          _imagenesSeleccionadas.clear();
          _recordedAudio = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final vehiculoProvider = context.watch<VehiculoProvider>();
    final emergenciaProvider = context.watch<EmergenciaProvider>();
    final mq = MediaQuery.of(context);

    final bool hasContent = _descripcionController.text.trim().isNotEmpty ||
        _imagenesSeleccionadas.isNotEmpty;

    // Auto-select first vehicle
    if (_vehiculoSeleccionado == null &&
        vehiculoProvider.vehiculos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _vehiculoSeleccionado == null) {
          setState(() => _vehiculoSeleccionado = vehiculoProvider.vehiculos.first);
        }
      });
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── 1. MAPA INMERSIVO ──────────────────────────────
          Positioned.fill(
            child: EmergenciaMapWidget(userLocation: _userLocation),
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
                      CircularProgressIndicator(
                        color: AppTheme.danger,
                        strokeWidth: 3,
                      ),
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

          // ── 3. HEADER FLOTANTE (SafeArea + Row) ───────────
          Positioned(
            top: mq.padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Botón hamburguesa circular con sombra
                _MapCircleButton(
                  icon: Icons.menu_rounded,
                  onTap: widget.onOpenDrawer ?? () {},
                ),

                const SizedBox(width: 12),

                // Pill selector de vehículo centrada y flexible
                Expanded(
                  child: _VehiclePillSelector(
                    vehiculos: vehiculoProvider.vehiculos,
                    selected: _vehiculoSeleccionado,
                    onChanged: (v) => setState(() => _vehiculoSeleccionado = v),
                  ),
                ),

                const SizedBox(width: 12),

                // Botón de re-centrar ubicación
                _MapCircleButton(
                  icon: Icons.my_location_rounded,
                  onTap: _determinePosition,
                ),
              ],
            ),
          ),

          // ── 4. BARRA SOS INFERIOR (Estilo Gemini) ─────────
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: AppTheme.bottomBarShadow,
              ),
              // SafeArea maneja el padding inferior (barra del sistema)
              child: SafeArea(
                top: false,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle decorativo
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

                      // Miniaturas de adjuntos
                      if (_imagenesSeleccionadas.isNotEmpty ||
                          _recordedAudio != null)
                        _AttachmentsRow(
                          imagenes: _imagenesSeleccionadas,
                          audio: _recordedAudio,
                          onRemoveImage: _removeImage,
                          onRemoveAudio: () =>
                              setState(() => _recordedAudio = null),
                        ),

                      // Fila principal
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Botón + adjuntos
                          _SOSActionButton(
                            icon: Icons.add_rounded,
                            backgroundColor: const Color(0xFF2C2C2E),
                            iconColor: Colors.white,
                            onTap: _showAttachmentOptions,
                          ),

                          const SizedBox(width: 10),

                          // TextField limpio o Indicador de Grabación
                          Expanded(
                            child: _isRecording
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
                                      controller: _descripcionController,
                                      minLines: 1,
                                      maxLines: 5,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: AppTheme.textPrimary,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Describe tu emergencia…',
                                        hintStyle: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 15,
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 18, vertical: 12),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                          ),

                          const SizedBox(width: 10),

                          // Mic / enviar
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return ScaleTransition(scale: animation, child: child);
                            },
                            child: hasContent || _recordedAudio != null
                                ? _SOSActionButton(
                                    key: const ValueKey('send_btn'),
                                    icon: Icons.send_rounded,
                                    backgroundColor: AppTheme.danger,
                                    iconColor: Colors.white,
                                    onTap: _enviarSOS,
                                  )
                                : _SOSActionButton(
                                    key: const ValueKey('mic_btn'),
                                    icon: _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                                    backgroundColor: _isRecording ? AppTheme.danger : const Color(0xFF2C2C2E),
                                    iconColor: Colors.white,
                                    onTap: () {
                                      if (_isRecording) {
                                        _detenerGrabacion();
                                      } else {
                                        _iniciarGrabacion();
                                      }
                                    },
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

// ─────────────────────────────────────────────────────────────────────────────
// Widgets privados extraídos para mantener el build limpio
// ─────────────────────────────────────────────────────────────────────────────

/// Botón circular flotante para el mapa (hamburguesa, re-centrar, etc.)
class _MapCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: AppTheme.glassCircle(),
        child: Icon(icon, size: 22, color: AppTheme.textPrimary),
      ),
    );
  }
}

/// Pill selector de vehículo con glassmorphism
class _VehiclePillSelector extends StatelessWidget {
  final List<Vehiculo> vehiculos;
  final Vehiculo? selected;
  final ValueChanged<Vehiculo?> onChanged;

  const _VehiclePillSelector({
    required this.vehiculos,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: AppTheme.glassPill(),
      child: Row(
        children: [
          const Icon(Icons.directions_car_rounded,
              size: 18, color: AppTheme.danger),
          const SizedBox(width: 8),
          Expanded(
            child: vehiculos.isEmpty
                ? Text(
                    'Sin vehículos',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<Vehiculo>(
                      value: selected,
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(Icons.expand_more_rounded,
                          size: 18, color: AppTheme.textSecondary),
                      hint: const Text(
                        '¿Qué vehículo?',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: onChanged,
                      items: vehiculos
                          .map((v) => DropdownMenuItem(
                                value: v,
                                child: Text(
                                  '${v.marca} ${v.modelo} · ${v.placa}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Botón circular de acción dentro de la barra SOS
class _SOSActionButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _SOSActionButton({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.30),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

/// Fila horizontal de miniaturas de adjuntos (fotos + chip de audio)
class _AttachmentsRow extends StatelessWidget {
  final List<File> imagenes;
  final File? audio;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onRemoveAudio;

  const _AttachmentsRow({
    required this.imagenes,
    required this.audio,
    required this.onRemoveImage,
    required this.onRemoveAudio,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          if (audio != null)
            _AudioChip(file: audio!, onRemove: onRemoveAudio),
          ...List.generate(imagenes.length, (i) {
            return _ImageThumb(
              file: imagenes[i],
              onRemove: () => onRemoveImage(i),
            );
          }),
        ],
      ),
    );
  }
}

class _AudioChip extends StatefulWidget {
  final File file;
  final VoidCallback onRemove;
  
  const _AudioChip({required this.file, required this.onRemove});

  @override
  State<_AudioChip> createState() => _AudioChipState();
}

class _AudioChipState extends State<_AudioChip> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    // Set source to load duration
    _audioPlayer.setSource(DeviceFileSource(widget.file.path));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    // Do not show hours for short emergency audios
    return "\$minutes:\$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () async {
            if (_isPlaying) {
              await _audioPlayer.pause();
            } else {
              await _audioPlayer.play(DeviceFileSource(widget.file.path));
            }
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8, top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.25), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  _duration.inMilliseconds > 0 
                    ? "\${_formatDuration(_position)} / \${_formatDuration(_duration)}"
                    : 'Audio',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: -4,
          top: -4,
          child: GestureDetector(
            onTap: widget.onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: AppTheme.danger, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const _ImageThumb({required this.file, required this.onRemove});

  void _showFullScreenImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _showFullScreenImage(context),
          child: Container(
            margin: const EdgeInsets.only(right: 8, top: 6),
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
              boxShadow: AppTheme.cardShadow,
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                  color: AppTheme.danger, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tile de opción de adjunto en el modal
class _AttachOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
