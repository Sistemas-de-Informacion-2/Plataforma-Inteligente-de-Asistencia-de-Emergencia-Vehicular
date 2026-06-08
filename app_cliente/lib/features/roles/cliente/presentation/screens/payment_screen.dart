import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/config/environment.dart';
import '../../../../../core/theme/app_theme.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

/// Pantalla de pago que se muestra después de que el admin establece el monto.
/// Recibida via WebSocket con evento PAGO_REQUERIDO.
class PaymentScreen extends StatefulWidget {
  final int pagoId;
  final double montoTotal;
  final double comision;
  final double montoTaller;

  const PaymentScreen({
    super.key,
    required this.pagoId,
    required this.montoTotal,
    required this.comision,
    required this.montoTaller,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiClient _apiClient = ApiClient();
  bool _isLoading = false;
  String? _selectedMethod; // 'TARJETA', 'EFECTIVO', 'QR'

  /// Construye la URL completa del QR a partir de la ruta relativa
  String _buildFullUrl(String rawUrl) {
    if (rawUrl.startsWith('/')) {
      return '${Environment.baseUrl.replaceAll('/api/v1', '')}$rawUrl';
    }
    return rawUrl;
  }

  Future<void> _pagarConTarjeta() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.instance.post(
        '/pagos/${widget.pagoId}/checkout',
      );
      final url = response.data['checkout_url'] as String;
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Redirigiendo a la pasarela de pago...'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.response?.data['detail'] ?? e.message}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmarEfectivo() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      await _apiClient.instance.post(
        '/pagos/${widget.pagoId}/confirmar-efectivo-cliente',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pago en efectivo confirmado. El mecánico fue notificado.',
            ),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al confirmar: ${e.response?.data['detail'] ?? e.message}',
            ),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Descarga la imagen QR y la guarda en la galería del dispositivo
  Future<void> _descargarQR(String qrUrl) async {
    try {
      HapticFeedback.lightImpact();
      final fullUrl = _buildFullUrl(qrUrl);

      // Descargar bytes con Dio
      final response = await Dio().get<List<int>>(
        fullUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      // Guardar a archivo temporal
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/qr_pago_${widget.pagoId}.png';
      final file = File(filePath);
      await file.writeAsBytes(Uint8List.fromList(response.data!));

      // Guardar en galería
      await Gal.putImage(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR guardado en la galería'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _mostrarQR() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.instance.get(
        '/pagos/${widget.pagoId}/qr',
      );
      final qrUrl = response.data['qr_url'] as String?;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Escanea el QR',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (qrUrl != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      _buildFullUrl(qrUrl),
                      width: 250,
                      height: 250,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return SizedBox(
                          width: 250,
                          height: 250,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image_rounded,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No se pudo cargar la imagen',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Guardar QR en Galería', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _descargarQR(qrUrl),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'El taller no ha subido un QR personalizado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text('Total a pagar', style: TextStyle(color: Colors.black54, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        'Bs. ${widget.montoTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Por favor, envía el comprobante al mecánico a través del chat o en persona para confirmar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(), // Cancelar
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        // Confirmar QR
                        try {
                          await _apiClient.instance.post(
                            '/pagos/${widget.pagoId}/confirmar-qr',
                          );

                          if (!mounted) return;
                          Navigator.of(context).pop(); // Cierra dialog
                          Navigator.of(context).pop(true); // cierra payment screen con true   
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error al confirmar.'),
                              backgroundColor: AppTheme.danger,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando QR: ${e.message}'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor, // Light theme like the rest of the app
      appBar: AppBar(
        title: const Text('Resumen de Pago', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Resumen del Pago ──
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 48,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Servicio Finalizado',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Elige tu método de pago preferido.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildPriceRow('Servicio de asistencia', widget.montoTaller),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                    _buildPriceRow('Tarifa de servicio (10%)', widget.comision),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),
                    _buildPriceRow(
                      'Total a pagar',
                      widget.montoTotal,
                      isBold: true,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Métodos de pago',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // ── Tarjeta ──
              _buildPaymentOption(
                icon: Icons.credit_card_rounded,
                title: 'Tarjeta de Crédito / Débito',
                subtitle: 'Pago rápido y seguro online',
                color: const Color(0xFF635BFF),
                method: 'TARJETA',
                onTap: _pagarConTarjeta,
              ),

              const SizedBox(height: 12),

              // ── QR ──
              _buildPaymentOption(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Transferencia QR',
                subtitle: 'Paga con la app de tu banco',
                color: const Color(0xFF00A86B),
                method: 'QR',
                onTap: _mostrarQR,
              ),

              const SizedBox(height: 12),

              // ── Efectivo ──
              _buildPaymentOption(
                icon: Icons.payments_rounded,
                title: 'Efectivo',
                subtitle: 'Paga directamente al llegar',
                color: const Color(0xFFFF9800),
                method: 'EFECTIVO',
                onTap: _confirmarEfectivo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 18 : 15,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isBold ? AppTheme.textPrimary : Colors.grey.shade600,
          ),
        ),
        Text(
          'Bs. ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isBold ? 24 : 16,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String method,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: _isLoading
          ? null
          : () {
              setState(() => _selectedMethod = method);
              onTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: isSelected ? Colors.white : color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (_isLoading && isSelected)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3, color: color),
              )
            else
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isSelected ? color : Colors.grey.shade300,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

