import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mecanico_provider.dart';

class MechanicBottomSheetWidget extends ConsumerStatefulWidget {
  const MechanicBottomSheetWidget({super.key});

  @override
  ConsumerState<MechanicBottomSheetWidget> createState() => _MechanicBottomSheetWidgetState();
}

class _MechanicBottomSheetWidgetState extends ConsumerState<MechanicBottomSheetWidget> {
  bool _isRejecting = false;
  final TextEditingController _rejectReasonController = TextEditingController();

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mecanicoControllerProvider);

    return DraggableScrollableSheet(
      initialChildSize: state == MecanicoState.idle ? 0.2 : 0.35,
      minChildSize: 0.15,
      maxChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildPanelContent(state),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanelContent(MecanicoState state) {
    // Indicador de arrastre (Draggable handle)
    final dragHandle = Center(
      child: Container(
        width: 40,
        height: 5,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    switch (state) {
      case MecanicoState.idle:
        return Column(
          children: [
            dragHandle,
            const SizedBox(height: 10),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Buscando emergencias en la zona...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            // TODO: Eliminar este botón, es temporal para demostrar el cambio de estado.
            ElevatedButton(
              onPressed: () {
                ref.read(mecanicoControllerProvider.notifier).receiveSos();
              },
              child: const Text('Simular SOS Recibido (Test)'),
            )
          ],
        );

      case MecanicoState.sosRecibido:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            dragHandle,
            const Text(
              '¡Nueva Emergencia!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Problema: Batería descargada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Distancia: 2.5 km (Aprox. 8 min)'),
                    SizedBox(height: 4),
                    Text('Cliente: Juan Pérez'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_isRejecting) ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  ref.read(mecanicoControllerProvider.notifier).acceptJob();
                },
                child: const Text('Aceptar Trabajo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    _isRejecting = true;
                  });
                },
                child: const Text('Rechazar', style: TextStyle(fontSize: 16)),
              ),
            ] else ...[
              TextField(
                controller: _rejectReasonController,
                decoration: const InputDecoration(
                  labelText: 'Razón de rechazo (Breve)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _isRejecting = false;
                          _rejectReasonController.clear();
                        });
                      },
                      child: const Text('Cancelar'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () {
                        ref.read(mecanicoControllerProvider.notifier).rejectJob(_rejectReasonController.text);
                        setState(() {
                          _isRejecting = false;
                          _rejectReasonController.clear();
                        });
                      },
                      child: const Text('Confirmar Rechazo'),
                    ),
                  ),
                ],
              ),
            ]
          ],
        );

      case MecanicoState.enRuta:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            dragHandle,
            const Text(
              'En ruta hacia el cliente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text('Juan Pérez', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Toyota Hilux 2020 - Placa: 1234ABC'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                // TODO: Navegar al chat con el cliente
              },
              icon: const Icon(Icons.chat),
              label: const Text('Abrir Chat con el Cliente', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                ref.read(mecanicoControllerProvider.notifier).arriveAtLocation();
              },
              child: const Text('Ya llegué', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        );
    }
  }
}
