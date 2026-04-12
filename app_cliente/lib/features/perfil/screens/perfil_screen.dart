import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_cliente/features/perfil/providers/perfil_provider.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _ciController = TextEditingController();
  
  final _nombreController = TextEditingController();
  final _segundoNombreController = TextEditingController();
  final _apellidoPaternoController = TextEditingController();
  final _apellidoMaternoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _fechaNacimientoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final provider = context.read<PerfilProvider>();
    final perfil = provider.perfil;
    if (perfil != null) {
      _emailController.text = perfil.email;
      _ciController.text = perfil.ci;

      _nombreController.text = perfil.nombre;
      _segundoNombreController.text = perfil.segundoNombre ?? '';
      _apellidoPaternoController.text = perfil.apellidoPaterno ?? '';
      _apellidoMaternoController.text = perfil.apellidoMaterno ?? '';
      _telefonoController.text = perfil.telefono ?? '';
      _fechaNacimientoController.text = perfil.fechaNacimiento ?? '';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _ciController.dispose();
    _nombreController.dispose();
    _segundoNombreController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
    _telefonoController.dispose();
    _fechaNacimientoController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final success = await context.read<PerfilProvider>().updatePerfil(
        nombre: _nombreController.text.trim(),
        segundoNombre: _segundoNombreController.text.trim(),
        apellidoPaterno: _apellidoPaternoController.text.trim(),
        apellidoMaterno: _apellidoMaternoController.text.trim(),
        telefono: _telefonoController.text.trim(),
        fechaNacimiento: _fechaNacimientoController.text.trim(), // Formato "YYYY-MM-DD" esperado
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil actualizado correctamente'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.read<PerfilProvider>().errorMessage),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Widget _buildImmutableField(String label, TextEditingController controller, IconData icon) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: TextStyle(color: Colors.grey.shade600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
        filled: true,
        fillColor: Colors.grey.shade100,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PerfilProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
      ),
      body: provider.isLoading && provider.perfil == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            backgroundImage: provider.perfil?.fotoPerfil != null 
                              ? NetworkImage(provider.perfil!.fotoPerfil!) 
                              : null,
                            child: provider.perfil?.fotoPerfil == null 
                              ? Icon(Icons.person, size: 50, color: Theme.of(context).primaryColor)
                              : null,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text('Datos Fijos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),
                    _buildImmutableField('Correo Electrónico', _emailController, Icons.email_outlined),
                    const SizedBox(height: 16),
                    _buildImmutableField('Cédula de Identidad', _ciController, Icons.badge_outlined),
                    
                    const SizedBox(height: 32),
                    const Text('Datos Editables', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(labelText: 'Primer Nombre *', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _segundoNombreController,
                      decoration: const InputDecoration(labelText: 'Segundo Nombre', prefixIcon: Icon(Icons.person_outline)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _apellidoPaternoController,
                      decoration: const InputDecoration(labelText: 'Apellido Paterno', prefixIcon: Icon(Icons.group_outlined)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _apellidoMaternoController,
                      decoration: const InputDecoration(labelText: 'Apellido Materno', prefixIcon: Icon(Icons.group_outlined)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telefonoController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone_outlined)),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fechaNacimientoController,
                      decoration: const InputDecoration(
                        labelText: 'Fecha de Nacimiento (YYYY-MM-DD)', 
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                    ),

                    const SizedBox(height: 32),
                    provider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _saveProfile,
                            child: const Text('GUARDAR CAMBIOS'),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
