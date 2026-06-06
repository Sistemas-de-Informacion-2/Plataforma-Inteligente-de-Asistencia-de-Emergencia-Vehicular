import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:dio/dio.dart';

/// Widget para calificar el servicio después del pago.
/// Muestra animación Lottie de estrellas + campo de reseña.
class ReviewModal extends StatefulWidget {
  final int sucursalId;
  
  const ReviewModal({super.key, required this.sucursalId});

  static Future<void> show(BuildContext context, int sucursalId) {
    debugPrint('[ReviewModal] Attempting to show modal for sucursalId: $sucursalId');
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ReviewModal(sucursalId: sucursalId),
      ),
    );
  }

  @override
  State<ReviewModal> createState() => _ReviewModalState();
}

class _ReviewModalState extends State<ReviewModal> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitReview() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    try {
      final apiClient = ApiClient();
      await apiClient.instance.post(
        '/sucursales/${widget.sucursalId}/resenas',
        data: {
          'puntuacion': _rating,
          'comentario': _commentController.text,
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('¡Gracias por tu reseña!', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar reseña: ${e.message}'),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Animación Lottie de estrella
          SizedBox(
            height: 100,
            child: Lottie.asset(
              'assets/animaciones/star-resena.json',
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
          const SizedBox(height: 8),

          const Text(
            '¡Servicio Completado!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            '¿Cómo calificarías la atención del taller?',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final isSelected = index < _rating;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _rating = index + 1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isSelected ? AppTheme.warning : Colors.grey.shade300,
                    size: 44,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Comment field
          TextField(
            controller: _commentController,
            maxLines: 3,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Opcional: Deja un comentario sobre el servicio...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: AppTheme.muted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Ignorar', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Enviar Reseña', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
