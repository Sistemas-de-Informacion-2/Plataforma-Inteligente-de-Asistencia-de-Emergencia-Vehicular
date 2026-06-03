import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart' as provider;
import 'package:image_picker/image_picker.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../shared/presentation/providers/perfil_provider.dart';

// ── Screen ───────────────────────────────────────────────────────────────────
class MechanicProfileScreen extends StatefulWidget {
  const MechanicProfileScreen({super.key});

  @override
  State<MechanicProfileScreen> createState() => _MechanicProfileScreenState();
}

class _MechanicProfileScreenState extends State<MechanicProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _segundoNombreCtrl;
  late final TextEditingController _apellidoPaternoCtrl;
  late final TextEditingController _apellidoMaternoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _fechaNacimientoCtrl;

  // Animación de entrada del formulario
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _isInit = false;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController();
    _segundoNombreCtrl = TextEditingController();
    _apellidoPaternoCtrl = TextEditingController();
    _apellidoMaternoCtrl = TextEditingController();
    _telefonoCtrl = TextEditingController();
    _fechaNacimientoCtrl = TextEditingController();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final perfil = provider.Provider.of<PerfilProvider>(
        context,
        listen: false,
      ).perfil;
      _nombreCtrl.text = perfil?.nombre ?? '';
      _segundoNombreCtrl.text = perfil?.segundoNombre ?? '';
      _apellidoPaternoCtrl.text = perfil?.apellidoPaterno ?? '';
      _apellidoMaternoCtrl.text = perfil?.apellidoMaterno ?? '';
      _telefonoCtrl.text = perfil?.telefono ?? '';
      _fechaNacimientoCtrl.text = perfil?.fechaNacimiento ?? '';
      _isInit = true;
      // Lanzar animación después del primer frame
      WidgetsBinding.instance.addPostFrameCallback((_) => _animCtrl.forward());
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _segundoNombreCtrl.dispose();
    _apellidoPaternoCtrl.dispose();
    _apellidoMaternoCtrl.dispose();
    _telefonoCtrl.dispose();
    _fechaNacimientoCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Acciones ────────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // pickImage ya corre en isolate interno → no bloquea UI
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85, // compresión para no cargar imágenes pesadas
      maxWidth: 800,
    );
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(CupertinoIcons.photo, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Foto seleccionada correctamente'),
            ],
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    DateTime? initialDate;
    if (_fechaNacimientoCtrl.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_fechaNacimientoCtrl.text);
      } catch (_) {}
    }

    final DateTime lastDate = DateTime.now().subtract(
      const Duration(days: 365 * 18),
    );

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? lastDate,
      firstDate: DateTime(1920),
      lastDate: lastDate,
      helpText: 'SELECCIONA TU FECHA DE NACIMIENTO',
      cancelText: 'CANCELAR',
      confirmText: 'ACEPTAR',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primaryColor,
            onPrimary: Colors.white,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _fechaNacimientoCtrl.text =
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final perfilProv = provider.Provider.of<PerfilProvider>(
      context,
      listen: false,
    );

    final success = await perfilProv.updatePerfil(
      nombre: _nombreCtrl.text,
      segundoNombre:
          _segundoNombreCtrl.text.isEmpty ? null : _segundoNombreCtrl.text,
      apellidoPaterno: _apellidoPaternoCtrl.text.isEmpty
          ? null
          : _apellidoPaternoCtrl.text,
      apellidoMaterno: _apellidoMaternoCtrl.text.isEmpty
          ? null
          : _apellidoMaternoCtrl.text,
      telefono:
          _telefonoCtrl.text.isEmpty ? null : _telefonoCtrl.text,
      fechaNacimiento: _fechaNacimientoCtrl.text.isEmpty
          ? null
          : _fechaNacimientoCtrl.text,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? CupertinoIcons.checkmark_circle : CupertinoIcons.xmark_circle,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              success
                  ? 'Perfil actualizado exitosamente'
                  : perfilProv.errorMessage,
            ),
          ],
        ),
        backgroundColor: success ? AppTheme.success : AppTheme.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final perfilProv = provider.Provider.of<PerfilProvider>(context);
    final perfil = perfilProv.perfil;
    final isLoading = perfilProv.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _ProfileSliverAppBar(
            perfil: perfil,
            imageFile: _imageFile,
            onPickImage: _pickImage,
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('Información de cuenta'),
                        const SizedBox(height: 8),
                        _ReadOnlyCard(perfil: perfil),
                        const SizedBox(height: 24),
                        const _SectionLabel('Datos personales'),
                        const SizedBox(height: 8),
                        _EditableCard(
                          nombreCtrl: _nombreCtrl,
                          segundoNombreCtrl: _segundoNombreCtrl,
                          apellidoPaternoCtrl: _apellidoPaternoCtrl,
                          apellidoMaternoCtrl: _apellidoMaternoCtrl,
                          telefonoCtrl: _telefonoCtrl,
                          fechaNacimientoCtrl: _fechaNacimientoCtrl,
                          onSelectDate: _selectDate,
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _SaveFab(isLoading: isLoading, onSave: _saveChanges),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ── Sliver App Bar ────────────────────────────────────────────────────────────

class _ProfileSliverAppBar extends StatelessWidget {
  final dynamic perfil;
  final File? imageFile;
  final VoidCallback onPickImage;

  const _ProfileSliverAppBar({
    required this.perfil,
    required this.imageFile,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final fotoUrl = perfil?.fotoPerfil as String?;
    final nombreCompleto =
        '${perfil?.nombre ?? ''} ${perfil?.apellidoPaterno ?? ''}'.trim();

    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      stretch: true,
      iconTheme: const IconThemeData(color: Colors.white),
      backgroundColor: AppTheme.inkDark,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.inkDark, AppTheme.secondaryColor],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    // Hero para transición suave si navegás desde otra pantalla
                    Hero(
                      tag: 'mechanic-avatar',
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.white24,
                        backgroundImage: imageFile != null
                            ? FileImage(imageFile!) as ImageProvider
                            : (fotoUrl != null
                                ? NetworkImage(fotoUrl)
                                : null),
                        child: imageFile == null && fotoUrl == null
                            ? const Icon(
                                CupertinoIcons.person_alt,
                                size: 50,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    GestureDetector(
                      onTap: onPickImage,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          CupertinoIcons.camera_fill,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  nombreCompleto.isEmpty ? 'Cargando...' : nombreCompleto,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Perfil Profesional',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
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

// ── Save FAB ─────────────────────────────────────────────────────────────────

class _SaveFab extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onSave;

  const _SaveFab({required this.isLoading, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: FloatingActionButton.extended(
        key: ValueKey(isLoading),
        onPressed: isLoading ? null : onSave,
        backgroundColor: isLoading
            ? AppTheme.primaryColor.withValues(alpha: 0.7)
            : AppTheme.primaryColor,
        elevation: 4,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(CupertinoIcons.checkmark_alt, color: Colors.white),
        label: Text(
          isLoading ? 'Guardando...' : 'Guardar cambios',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Read Only Card ────────────────────────────────────────────────────────────

class _ReadOnlyCard extends StatelessWidget {
  final dynamic perfil;

  const _ReadOnlyCard({required this.perfil});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _ReadOnlyRow(
            icon: CupertinoIcons.mail_solid,
            iconColor: AppTheme.primaryColor,
            label: 'Correo electrónico',
            value: perfil?.email ?? '-',
          ),
          Divider(
            height: 1,
            indent: 56,
            color: AppTheme.textSecondary.withValues(alpha: 0.1),
          ),
          _ReadOnlyRow(
            icon: CupertinoIcons.doc_text_fill,
            iconColor: AppTheme.warning,
            label: 'Carnet de identidad',
            value: perfil?.ci ?? '-',
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _ReadOnlyRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.lock_fill,
            color: AppTheme.textSecondary.withValues(alpha: 0.3),
            size: 14,
          ),
        ],
      ),
    );
  }
}

// ── Editable Card ─────────────────────────────────────────────────────────────

class _EditableCard extends StatelessWidget {
  final TextEditingController nombreCtrl;
  final TextEditingController segundoNombreCtrl;
  final TextEditingController apellidoPaternoCtrl;
  final TextEditingController apellidoMaternoCtrl;
  final TextEditingController telefonoCtrl;
  final TextEditingController fechaNacimientoCtrl;
  final VoidCallback onSelectDate;

  const _EditableCard({
    required this.nombreCtrl,
    required this.segundoNombreCtrl,
    required this.apellidoPaternoCtrl,
    required this.apellidoMaternoCtrl,
    required this.telefonoCtrl,
    required this.fechaNacimientoCtrl,
    required this.onSelectDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _ProfileTextField(
            controller: nombreCtrl,
            label: 'Nombres',
            icon: CupertinoIcons.person_fill,
            iconColor: AppTheme.primaryColor,
            validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          _ProfileTextField(
            controller: segundoNombreCtrl,
            label: 'Segundo nombre',
            hint: 'Opcional',
            icon: CupertinoIcons.person,
            iconColor: AppTheme.primaryColor,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          _ProfileTextField(
            controller: apellidoPaternoCtrl,
            label: 'Apellido paterno',
            icon: CupertinoIcons.person_crop_square_fill,
            iconColor: AppTheme.secondaryColor,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          _ProfileTextField(
            controller: apellidoMaternoCtrl,
            label: 'Apellido materno',
            icon: CupertinoIcons.person_crop_square,
            iconColor: AppTheme.secondaryColor,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 14),
          _ProfileTextField(
            controller: telefonoCtrl,
            label: 'Teléfono',
            icon: CupertinoIcons.phone_fill,
            iconColor: AppTheme.success,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 14),
          _ProfileTextField(
            controller: fechaNacimientoCtrl,
            label: 'Fecha de nacimiento',
            icon: CupertinoIcons.calendar_today,
            iconColor: AppTheme.warning,
            readOnly: true,
            onTap: onSelectDate,
          ),
        ],
      ),
    );
  }
}

// ── Profile TextField ─────────────────────────────────────────────────────────

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final Color iconColor;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextCapitalization textCapitalization;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.iconColor,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.readOnly = false,
    this.onTap,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: AppTheme.textSecondary.withValues(alpha: 0.5),
          fontSize: 13,
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        filled: true,
        fillColor: AppTheme.backgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.textSecondary.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        suffixIcon: readOnly
            ? Icon(
                CupertinoIcons.chevron_down,
                size: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              )
            : null,
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}