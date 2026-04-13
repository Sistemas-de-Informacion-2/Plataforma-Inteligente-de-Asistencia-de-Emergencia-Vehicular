import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_cliente/core/theme/app_theme.dart';
import 'package:app_cliente/features/vehiculos/providers/vehiculo_provider.dart';
import 'package:app_cliente/features/vehiculos/widgets/vehiculo_form_sheet.dart';
import 'package:app_cliente/features/vehiculos/models/vehiculo.dart';

class GarajeScreen extends StatelessWidget {
  const GarajeScreen({super.key});

  void _showAddOrEditSheet(BuildContext context, {Vehiculo? vehiculo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VehiculoFormSheet(vehiculo: vehiculo),
    );
  }

  void _showDeleteDialog(BuildContext context, Vehiculo vehiculo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Eliminar Vehículo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
            '¿Seguro que deseas eliminar el ${vehiculo.marca} ${vehiculo.modelo} (${vehiculo.placa})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context
                  .read<VehiculoProvider>()
                  .deleteVehiculo(vehiculo.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vehículo eliminado'),
                    backgroundColor: AppTheme.danger,
                  ),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Mi Garaje'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
              height: 1, color: Colors.grey.shade100, thickness: 1),
        ),
      ),
      body: Consumer<VehiculoProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.vehiculos.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (provider.vehiculos.isEmpty) {
            return _EmptyGarage(
              onAddTap: () => _showAddOrEditSheet(context),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: provider.fetchVehiculos,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: provider.vehiculos.length,
              itemBuilder: (context, index) {
                final vehiculo = provider.vehiculos[index];
                return _VehicleCard(
                  vehiculo: vehiculo,
                  onEdit: () =>
                      _showAddOrEditSheet(context, vehiculo: vehiculo),
                  onDelete: () => _showDeleteDialog(context, vehiculo),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditSheet(context),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Añadir Auto',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _EmptyGarage extends StatelessWidget {
  final VoidCallback onAddTap;
  const _EmptyGarage({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_car_outlined,
                  size: 48, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tu garaje está vacío',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega tu primer vehículo para reportar emergencias de forma rápida.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onAddTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Añadir vehículo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehiculo vehiculo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VehicleCard({
    required this.vehiculo,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Ícono del auto
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.directions_car_rounded,
                  color: AppTheme.primaryColor, size: 26),
            ),
            const SizedBox(width: 14),

            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehiculo.marca} ${vehiculo.modelo}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _Chip(label: vehiculo.anio.toString()),
                      const SizedBox(width: 6),
                      _Chip(label: vehiculo.placa),
                    ],
                  ),
                ],
              ),
            ),

            // Menú
            PopupMenuButton<String>(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              icon: const Icon(Icons.more_vert_rounded,
                  color: AppTheme.textSecondary),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Editar'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: AppTheme.danger),
                    SizedBox(width: 10),
                    Text('Eliminar',
                        style: TextStyle(color: AppTheme.danger)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.muted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
