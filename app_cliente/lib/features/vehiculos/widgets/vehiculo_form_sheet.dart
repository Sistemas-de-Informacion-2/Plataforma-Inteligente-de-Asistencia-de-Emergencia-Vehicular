import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_cliente/core/theme/app_theme.dart';
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
  final _marcaController    = TextEditingController();
  final _modeloController   = TextEditingController();
  final _anioController     = TextEditingController();
  final _placaController    = TextEditingController();
  bool _isLoading = false;

  bool get _isEditing => widget.vehiculo != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _marcaController.text  = widget.vehiculo!.marca;
      _modeloController.text = widget.vehiculo!.modelo;
      _anioController.text   = widget.vehiculo!.anio.toString();
      _placaController.text  = widget.vehiculo!.placa;
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final provider = context.read<VehiculoProvider>();
    final bool success = _isEditing
        ? await provider.updateVehiculo(
            widget.vehiculo!.id,
            marca:  _marcaController.text.trim(),
            modelo: _modeloController.text.trim(),
            anio:   int.parse(_anioController.text.trim()),
            placa:  _placaController.text.trim().toUpperCase(),
          )
        : await provider.addVehiculo(
            marca:  _marcaController.text.trim(),
            modelo: _modeloController.text.trim(),
            anio:   int.parse(_anioController.text.trim()),
            placa:  _placaController.text.trim().toUpperCase(),
          );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing
              ? 'Vehículo actualizado exitosamente'
              : 'Vehículo agregado exitosamente'),
          backgroundColor: AppTheme.success,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(provider.errorMessage),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Text(
              _isEditing ? 'Editar Vehículo' : 'Añadir Vehículo',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              _isEditing
                  ? 'Actualiza los datos de tu vehículo'
                  : 'Registra un nuevo vehículo para emergencias',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),

            const SizedBox(height: 24),

            // Marca
            _FormField(
              controller: _marcaController,
              label: 'Marca',
              hint: 'Ej. Toyota',
              icon: Icons.branding_watermark_rounded,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 14),

            // Modelo
            _FormField(
              controller: _modeloController,
              label: 'Modelo',
              hint: 'Ej. Corolla',
              icon: Icons.directions_car_outlined,
              validator: (v) =>
                  v == null || v.isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 14),

            // Año y Placa
            Row(
              children: [
                Expanded(
                  child: _FormField(
                    controller: _anioController,
                    label: 'Año',
                    hint: '2020',
                    icon: Icons.calendar_today_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requerido';
                      final n = int.tryParse(v);
                      if (n == null || n < 1900 || n > 2100) return 'Inválido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _FormField(
                    controller: _placaController,
                    label: 'Placa',
                    hint: 'ABC-123',
                    icon: Icons.confirmation_number_outlined,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Botón guardar
            _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.primaryColor))
                : FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _isEditing ? 'ACTUALIZAR' : 'GUARDAR VEHÍCULO',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Campo de texto estilizado para el formulario
class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?) validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.danger),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
    );
  }
}
