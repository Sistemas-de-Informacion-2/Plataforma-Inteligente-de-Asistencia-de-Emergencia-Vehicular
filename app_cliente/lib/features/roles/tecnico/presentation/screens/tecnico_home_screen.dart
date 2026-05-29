import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';

import '../providers/mecanico_provider.dart';
import '../widgets/mechanic_map_widget.dart';
import '../widgets/mechanic_drawer_widget.dart';
import '../widgets/mechanic_bottom_sheet_widget.dart';

class TecnicoHomeScreen extends ConsumerWidget {
  const TecnicoHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      drawer: const MechanicDrawerWidget(),
      body: Stack(
        children: [
          // Capa Fondo: Mapa
          const MechanicMapWidget(),

          // Capa Superior: Botones superpuestos
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Botón para abrir el menu
                  Builder(
                    builder: (context) {
                      return CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 24,
                        child: IconButton(
                          icon: const Icon(CupertinoIcons.bars, color: Colors.black),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      );
                    }
                  ),
                  
                  // Toggle Conectado / Desconectado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          isOnline ? 'Conectado' : 'Desconectado',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isOnline ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoSwitch(
                          value: isOnline,
                          activeTrackColor: Colors.green,
                          onChanged: (value) {
                            ref.read(isOnlineProvider.notifier).setStatus(value);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Botón de notificaciones
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(CupertinoIcons.bell, color: Colors.black),
                      onPressed: () {
                        // TODO: Navegar a la pantalla de notificaciones
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Capa Inferior: Bottom Sheet para interactuar con los estados
          const MechanicBottomSheetWidget(),
        ],
      ),
    );
  }
}
