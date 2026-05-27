import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../providers/emergencia_provider.dart';
import '../providers/inicio_provider.dart';
import '../widgets/emergencia_map_widget.dart';

import 'tracking_screen.dart';

class RadarEsperaScreen extends StatefulWidget {
  const RadarEsperaScreen({super.key});

  @override
  State<RadarEsperaScreen> createState() => _RadarEsperaScreenState();
}

class _RadarEsperaScreenState extends State<RadarEsperaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final emProvider = context.read<EmergenciaProvider>();
      emProvider.onPujaAceptadaCallback = () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TrackingScreen()),
          );
        }
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final emProvider = context.watch<EmergenciaProvider>();
    final pujas = emProvider.pujasActivas;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black87),
      ),
      body: Stack(
        children: [
          // 1. Mapa de fondo con la ubicación del cliente
          Positioned.fill(
            child: EmergenciaMapWidget(
              userLocation: context.read<InicioProvider>().userLocation,
            ),
          ),

          // 2. Efecto de Radar Holográfico en el centro
          const Center(
            child: RadarPulseEffect(),
          ),

          // 3. Header de estado en la parte superior
          Positioned(
            top: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: AppTheme.glassPill(radius: 20).copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
              child: Column(
                children: [
                  const Text(
                    'Buscando talleres cercanos...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hemos notificado a los talleres. Las ofertas aparecerán en tiempo real abajo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  if (emProvider.recomendaciones?.diagnosticoIa != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.withValues(alpha: 0.1)),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: false,
                          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                          title: Row(
                            children: [
                              const Icon(Icons.smart_toy, color: Colors.purple, size: 16),
                              const SizedBox(width: 8),
                              const Text('Diagnóstico de IA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple)),
                              const Spacer(),
                              if (emProvider.recomendaciones!.diagnosticoIa.nivelGravedad != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    emProvider.recomendaciones!.diagnosticoIa.nivelGravedad!,
                                    style: TextStyle(fontSize: 10, color: Colors.red.shade700, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          children: [
                            Text(
                              emProvider.recomendaciones!.diagnosticoIa.problemaDetectado ?? 'Evaluando daños reportados...',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                              textAlign: TextAlign.left,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 4. Panel inferior de Pujas (DraggableScrollableSheet)
          if (pujas.isNotEmpty)
            DraggableScrollableSheet(
              initialChildSize: 0.45,
              minChildSize: 0.25,
              maxChildSize: 0.8,
              snap: true,
              snapSizes: const [0.25, 0.45, 0.8],
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 15,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        height: 5,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${pujas.length} Ofertas Recibidas',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(Icons.sort, color: AppTheme.primaryColor),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: pujas.length,
                          padding: const EdgeInsets.only(top: 8, bottom: 24),
                          itemBuilder: (context, index) {
                            final puja = pujas[index];
                            return PujaCardItem(puja: puja);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class PujaCardItem extends StatelessWidget {
  final Map<String, dynamic> puja;

  const PujaCardItem({super.key, required this.puja});

  @override
  Widget build(BuildContext context) {
    final emProvider = context.read<EmergenciaProvider>();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  radius: 24,
                  child: const Icon(Icons.build_circle, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        puja['taller_nombre'] != null 
                          ? '${puja['taller_nombre']} - ${puja['sucursal_nombre'] ?? ''}' 
                          : (puja['sucursal_nombre'] ?? 'Taller Mecánico'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            puja['rating'].toString(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on, color: Colors.grey, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${puja['distancia_km']} km',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Precio est.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      'Bs. ${puja['precio_estimado']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Llega en ${puja['tiempo_llegada_minutos']} min',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      emProvider.aceptarPuja(puja['id']);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Aceptar Oferta'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RadarPulseEffect extends StatefulWidget {
  const RadarPulseEffect({super.key});

  @override
  State<RadarPulseEffect> createState() => _RadarPulseEffectState();
}

class _RadarPulseEffectState extends State<RadarPulseEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Container(
          width: 150 + (100 * value),
          height: 150 + (100 * value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 1.0 - value),
              width: 2,
            ),
            color: AppTheme.primaryColor.withValues(alpha: (1.0 - value) * 0.1),
          ),
        );
      },
    );
  }
}
