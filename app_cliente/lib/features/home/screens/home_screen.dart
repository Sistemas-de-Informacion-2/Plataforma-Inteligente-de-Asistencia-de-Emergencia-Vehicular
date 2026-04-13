import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_cliente/core/theme/app_theme.dart';
import 'package:app_cliente/features/auth/providers/auth_provider.dart';
import 'package:app_cliente/features/auth/screens/login_screen.dart';
import 'package:app_cliente/features/vehiculos/screens/garaje_screen.dart';
import 'package:app_cliente/features/perfil/screens/perfil_screen.dart';
import 'package:app_cliente/features/perfil/providers/perfil_provider.dart';
import 'package:app_cliente/features/emergencias/screens/inicio_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      // El mapa cubre todo — sin AppBar
      extendBodyBehindAppBar: true,
      drawer: _buildDrawer(context),
      // InicioScreen recibe el callback para abrir el drawer
      body: InicioScreen(
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final perfilProvider = context.watch<PerfilProvider>();
    final perfil = perfilProvider.perfil;
    final mq = MediaQuery.of(context);

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // ── Header premium ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: mq.padding.top + 20,
              left: 24,
              right: 24,
              bottom: 24,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, Color(0xFF0047CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.5), width: 2),
                    image: perfil?.fotoPerfil != null
                        ? DecorationImage(
                            image: NetworkImage(perfil!.fotoPerfil!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: perfil?.fotoPerfil == null
                      ? const Icon(Icons.person_rounded,
                          size: 36, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 14),
                Text(
                  perfil?.nombre ?? 'Cargando…',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  perfil?.email ?? 'CLIENTE',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // ── Menu items ──────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Mi Perfil',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PerfilScreen()));
                  },
                ),
                _DrawerTile(
                  icon: Icons.directions_car_outlined,
                  label: 'Mis Autos',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GarajeScreen()));
                  },
                ),
                _DrawerTile(
                  icon: Icons.history_rounded,
                  label: 'Historial de Servicios',
                  onTap: () => Navigator.pop(context),
                ),
                _DrawerTile(
                  icon: Icons.settings_outlined,
                  label: 'Configuración',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ── Footer ──────────────────────────────────────────
          const Divider(height: 1),
          _DrawerTile(
            icon: Icons.logout_rounded,
            label: 'Cerrar Sesión',
            destructive: true,
            onTap: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
          SizedBox(height: mq.padding.bottom + 8),
        ],
      ),
    );
  }
}

/// Tile reutilizable del Drawer
class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppTheme.danger : AppTheme.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (destructive ? AppTheme.danger : AppTheme.primaryColor)
                  .withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          trailing: destructive
              ? null
              : const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
