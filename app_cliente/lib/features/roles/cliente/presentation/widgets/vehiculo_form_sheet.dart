import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../providers/vehiculo_provider.dart';
import '../../data/models/vehiculo.dart';

// Widget para agregar o editar un vehículo.
// Bottom sheet con formulario estilizado, validación y feedback visual.
class VehiculoFormSheet extends StatefulWidget {
  final Vehiculo? vehiculo;
  const VehiculoFormSheet({super.key, this.vehiculo});

  @override
  State<VehiculoFormSheet> createState() => _VehiculoFormSheetState();
}

class _VehiculoFormSheetState extends State<VehiculoFormSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anioController = TextEditingController();
  final _placaController = TextEditingController();

  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<double> _entrySlide;

  bool _isLoading = false;

  bool get _isEditing => widget.vehiculo != null;

  @override
  void initState() {
    super.initState();

    // Animación de entrada del sheet
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _entryFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _entrySlide = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _entryCtrl.forward();

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
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

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

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      HapticFeedback.heavyImpact();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                _isEditing
                    ? 'Vehículo actualizado correctamente'
                    : 'Vehículo guardado en tu garaje',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  provider.errorMessage,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedBuilder(
      animation: _entryCtrl,
      builder: (context, child) {
        return Opacity(
          opacity: _entryFade.value,
          child: Transform.translate(
            offset: Offset(0, _entrySlide.value),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPadding + 28),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Encabezado del formulario
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _isEditing ? Icons.edit_note_rounded : Icons.add_road_rounded,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isEditing ? 'Editar vehículo' : 'Registrar vehículo',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            _isEditing
                                ? 'Modifica los detalles de tu auto'
                                : 'Ingresa los datos para el registro',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Marca
                _FormField(
                  controller: _marcaController,
                  label: 'Marca',
                  hint: 'Ej. Toyota, Nissan...',
                  icon: Icons.branding_watermark_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'La marca es obligatoria' : null,
                ),
                const SizedBox(height: 14),

                // Modelo
                _FormField(
                  controller: _modeloController,
                  label: 'Modelo',
                  hint: 'Ej. Corolla, Sentra...',
                  icon: Icons.directions_car_filled_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'El modelo es obligatorio' : null,
                ),
                const SizedBox(height: 14),

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
                          if (n == null || n < 1950 || n > 2030) {
                            return 'Año inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: _FormField(
                        controller: _placaController,
                        label: 'Placa',
                        hint: 'ABC-123',
                        icon: Icons.pin_outlined,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [LengthLimitingTextInputFormatter(10)],
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Ingresa la placa'
                            : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Botón guardar
                SizedBox(
                  height: 54,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                                strokeWidth: 2.5,
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ).copyWith(
                              elevation: WidgetStateProperty.resolveWith(
                                (s) => s.contains(WidgetState.pressed) ? 0 : 3,
                              ),
                              shadowColor: WidgetStatePropertyAll(
                                AppTheme.primaryColor.withValues(alpha: 0.35),
                              ),
                            ),
                            icon: Icon(
                              _isEditing
                                  ? Icons.save_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 20,
                            ),
                            label: Text(
                              _isEditing ? 'Actualizar datos' : 'Registrar vehículo',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FormField reutilizable con estilo unificado
// ─────────────────────────────────────────────────────────────────────────────
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
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, size: 20, color: AppTheme.textSecondary),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
        ),
        labelStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 13,
        ),
      ),
    );
  }
}
