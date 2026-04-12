import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_cliente/features/auth/providers/auth_provider.dart';
import 'package:app_cliente/features/home/screens/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ciController = TextEditingController();
  final _telefonoController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ciController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  void _onRegister() async {
    final nombre = _nombreController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final ci = _ciController.text.trim();
    final telefono = _telefonoController.text.trim();

    if (nombre.isEmpty || email.isEmpty || password.isEmpty || ci.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa los campos obligatorios')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.registro(
      nombre: nombre,
      email: email,
      password: password,
      ci: ci,
      telefono: telefono.isNotEmpty ? telefono : null,
    );

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro exitoso. Inicia sesión.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Vuelve al login
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
        titleTextStyle: TextStyle(
          color: Theme.of(context).textTheme.headlineMedium?.color,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
               Text(
                'Crea una cuenta nueva',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Completa tus datos para registrarte.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre (1er nombre de preferencia)*',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _ciController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cédula de Identidad (CI) *',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono *',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico *',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña *',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 32),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _onRegister,
                      child: const Text('REGISTRARSE'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
