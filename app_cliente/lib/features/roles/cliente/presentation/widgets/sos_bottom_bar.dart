import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import '../providers/emergencia_provider.dart';
import '../providers/inicio_provider.dart';
import 'attachments_row.dart';

// Widget que representa la barra inferior de la pantalla SOS.
// Contiene campo de descripción, adjuntos, grabación y envío.
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
    final hasAttachments = inicioProvider.imagenesSeleccionadas.isNotEmpty ||
        inicioProvider.recordedAudio != null;

    return Align(
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle drag indicator
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Contenedor de entrada unificado
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Adjuntos (visible solo cuando existen)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: hasAttachments
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                                child: AttachmentsRow(
                                  imagenes: inicioProvider.imagenesSeleccionadas,
                                  audio: inicioProvider.recordedAudio,
                                  onRemoveImage: inicioProvider.removeImage,
                                  onRemoveAudio: inicioProvider.removeAudio,
                                  isPlayingAudio: inicioProvider.isPlayingAudio,
                                  onToggleAudio: inicioProvider.toggleAudioPlayback,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Campo de texto / indicador de grabación
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) {
                          return FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.15),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          );
                        },
                        child: inicioProvider.isRecording
                            ? const _RecordingIndicator()
                            : _DescriptionField(inicioProvider: inicioProvider),
                      ),

                      // Fila de botones de acción
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Adjuntar
                            _BarIconButton(
                              icon: Icons.add_circle_outline_rounded,
                              onTap: () => onShowAttachments(inicioProvider),
                              tooltip: 'Adjuntar archivo',
                            ),

                            const Spacer(),

                            // Micrófono
                            _MicButton(
                              isRecording: inicioProvider.isRecording,
                              onTap: () => onRecord(inicioProvider),
                            ),

                            const SizedBox(width: 8),

                            // Enviar
                            _SendButton(
                              isActive: inicioProvider.hasContent,
                              onTap: inicioProvider.hasContent ? onSendSOS : null,
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

// Sub-widgets internos

class _DescriptionField extends StatelessWidget {
  final InicioProvider inicioProvider;
  const _DescriptionField({required this.inicioProvider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: TextField(
        controller: inicioProvider.descripcionController,
        minLines: 1,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppTheme.textPrimary,
          height: 1.4,
        ),
        decoration: InputDecoration(
          hintText: 'Describe tu emergencia...',
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        ),
      ),
    );
  }
}

class _RecordingIndicator extends StatefulWidget {
  const _RecordingIndicator();

  @override
  State<_RecordingIndicator> createState() => _RecordingIndicatorState();
}

class _RecordingIndicatorState extends State<_RecordingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          FadeTransition(
            opacity: _blinkCtrl,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTheme.danger,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.danger.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Grabando nota de voz...',
            style: TextStyle(
              color: AppTheme.danger,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de icono compacto para la barra inferior (adjuntar, etc.)
class _BarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _BarIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 28,
          color: AppTheme.textSecondary,
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

/// Botón de micrófono con animación de color entre estados
class _MicButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onTap;

  const _MicButton({required this.isRecording, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isRecording
              ? AppTheme.danger.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
          size: 28,
          color: isRecording ? AppTheme.danger : AppTheme.textSecondary,
        ),
      ),
    );
  }
}

/// Botón de envío con transición de color activo/inactivo y scale press
class _SendButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback? onTap;

  const _SendButton({required this.isActive, this.onTap});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isActive
          ? (_) {
              _pressCtrl.forward();
              HapticFeedback.mediumImpact();
            }
          : null,
      onTapUp: widget.isActive
          ? (_) {
              _pressCtrl.reverse();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: widget.isActive ? () => _pressCtrl.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.isActive ? AppTheme.primaryColor : Colors.grey.shade200,
            shape: BoxShape.circle,
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Icon(
            Icons.arrow_upward_rounded,
            color: widget.isActive ? Colors.white : Colors.grey.shade400,
            size: 22,
          ),
        ),
      ),
    );
  }
}
