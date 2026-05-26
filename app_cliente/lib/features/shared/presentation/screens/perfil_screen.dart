import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../providers/perfil_provider.dart';
import '../../../../core/theme/app_theme.dart';

// Widgets del perfil
import '../widgets/perfil_header.dart';
import '../widgets/perfil_form.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _dateMaskFormatter = MaskTextInputFormatter(
    mask: '####-##-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  final _emailController = TextEditingController();
  final _ciController = TextEditingController();
  
  final _nombreController = TextEditingController();
  final _segundoNombreController = TextEditingController();
  final _apellidoPaternoController = TextEditingController();
  final _apellidoMaternoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _fechaNacimientoController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Cargar datos actuales del provider si existen
    _loadData();
    
    // Obtener los datos más recientes del servidor en segundo plano
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PerfilProvider>().fetchPerfil().then((_) {
          if (mounted) {
            _loadData();
          }
        });
      }
    });

    _animationController.forward();
  }

  void _loadData() {
    final provider = context.read<PerfilProvider>();
    final perfil = provider.perfil;
    
    if (perfil != null) {
      if (_emailController.text != perfil.email) _emailController.text = perfil.email;
      if (_ciController.text != perfil.ci) _ciController.text = perfil.ci;
      if (_nombreController.text != perfil.nombre) _nombreController.text = perfil.nombre;
      
      final segNombre = perfil.segundoNombre ?? '';
      if (_segundoNombreController.text != segNombre) _segundoNombreController.text = segNombre;
      
      final apPat = perfil.apellidoPaterno ?? '';
      if (_apellidoPaternoController.text != apPat) _apellidoPaternoController.text = apPat;
      
      final apMat = perfil.apellidoMaterno ?? '';
      if (_apellidoMaternoController.text != apMat) _apellidoMaternoController.text = apMat;
      
      final tel = perfil.telefono ?? '';
      if (_telefonoController.text != tel) _telefonoController.text = tel;
      
      final fechaNac = perfil.fechaNacimiento ?? '';
      if (_fechaNacimientoController.text != fechaNac) _fechaNacimientoController.text = fechaNac;
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
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now().subtract(const Duration(days: 365 * 18));
    if (_fechaNacimientoController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_fechaNacimientoController.text);
      } catch (_) {}
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaNacimientoController.text = picked.toString().split(' ')[0];
      });
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final success = await context.read<PerfilProvider>().updatePerfil(
        nombre: _nombreController.text.trim(),
        segundoNombre: _segundoNombreController.text.trim(),
        apellidoPaterno: _apellidoPaternoController.text.trim(),
        apellidoMaterno: _apellidoMaternoController.text.trim(),
        telefono: _telefonoController.text.trim(),
        fechaNacimiento: _fechaNacimientoController.text.trim(),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Perfil actualizado correctamente'),
                ],
              ),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.read<PerfilProvider>().errorMessage),
              backgroundColor: AppTheme.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PerfilProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        titleTextStyle: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: provider.isLoading && provider.perfil == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const PerfilHeader(), // <-- Cabecera visual
                      
                      PerfilForm(           // <-- Lógica del formulario
                        formKey: _formKey,
                        emailController: _emailController,
                        ciController: _ciController,
                        nombreController: _nombreController,
                        segundoNombreController: _segundoNombreController,
                        apellidoPaternoController: _apellidoPaternoController,
                        apellidoMaternoController: _apellidoMaternoController,
                        telefonoController: _telefonoController,
                        fechaNacimientoController: _fechaNacimientoController,
                        dateMaskFormatter: _dateMaskFormatter,
                        isLoading: provider.isLoading,
                        onSelectDate: _selectDate,
                        onSave: _saveProfile,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}