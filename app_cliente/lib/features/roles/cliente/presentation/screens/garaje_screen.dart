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

class _GarajeScreenState extends State<GarajeScreen>
    with SingleTickerProviderStateMixin {
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Eliminar Vehículo',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar tu ${vehiculo.marca} ${vehiculo.modelo}?\n\nEsta acción no se puede deshacer.',
          style: const TextStyle(height: 1.5, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CANCELAR',
              style: TextStyle(
                  color: Colors.grey.shade600, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context
                  .read<VehiculoProvider>()
                  .deleteVehiculo(vehiculo.id);
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
                    backgroundColor: AppTheme.danger,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: const Text('ELIMINAR',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer<VehiculoProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.vehiculos.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (provider.vehiculos.isEmpty) {
            return Column(
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: AppTheme.textPrimary),
                ),
                Expanded(
                  child: EmptyGaraje(
                    onAddTap: () => _showAddOrEditSheet(context),
                  ),
                ),
              ],
            );
          }

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: provider.fetchVehiculos,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: AppTheme.backgroundColor,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  iconTheme: const IconThemeData(color: AppTheme.textPrimary),
                  expandedHeight: 120.0,
                  flexibleSpace: const FlexibleSpaceBar(
                    titlePadding: EdgeInsets.only(left: 24, bottom: 16),
                    title: Text(
                      'Mi Garaje',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
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
                          onEdit: () =>
                              _showAddOrEditSheet(context, vehiculo: vehiculo),
                          onDelete: () => _showDeleteDialog(context, vehiculo),
                        );
                      },
                      childCount: provider.vehiculos.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditSheet(context),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.add_circle_outline_rounded),
        label: const Text(
          'Añadir auto',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}

