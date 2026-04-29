import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fixo/core/theme/app_theme.dart';
import 'package:fixo/features/perfil/providers/perfil_provider.dart';

class PerfilHeader extends StatelessWidget {
  const PerfilHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PerfilProvider>();

    return Column(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: AppTheme.softShadow,
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.05),
                  backgroundImage: provider.perfil?.fotoPerfil != null
                      ? NetworkImage(provider.perfil!.fotoPerfil!)
                      : null,
                  child: provider.perfil?.fotoPerfil == null
                      ? Icon(Icons.person_rounded,
                          size: 60, color: AppTheme.primaryColor.withOpacity(0.5))
                      : null,
                ),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: Implementar cambio de foto
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: AppTheme.softShadow,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          provider.perfil?.nombre ?? '',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          provider.perfil?.email ?? '',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}