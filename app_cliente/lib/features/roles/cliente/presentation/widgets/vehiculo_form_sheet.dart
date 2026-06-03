import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../providers/vehiculo_provider.dart';
import '../../data/models/vehiculo.dart';

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

  bool get _isEditing => widget.vehiculo != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final provider = context.read<VehiculoProvider>();
    final bool success = _isEditing
        ? await provider.updateVehiculo(
            widget.vehiculo!.id,
            marca: _marcaController.text.trim(),
            modelo: _modeloController.text.trim(),
            anio: int.tryParse(_anioController.text.trim()) ?? 0,
            placa: _placaController.text.trim().toUpperCase(),
          )
        : await provider.addVehiculo(
            marca: _marcaController.text.trim(),
            modelo: _modeloController.text.trim(),
            anio: int.parse(_anioController.text.trim()),
            placa: _placaController.text.trim().toUpperCase(),
          );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  _isEditing
                      ? 'Vehículo actualizado correctamente'
                      : 'Vehículo guardado en tu garaje',
                ),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPadding + 32),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle Premium
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Titulo del formulario
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isEditing
                          ? Icons.edit_note_rounded
                          : Icons.add_road_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Editar Vehículo' : 'Nuevo Vehículo',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          _isEditing
                              ? 'Modifica los detalles de tu auto'
                              : 'Ingresa los datos para el registro',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Marca
              _FormField(
                controller: _marcaController,
                label: 'Marca del Vehí­culo',
                hint: 'Ej. Toyota, Nissan...',
                icon: Icons.branding_watermark_outlined,
                validator: (v) =>
                    v == null || v.isEmpty ? 'La marca es obligatoria' : null,
              ),
              const SizedBox(height: 16),

              // Modelo
              _FormField(
                controller: _modeloController,
                label: 'Modelo',
                hint: 'Ej. Corolla, Sentra...',
                icon: Icons.directions_car_filled_outlined,
                validator: (v) =>
                    v == null || v.isEmpty ? 'El modelo es obligatorio' : null,
              ),
              const SizedBox(height: 16),

              // Año y Placa en fila
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _FormField(
                      controller: _anioController,
                      label: 'Año',
                      hint: '2024',
                      icon: Icons.calendar_month_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        final n = int.tryParse(v);
                        if (n == null || n < 1950 || n > 2026) {
                          return 'Año inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: _FormField(
                      controller: _placaController,
                      label: 'Placa / Matrícula',
                      hint: 'ABC-123',
                      icon: Icons.pin_outlined,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(10)],
                      validator: (v) => v == null || v.isEmpty
                          ? 'La placa es necesaria'
                          : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Boton Guardar con estilo premium
              SizedBox(
                height: 56,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _isEditing
                              ? 'ACTUALIZAR DATOS'
                              : 'REGISTRAR VEHÍCULO',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?) validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 22),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppTheme.primaryColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
