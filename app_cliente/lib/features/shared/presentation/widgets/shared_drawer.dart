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
    // Animación más rápida y fluida para no consumir recursos
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
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
      backgroundColor: AppTheme.backgroundColor,
      elevation: 0,
      width: mq.size.width * 0.85, // Un poco más ancho para más elegancia
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // ── Header Premium ────────────────────
          _buildPremiumHeader(context, perfil, mq),

          // ── Menú Items con Animación Staggered ───────────────
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                _AnimatedTile(
                  index: 0,
                  controller: _controller,
                  icon: Icons.person_rounded,
                  label: 'Mi Perfil',
                  subtitle: 'Datos personales y foto',
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
                  icon: Icons.directions_car_rounded,
                  label: 'Mi Garaje',
                  subtitle: 'Gestiona tus vehículos',
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
                  label: 'Historial',
                  subtitle: 'Servicios anteriores',
                  onTap: () => Navigator.pop(context),
                ),
                _AnimatedTile(
                  index: 3,
                  controller: _controller,
                  icon: Icons.notifications_active_rounded,
                  label: 'Notificaciones',
                  subtitle: 'Avisos y alertas',
                  onTap: () => Navigator.pop(context),
                ),
                
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE5E5EA)),
                const SizedBox(height: 16),

                _AnimatedTile(
                  index: 4,
                  controller: _controller,
                  icon: Icons.settings_rounded,
                  label: 'Configuración',
                  onTap: () => Navigator.pop(context),
                  isSimple: true,
                ),
                _AnimatedTile(
                  index: 5,
                  controller: _controller,
                  icon: Icons.help_outline_rounded,
                  label: 'Soporte y Ayuda',
                  onTap: () => Navigator.pop(context),
                  isSimple: true,
                ),
              ],
            ),
          ),

          // ── Logo Fixo Footer ────────────────────────────────
          Opacity(
            opacity: 0.5,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
               mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'FIXO v1.0.2',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Botón Cerrar Sesión ──────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, mq.padding.bottom + 24),
            child: InkWell(
              onTap: () async {
                Navigator.pop(context);
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: AppTheme.danger, size: 22),
                    SizedBox(width: 12),
                    Text(
                      'Cerrar Sesión',
                      style: TextStyle(
                        color: AppTheme.danger,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, dynamic perfil, MediaQueryData mq) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, mq.padding.top + 30, 24, 30),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar con Glow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  backgroundImage: perfil?.fotoPerfil != null
                      ? NetworkImage(perfil!.fotoPerfil!)
                      : null,
                  child: perfil?.fotoPerfil == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 40,
                          color: AppTheme.primaryColor,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perfil?.nombre ?? 'Usuario',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, color: AppTheme.success, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Cuenta Verificada',
                            style: TextStyle(
                              color: AppTheme.success.withValues(alpha: 0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (perfil?.email != null) ...[
            const SizedBox(height: 16),
            Text(
              perfil!.email!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ]
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
  final String? subtitle;
  final VoidCallback onTap;
  final bool isSimple;

  const _AnimatedTile({
    required this.index,
    required this.controller,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.isSimple = false,
  });

  @override
  Widget build(BuildContext context) {
    // Staggered timing
    final start = (0.05 * index).clamp(0.0, 1.0);
    final end = (start + 0.4).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final animation = CurvedAnimation(
          parent: controller,
          curve: Interval(start, end, curve: Curves.easeOutBack), // Efecto resorte suave
        );
        return Transform.translate(
          offset: Offset(40 * (1 - animation.value), 0),
          child: Opacity(opacity: animation.value.clamp(0.0, 1.0), child: child),
        );
      },
      child: _DrawerItem(
        icon: icon, 
        label: label, 
        subtitle: subtitle, 
        onTap: onTap,
        isSimple: isSimple,
      ),
    );
  }
}

class _DrawerItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isSimple;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.isSimple = false,
  });

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (val) => setState(() => _isHovered = val),
        borderRadius: BorderRadius.circular(20),
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.05),
        highlightColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(widget.isSimple ? 12 : 16),
          decoration: BoxDecoration(
            color: _isHovered ? AppTheme.primaryColor.withValues(alpha: 0.03) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.isSimple ? Colors.grey.shade100 : AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.isSimple ? Colors.grey.shade700 : AppTheme.primaryColor,
                  size: widget.isSimple ? 20 : 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: widget.isSimple ? 15 : 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _isHovered ? AppTheme.primaryColor : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

