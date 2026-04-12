import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_cliente/features/vehiculos/providers/vehiculo_provider.dart';

import 'package:app_cliente/features/vehiculos/models/vehiculo.dart';

class VehiculoFormSheet extends StatefulWidget {
  final Vehiculo? vehiculo;
  const VehiculoFormSheet({super.key, this.vehiculo});

  @override
  State<VehiculoFormSheet> createState() => _VehiculoFormSheetState();
}

class _VehiculoFormSheetState extends State<VehiculoFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anioController = TextEditingController();
  final _placaController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.vehiculo != null) {
      _marcaController.text = widget.vehiculo!.marca;
      _modeloController.text = widget.vehiculo!.modelo;
      _anioController.text = widget.vehiculo!.anio.toString();
      _placaController.text = widget.vehiculo!.placa;
    }
  }

  @override
  void dispose() {
    _marcaController.dispose();
    _modeloController.dispose();
    _anioController.dispose();
    _placaController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final provider = context.read<VehiculoProvider>();
      final isEditing = widget.vehiculo != null;
      bool success;

      if (isEditing) {
        success = await provider.updateVehiculo(
          widget.vehiculo!.id,
          marca: _marcaController.text.trim(),
          modelo: _modeloController.text.trim(),
          anio: int.parse(_anioController.text.trim()),
          placa: _placaController.text.trim().toUpperCase(),
        );
      } else {
        success = await provider.addVehiculo(
          marca: _marcaController.text.trim(),
          modelo: _modeloController.text.trim(),
          anio: int.parse(_anioController.text.trim()),
          placa: _placaController.text.trim().toUpperCase(),
        );
      }

      setState(() => _isLoading = false);

      if (success) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? 'Vehículo actualizado existosamente' : 'Vehículo agregado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.errorMessage), backgroundColor: Colors.redAccent),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Para que el bottom sheet no quede tapado por el teclado
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomPadding + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Añadir Vehículo',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _marcaController,
              decoration: const InputDecoration(labelText: 'Marca (Ej. Toyota) *'),
              validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _modeloController,
              decoration: const InputDecoration(labelText: 'Modelo (Ej. Corolla) *'),
              validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _anioController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Año *'),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Requerido';
                      final num = int.tryParse(val);
                      if (num == null || num < 1900 || num > 2100) return 'Año inválido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _placaController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Placa *'),
                    validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit,
                    child: const Text('GUARDAR VEHÍCULO'),
                  ),
          ],
        ),
      ),
    );
  }
}
