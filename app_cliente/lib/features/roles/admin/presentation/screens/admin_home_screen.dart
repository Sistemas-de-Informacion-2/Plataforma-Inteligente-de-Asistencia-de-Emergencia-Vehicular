import 'package:flutter/material.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Taller (Radar)'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'Aquí el Admin verá los SOS en el radar\ny podrá lanzar ofertas (Pujas).',
          textAlign: TextAlign.center,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.radar),
            label: 'Radar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Asignaciones',
          ),
        ],
      ),
    );
  }
}
