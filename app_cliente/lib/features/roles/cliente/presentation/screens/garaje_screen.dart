import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../providers/vehiculo_provider.dart';
import '../widgets/vehiculo_form_sheet.dart';
import '../../data/models/vehiculo.dart';
import '../widgets/vehiculo_card.dart';
import '../widgets/empty_garaje.dart';

class GarajeScreen extends StatefulWidget {
  const GarajeScreen({super.key});

  @override
  State<GarajeScreen> createState() => _GarajeScreenState();
}

class _GarajeScreenState extends State<GarajeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Eliminar Vehículo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar tu ${vehiculo.marca} ${vehiculo.modelo}?\n\nEsta acción no se puede deshacer.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCELAR',
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<VehiculoProvider>().deleteVehiculo(vehiculo.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.delete_sweep_rounded, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Vehículo eliminado correctamente'),
                      ],
                    ),
                    backgroundColor: const Color.fromRGBO(239, 68, 68, 1),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: const Text('ELIMINAR', style: TextStyle(fontWeight: FontWeight.bold)),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        titleTextStyle: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
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
            return EmptyGaraje(
              onAddTap: () => _showAddOrEditSheet(context),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: provider.fetchVehiculos,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
              itemCount: provider.vehiculos.length,
              itemBuilder: (context, index) {
                final vehiculo = provider.vehiculos[index];
                
                // Intervalo de animación escalonado
                final animation = CurvedAnimation(
                  parent: _animationController,
                  curve: Interval(
                    (0.1 * index).clamp(0, 1.0),
                    (0.1 * index + 0.5).clamp(0, 1.0),
                    curve: Curves.easeOutCubic,
                  ),
                );

                return VehiculoCard(
                  vehiculo: vehiculo,
                  animation: animation,
                  onEdit: () => _showAddOrEditSheet(context, vehiculo: vehiculo),
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
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'AÑADIR AUTO',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }
}
