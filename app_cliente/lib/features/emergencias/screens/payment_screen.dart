import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fixo/core/network/api_client.dart';
import 'package:fixo/core/config/environment.dart';
import 'package:fixo/core/theme/app_theme.dart';
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
    setState(() => _isLoading = true);
    try {
      // Nota: Este endpoint requiere rol ADMIN. En un flujo real,
      // el admin confirmaría desde su panel. Aquí mostramos el mensaje.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El mecánico/admin confirmará el cobro en efectivo.'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Descarga la imagen QR y la guarda en la galería del dispositivo
  Future<void> _descargarQR(String qrUrl) async {
    try {
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
            content: Text('✅ QR guardado en la galería'),
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
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.instance.get('/pagos/${widget.pagoId}/qr');
      final qrUrl = response.data['qr_url'] as String?;

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Escanea el QR para pagar', textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (qrUrl != null) ...[
                  Image.network(
                    _buildFullUrl(qrUrl),
                    width: 250,
                    height: 250,
                    fit: BoxFit.contain,
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('No se pudo cargar la imagen',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Descargar QR'),
                    onPressed: () => _descargarQR(qrUrl),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('El taller no ha subido un QR personalizado.', textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Monto: Bs. ${widget.montoTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Envía el comprobante al taller para confirmar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(), // Cancelar
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Confirmar QR
                  try {
                    await _apiClient.instance.post('/pagos/${widget.pagoId}/confirmar-qr');
                    if (mounted) {
                      Navigator.of(context).pop(); // cierra dialog
                      Navigator.of(context).pop(true); // cierra payment screen con true
                    }
                  } catch (e) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Error al confirmar.'), backgroundColor: AppTheme.danger),
                     );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                child: const Text('Listo', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando QR: ${e.message}'), backgroundColor: AppTheme.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Método de Pago'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ── Resumen del Pago ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.primaryColor),
                  const SizedBox(height: 16),
                  const Text(
                    'Resumen del Servicio',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  _buildPriceRow('Servicio', widget.montoTaller),
                  const Divider(height: 24),
                  _buildPriceRow('Comisión plataforma (10%)', widget.comision),
                  const Divider(height: 24),
                  _buildPriceRow(
                    'TOTAL',
                    widget.montoTotal,
                    isBold: true,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Título ──
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selecciona un método de pago',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ),
            const SizedBox(height: 16),

            // ── Tarjeta ──
            _buildPaymentOption(
              icon: Icons.credit_card_rounded,
              title: 'Tarjeta de Crédito/Débito',
              subtitle: 'Pago seguro con Stripe',
              color: const Color(0xFF635BFF),
              method: 'TARJETA',
              onTap: _pagarConTarjeta,
            ),

            const SizedBox(height: 12),

            // ── QR ──
            _buildPaymentOption(
              icon: Icons.qr_code_2_rounded,
              title: 'Transferencia QR',
              subtitle: 'Escanea el código y transfiere',
              color: const Color(0xFF00A86B),
              method: 'QR',
              onTap: _mostrarQR,
            ),

            const SizedBox(height: 12),

            // ── Efectivo ──
            _buildPaymentOption(
              icon: Icons.payments_rounded,
              title: 'Efectivo',
              subtitle: 'Paga directamente al mecánico',
              color: const Color(0xFFFF9800),
              method: 'EFECTIVO',
              onTap: _confirmarEfectivo,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? AppTheme.textSecondary,
          ),
        ),
        Text(
          'Bs. ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isBold ? 20 : 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
            if (_isLoading && isSelected)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
