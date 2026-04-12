import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_cliente/features/auth/providers/auth_provider.dart';
import 'package:app_cliente/features/auth/screens/login_screen.dart';
import 'package:app_cliente/features/vehiculos/screens/garaje_screen.dart';
import 'package:app_cliente/features/perfil/screens/perfil_screen.dart';
import 'package:app_cliente/features/perfil/providers/perfil_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _InicioContentTab(), // Pestaña 0
    const GarajeScreen(),      // Pestaña 1
  ];

  final List<String> _titles = [
    'Inicio',
    'Mi Garaje',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        elevation: 0,
      ),
      drawer: _buildDrawer(context),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Inicio/Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_filled_outlined),
            activeIcon: Icon(Icons.directions_car),
            label: 'Mis Autos',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final perfilProvider = context.watch<PerfilProvider>();
    final perfil = perfilProvider.perfil;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            accountName: Text(perfil?.nombre ?? 'Cargando...'), 
            accountEmail: Text(perfil?.email ?? 'CLIENTE'), 
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: perfil?.fotoPerfil != null 
                  ? NetworkImage(perfil!.fotoPerfil!) 
                  : null,
              child: perfil?.fotoPerfil == null 
                  ? const Icon(Icons.person, size: 40, color: Colors.grey)
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Mi Perfil'),
            onTap: () {
              Navigator.pop(context); // Cierra drawer
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const PerfilScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historial de Servicios'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Configuración'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InicioContentTab extends StatelessWidget {
  const _InicioContentTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text('Mapa Principal (Próximamente)'),
        ],
      ),
    );
  }
}
