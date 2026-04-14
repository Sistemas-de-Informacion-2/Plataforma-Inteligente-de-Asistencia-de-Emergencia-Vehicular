import 'dart:io';
import 'package:flutter/material.dart';
import 'package:app_cliente/core/theme/app_theme.dart';

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
      height: 76,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 8),
        children: [
          if (audio != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(isPlayingAudio ? Icons.stop : Icons.play_arrow, size: 20, color: AppTheme.primaryColor),
                      onPressed: onToggleAudio,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Audio adjunto',
                      style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: AppTheme.danger),
                      onPressed: onRemoveAudio,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ...List.generate(imagenes.length, (i) {
            return ImageThumb(
              file: imagenes[i],
              onRemove: () => onRemoveImage(i),
            );
          }),
        ],
      ),
    );
  }
}

class ImageThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  const ImageThumb({super.key, required this.file, required this.onRemove});

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
