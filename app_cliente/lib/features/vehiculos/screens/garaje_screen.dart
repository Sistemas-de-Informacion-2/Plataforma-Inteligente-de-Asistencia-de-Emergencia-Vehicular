import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_cliente/features/vehiculos/providers/vehiculo_provider.dart';
import 'package:app_cliente/features/vehiculos/widgets/vehiculo_form_sheet.dart';
import 'package:app_cliente/features/vehiculos/models/vehiculo.dart';

class GarajeScreen extends StatelessWidget {
  const GarajeScreen({super.key});

  void _showAddOrEditSheet(BuildContext context, {Vehiculo? vehiculo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Importante para que el teclado desplace el modal
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => VehiculoFormSheet(vehiculo: vehiculo),
    );
  }

  void _showDeleteDialog(BuildContext context, Vehiculo vehiculo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Vehículo'),
        content: Text('¿Seguro que deseas eliminar el ${vehiculo.marca} ${vehiculo.modelo} (${vehiculo.placa})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<VehiculoProvider>().deleteVehiculo(vehiculo.id);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vehículo eliminado'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<VehiculoProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.vehiculos.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.vehiculos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes vehículos registrados',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.fetchVehiculos,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.vehiculos.length,
              itemBuilder: (context, index) {
                final vehiculo = provider.vehiculos[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Icon(Icons.directions_car, color: Theme.of(context).primaryColor),
                    ),
                    title: Text(
                      '${vehiculo.marca} ${vehiculo.modelo}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Año: ${vehiculo.anio} | Placa: ${vehiculo.placa}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showAddOrEditSheet(context, vehiculo: vehiculo);
                        } else if (value == 'delete') {
                          _showDeleteDialog(context, vehiculo);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOrEditSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}
