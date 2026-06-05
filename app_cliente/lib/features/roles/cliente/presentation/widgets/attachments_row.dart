import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';

// Widget que muestra los archivos adjuntos (imágenes y audio) de manera
// estilizada con scroll horizontal y animaciones de entrada escalonadas.
class AttachmentsRow extends StatelessWidget {
  final List<File> imagenes;
  final File? audio;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onRemoveAudio;
  final bool isPlayingAudio;
  final VoidCallback onToggleAudio;

  const AttachmentsRow({
    super.key,
    required this.imagenes,
    required this.audio,
    required this.onRemoveImage,
    required this.onRemoveAudio,
    required this.isPlayingAudio,
    required this.onToggleAudio,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        children: [
          // Cápsula de Audio
          if (audio != null)
            _AudioChip(
              isPlaying: isPlayingAudio,
              onToggle: onToggleAudio,
              onRemove: onRemoveAudio,
            ),

          // Miniaturas de imágenes con animación escalonada
          ...List.generate(imagenes.length, (i) {
            return _ImageThumb(
              key: ValueKey(imagenes[i].path),
              file: imagenes[i],
              index: i,
              onRemove: () => onRemoveImage(i),
            );
          }),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _AudioChip
// Cápsula de audio con indicador animado de ondas cuando está en reproducción.
// ──────────────────────────────────────────────────────────────────────────────
class _AudioChip extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  const _AudioChip({
    required this.isPlaying,
    required this.onToggle,
    required this.onRemove,
  });

  @override
  State<_AudioChip> createState() => _AudioChipState();
}

class _AudioChipState extends State<_AudioChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  late final Animation<double> _waveAnim;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _waveAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _waveCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_AudioChip old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying) {
      _waveCtrl.repeat(reverse: true);
    } else {
      _waveCtrl.stop();
      _waveCtrl.reset();
    }
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10, top: 6, bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.12),
              AppTheme.primaryColor.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón play/stop
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onToggle();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: widget.isPlaying ? AppTheme.danger : AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isPlaying ? AppTheme.danger : AppTheme.primaryColor)
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  widget.isPlaying
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Texto + indicador de onda
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nota de voz',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedBuilder(
                  animation: _waveAnim,
                  builder: (context, _) {
                    return _WaveBars(playing: widget.isPlaying, phase: _waveAnim.value);
                  },
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Botón eliminar
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onRemove();
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: AppTheme.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Barras de onda animadas simples (5 barras con alturas variables)
class _WaveBars extends StatelessWidget {
  final bool playing;
  final double phase;

  const _WaveBars({required this.playing, required this.phase});

  @override
  Widget build(BuildContext context) {
    const heights = [6.0, 10.0, 7.0, 12.0, 6.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(heights.length, (i) {
        final h = playing
            ? heights[i] * (i.isEven ? phase : (1.6 - phase).clamp(0.4, 1.0))
            : 4.0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 3,
            height: h,
            decoration: BoxDecoration(
              color: playing
                  ? AppTheme.primaryColor.withValues(alpha: 0.7)
                  : AppTheme.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

/* _ImageThumb
 Miniatura de imagen con animación elasticOut de entrada y visor de pantalla
 completa con InteractiveViewer. */
 
class _ImageThumb extends StatefulWidget {
  final File file;
  final int index;
  final VoidCallback onRemove;

  const _ImageThumb({
    super.key,
    required this.file,
    required this.index,
    required this.onRemove,
  });

  @override
  State<_ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<_ImageThumb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // Stagger: cada imagen entra 80ms después de la anterior
    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showFullScreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (ctx, anim, _) {
          return FadeTransition(
            opacity: anim,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: SafeArea(
                  child: Stack(
                    children: [
                      Center(
                        child: Hero(
                          tag: widget.file.path,
                          child: InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.8,
                            maxScale: 5,
                            child: Image.file(widget.file, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 12,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: ScaleTransition(scale: _scaleAnim, child: child),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () => _showFullScreen(context),
            child: Hero(
              tag: widget.file.path,
              child: Container(
                margin: const EdgeInsets.only(right: 10, top: 6, bottom: 6),
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    widget.file,
                    fit: BoxFit.cover,
                    cacheWidth: 132, // evita decodificar a full res
                  ),
                ),
              ),
            ),
          ),

          // Botón eliminar con haptic
          Positioned(
            right: 2,
            top: 0,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onRemove();
              },
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppTheme.danger,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
