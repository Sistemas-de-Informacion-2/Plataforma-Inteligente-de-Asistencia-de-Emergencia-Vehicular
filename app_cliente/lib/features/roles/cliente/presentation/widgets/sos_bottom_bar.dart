import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../providers/emergencia_provider.dart';
import '../providers/inicio_provider.dart';
import 'attachments_row.dart';

class SosBottomBar extends StatelessWidget {
  final InicioProvider inicioProvider;
  final EmergenciaProvider emergenciaProvider;
  final VoidCallback onSendSOS;
  final ValueChanged<InicioProvider> onRecord;
  final ValueChanged<InicioProvider> onShowAttachments;

  const SosBottomBar({
    super.key,
    required this.inicioProvider,
    required this.emergenciaProvider,
    required this.onSendSOS,
    required this.onRecord,
    required this.onShowAttachments,
  });

  @override
  Widget build(BuildContext context) {
    final hasAttachments =
        inicioProvider.imagenesSeleccionadas.isNotEmpty ||
        inicioProvider.recordedAudio != null;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Contenedor principal unificado (Adjuntos + Texto + Botones)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7), // Fondo unificado
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Fila de adjuntos (ahora dentro del contenedor gris)
                      if (hasAttachments)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: AttachmentsRow(
                            imagenes: inicioProvider.imagenesSeleccionadas,
                            audio: inicioProvider.recordedAudio,
                            onRemoveImage: inicioProvider.removeImage,
                            onRemoveAudio: inicioProvider.removeAudio,
                            isPlayingAudio: inicioProvider.isPlayingAudio,
                            onToggleAudio: inicioProvider.toggleAudioPlayback,
                          ),
                        ),

                      // Area de texto o indicador de grabacion
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: inicioProvider.isRecording
                            ? _RecordingIndicator()
                            : _DescriptionField(inicioProvider: inicioProvider),
                      ),

                      // Fila de botones de accion (Mas grandes para dedos gruesos)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Boton de adjuntar
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                              ),
                              color: AppTheme.textSecondary,
                              iconSize: 32, // Mas grande
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ), // Area tactil amplia
                              padding: EdgeInsets.zero,
                              onPressed: () =>
                                  onShowAttachments(inicioProvider),
                            ),

                            // Botones Mic y Enviar
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    inicioProvider.isRecording
                                        ? Icons.stop_circle_rounded
                                        : Icons.mic_none_rounded,
                                  ),
                                  color: inicioProvider.isRecording
                                      ? AppTheme.danger
                                      : AppTheme.textSecondary,
                                  iconSize: 32, // Mas grande
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ), // Area tactil amplia
                                  padding: EdgeInsets.zero,
                                  onPressed: () => onRecord(inicioProvider),
                                ),
                                const SizedBox(width: 8),
                                _SendButton(
                                  isActive: inicioProvider.hasContent,
                                  onTap: inicioProvider.hasContent
                                      ? onSendSOS
                                      : () {},
                                ),
                              ],
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
        ),
      ),
    );
  }
}

class _DescriptionField extends StatelessWidget {
  final InicioProvider inicioProvider;
  const _DescriptionField({required this.inicioProvider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: TextField(
        controller: inicioProvider.descripcionController,
        minLines: 1,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Describe tu emergencia...',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        ),
      ),
    );
  }
}

class _RecordingIndicator extends StatefulWidget {
  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56, // Un poco mas alto
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          FadeTransition(
            opacity: _controller,
            child: Container(
              width: 12,
              height: 12, // Punto mas grande
              decoration: const BoxDecoration(
                color: AppTheme.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'Grabando nota de voz...',
            style: TextStyle(
              color: AppTheme.danger,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _SendButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48, // Area tactil mas grande
        height: 48,
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : Colors.grey.shade300,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.arrow_upward_rounded,
          color: Colors.white,
          size: 26, // Icono mas grande
        ),
      ),
    );
  }
}
