import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/perfil_provider.dart';
import '../screens/perfil_screen.dart';
import '../../../roles/cliente/presentation/screens/garaje_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';

class HomeDrawer extends StatefulWidget {
  const HomeDrawer({super.key});

  @override
  State<HomeDrawer> createState() => _HomeDrawerState();
}

class _HomeDrawerState extends State<HomeDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perfilProvider = context.watch<PerfilProvider>();
    final perfil = perfilProvider.perfil;
    final mq = MediaQuery.of(context);

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // ── Header Premium con Gradiente ────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, mq.padding.top + 20, 24, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withAlpha(220),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(40),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar con Borde Elegante
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.grey.shade100,
                    backgroundImage: perfil?.fotoPerfil != null
                        ? NetworkImage(perfil!.fotoPerfil!)
                        : null,
                    child: perfil?.fotoPerfil == null
                        ? const Icon(
                            Icons.person_rounded,
                            size: 38,
                            color: AppTheme.primaryColor,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        perfil?.nombre ?? 'Cargando...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          perfil?.email ?? 'Cliente Verificado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Menú Items con Animación Staggered ───────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                _AnimatedTile(
                  index: 0,
                  controller: _controller,
                  icon: Icons.person_outline_rounded,
                  label: 'Mi Perfil',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PerfilScreen()),
                    );
                  },
                ),
                _AnimatedTile(
                  index: 1,
                  controller: _controller,
                  icon: Icons.directions_car_outlined,
                  label: 'Mis Autos',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GarajeScreen()),
                    );
                  },
                ),
                _AnimatedTile(
                  index: 2,
                  controller: _controller,
                  icon: Icons.history_rounded,
                  label: 'Historial de Servicios',
                  onTap: () => Navigator.pop(context),
                ),
                _AnimatedTile(
                  index: 3,
                  controller: _controller,
                  icon: Icons.notifications_none_rounded,
                  label: 'Notificaciones',
                  onTap: () => Navigator.pop(context),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFF2F2F7)),
                ),
                _AnimatedTile(
                  index: 4,
                  controller: _controller,
                  icon: Icons.settings_outlined,
                  label: 'Configuración',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ── Logo Fixo Footer ────────────────────────────────
          Opacity(
            opacity: 0.4,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'FIXO v1.0.2',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Botón Cerrar Sesión ──────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, mq.padding.bottom + 20),
            child: _DrawerTile(
              icon: Icons.logout_rounded,
              label: 'Cerrar Sesión',
              destructive: true,
              onTap: () async {
                Navigator.pop(context);
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTile extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AnimatedTile({
    required this.index,
    required this.controller,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final start = 0.1 * index;
    final end = start + 0.5;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final animation = CurvedAnimation(
          parent: controller,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        );
        return Transform.translate(
          offset: Offset(30 * (1 - animation.value), 0),
          child: Opacity(opacity: animation.value, child: child),
        );
      },
      child: _DrawerTile(icon: icon, label: label, onTap: onTap),
    );
  }
}

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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: destructive ? color.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: destructive ? Colors.transparent : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: destructive ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        trailing: destructive
            ? null
            : const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFFC7C7CC),
              ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
