import 'package:flutter/material.dart';

class TecnicoHomeScreen extends StatelessWidget {
  const TecnicoHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Técnico (Mecánico)'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Aquí el Técnico recibirá notificaciones\nde trabajos asignados y usará navegación Turn-by-Turn.',
          textAlign: TextAlign.center,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.build),
            label: 'Trabajos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mapa',
          ),
        ],
      ),
    );
  }
}
