import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/presentation/providers/perfil_provider.dart';

class MechanicDrawerWidget extends StatelessWidget {
  const MechanicDrawerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final perfilProvider = context.watch<PerfilProvider>();
    final perfil = perfilProvider.perfil;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(perfil?.nombre ?? 'Cargando...'),
            accountEmail: Text(perfil?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: perfil?.fotoPerfil != null
                  ? NetworkImage(perfil!.fotoPerfil!)
                  : null,
              child: perfil?.fotoPerfil == null
                  ? const Icon(CupertinoIcons.person_alt, size: 40, color: Colors.grey)
                  : null,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.person),
            title: const Text('Ver perfil'),
            onTap: () {
              // TODO: Navegar a perfil del mecánico
              context.pop();
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.doc_text),
            title: const Text('Asignaciones'),
            onTap: () {
              // TODO: Navegar a asignaciones
              context.pop();
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.wrench),
            title: const Text('Especialidades (CRUD)'),
            onTap: () {
              // TODO: Navegar a especialidades
              context.pop();
            },
          ),
          ListTile(
            leading: const Icon(CupertinoIcons.bell),
            title: const Text('Notificaciones'),
            onTap: () {
              // TODO: Navegar a notificaciones
              context.pop();
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(CupertinoIcons.square_arrow_right, color: Colors.red),
            title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
            onTap: () async {
              context.pop(); // Cierra el drawer
              await context.read<AuthProvider>().logout();
              // go_router detecta el cambio a unauthenticated y redirige a /login
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
