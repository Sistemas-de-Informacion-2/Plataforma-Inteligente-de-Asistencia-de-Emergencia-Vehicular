import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:fixo/core/theme/app_theme.dart';

class PerfilForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController ciController;
  final TextEditingController nombreController;
  final TextEditingController segundoNombreController;
  final TextEditingController apellidoPaternoController;
  final TextEditingController apellidoMaternoController;
  final TextEditingController telefonoController;
  final TextEditingController fechaNacimientoController;
  final MaskTextInputFormatter dateMaskFormatter;
  final bool isLoading;
  final Function(BuildContext) onSelectDate;
  final VoidCallback onSave;

  const PerfilForm({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.ciController,
    required this.nombreController,
    required this.segundoNombreController,
    required this.apellidoPaternoController,
    required this.apellidoMaternoController,
    required this.telefonoController,
    required this.fechaNacimientoController,
    required this.dateMaskFormatter,
    required this.isLoading,
    required this.onSelectDate,
    required this.onSave,
  });

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildImmutableField(String label, TextEditingController controller, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 22),
          suffixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade300, size: 18),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sección de Datos Fijos
          _buildSectionTitle('Información de Cuenta'),
          _buildImmutableField('Correo Electrónico', emailController, Icons.email_rounded),
          _buildImmutableField('Cédula de Identidad', ciController, Icons.badge_rounded),
          const SizedBox(height: 24),

          // Sección de Datos Editables
          _buildSectionTitle('Información Personal'),
          TextFormField(
            controller: nombreController,
            decoration: const InputDecoration(
                labelText: 'Primer Nombre *', prefixIcon: Icon(Icons.person_outline_rounded)),
            validator: (v) => v == null || v.isEmpty ? 'Este campo es requerido' : null,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: segundoNombreController,
            decoration: const InputDecoration(
                labelText: 'Segundo Nombre', prefixIcon: Icon(Icons.person_outline_rounded)),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: apellidoPaternoController,
                  decoration: const InputDecoration(
                      labelText: 'Ap. Paterno', prefixIcon: Icon(Icons.person_outline_rounded)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: apellidoMaternoController,
                  decoration: const InputDecoration(
                      labelText: 'Ap. Materno', prefixIcon: Icon(Icons.person_outline_rounded)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: telefonoController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Teléfono de Contacto', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: fechaNacimientoController,
            keyboardType: TextInputType.number,
            inputFormatters: [dateMaskFormatter],
            onTap: () {
              if (fechaNacimientoController.text.isEmpty) {
                onSelectDate(context);
              }
            },
            decoration: InputDecoration(
              labelText: 'Fecha de Nacimiento',
              hintText: 'YYYY-MM-DD',
              prefixIcon: const Icon(Icons.calendar_today_rounded),
              suffixIcon: IconButton(
                icon: const Icon(Icons.edit_calendar_rounded, size: 20),
                onPressed: () => onSelectDate(context),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              if (v.length < 10) return 'Formato incompleto (YYYY-MM-DD)';
              try {
                DateTime.parse(v);
                return null;
              } catch (_) {
                return 'Fecha inválida';
              }
            },
          ),
          const SizedBox(height: 40),

          // Botón Guardar
          SizedBox(
            height: 56,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'ACTUALIZAR PERFIL',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}