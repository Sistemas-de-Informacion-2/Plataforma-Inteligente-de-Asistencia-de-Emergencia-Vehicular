import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../shared/presentation/providers/perfil_provider.dart';
import '../providers/mecanico_provider.dart';

// ── Widget principal ─────────────────────────────────────────────────────────
class MechanicDrawerWidget extends ConsumerWidget {
  const MechanicDrawerWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = context.watch<PerfilProvider>().perfil;
    final isOnline = ref.watch(isOnlineProvider);

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _DrawerHeader(perfil: perfil, isOnline: isOnline),
          const _StatusTile(),
          const SizedBox(height: 6),
          const _SectionLabel('General'),
          _NavItem(
            icon: CupertinoIcons.person_crop_circle,
            iconColor: AppTheme.primaryColor,
            iconBg: AppTheme.primaryColor.withValues(alpha: 0.10),
            label: 'Ver perfil',
            onTap: () {
              context.pop();
              Future.delayed(const Duration(milliseconds: 200), () {
                if (context.mounted) {
                  context.push('/tecnico-perfil');
                }
              });
            },
          ),
          _NavItem(
            icon: CupertinoIcons.doc_text_fill,
            iconColor: AppTheme.warning,
            iconBg: AppTheme.warning.withValues(alpha: 0.12),
            label: 'Asignaciones',
            badge: '3',
            onTap: () {
              context.pop();
              context.push('/tecnico-asignaciones');
            },
          ),
          _NavItem(
            icon: CupertinoIcons.wrench_fill,
            iconColor: AppTheme.success,
            iconBg: AppTheme.success.withValues(alpha: 0.10),
            label: 'Especialidades',
            onTap: () => context.pop(),
          ),
          const _SectionDivider(),
          const _SectionLabel('Preferencias'),
          _NavItem(
            icon: CupertinoIcons.bell_fill,
            iconColor: AppTheme.secondaryColor,
            iconBg: AppTheme.secondaryColor.withValues(alpha: 0.10),
            label: 'Notificaciones',
            onTap: () => context.pop(),
          ),
          const Spacer(),
          const Divider(height: 1),
          const _LogoutTile(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _DrawerHeader extends StatelessWidget {
  // Reemplazá `dynamic` con tu tipo real: PerfilModel? u otro
  final dynamic perfil;
  final bool isOnline;

  const _DrawerHeader({required this.perfil, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        // Usa inkDark → primaryColor, mismo gradiente que tu AppBar
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.inkDark, AppTheme.secondaryColor],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                backgroundImage: perfil?.fotoPerfil != null
                    ? NetworkImage(perfil!.fotoPerfil!)
                    : null,
                child: perfil?.fotoPerfil == null
                    ? const Icon(
                        CupertinoIcons.person_alt,
                        size: 26,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      perfil?.nombre ?? 'Cargando...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      perfil?.email ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    // success de AppTheme cuando online, muted cuando offline
                    color: isOnline
                        ? AppTheme.success
                        : Colors.white.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Mecánico Certificado',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Tile ── ConsumerWidget propio, no recibe ref ───────────────────────

class _StatusTile extends ConsumerWidget {
  const _StatusTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.textSecondary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isOnline
                  ? AppTheme.success.withValues(alpha: 0.12)
                  : AppTheme.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isOnline
                  ? CupertinoIcons.bolt_fill
                  : CupertinoIcons.bolt_slash_fill,
              size: 18,
              color: isOnline ? AppTheme.success : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'Finalizar Turno' : 'Iniciar Turno',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isOnline ? AppTheme.success : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  isOnline ? 'Estás en línea y visible' : 'Estás desconectado',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: isOnline,
            activeTrackColor: AppTheme.success,
            onChanged: (value) =>
                ref.read(isOnlineProvider.notifier).setStatus(value),
          ),
        ],
      ),
    );
  }
}

// ── Nav Item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              )
            : Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
        onTap: onTap,
      ),
    );
  }
}

// ── Logout Tile ── ConsumerWidget propio, no recibe ref ───────────────────────
class _LogoutTile extends ConsumerWidget {
  const _LogoutTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.dangerSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            CupertinoIcons.square_arrow_right,
            size: 17,
            color: AppTheme.danger,
          ),
        ),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.danger,
          ),
        ),
        onTap: () async {
          context.pop();

          // 1. Limpiar estado en Riverpod
          ref.invalidate(mecanicoControllerProvider);
          ref.invalidate(isOnlineProvider);

          // 2. Limpiar Storage profundo
          await context.read<AuthProvider>().logout();

          // 3. go_router detecta el cambio a unauthenticated y redirige a /login
          if (context.mounted) {
            context.go('/login');
          }
        },
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          letterSpacing: 1.2, color: AppTheme.textSecondary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
      color: AppTheme.textSecondary.withValues(alpha: 0.12),
    );
  }
}