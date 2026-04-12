class Perfil {
  final int id;
  final String nombre;
  final String email;
  final String ci;
  final String? telefono;

  // Campos de UsuarioPerfil
  final String? segundoNombre;
  final String? apellidoPaterno;
  final String? apellidoMaterno;
  final String? fotoPerfil;
  final String? fechaNacimiento;

  Perfil({
    required this.id,
    required this.nombre,
    required this.email,
    required this.ci,
    this.telefono,
    this.segundoNombre,
    this.apellidoPaterno,
    this.apellidoMaterno,
    this.fotoPerfil,
    this.fechaNacimiento,
  });

  factory Perfil.fromJson(Map<String, dynamic> json) {
    // Si viene con el objeto 'perfil' embebido (UsuarioOut => perfil: UsuarioPerfilOut)
    final perfilJson = json['perfil'] as Map<String, dynamic>? ?? {};

    return Perfil(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      email: json['email'] ?? '',
      ci: json['ci'] ?? '',
      telefono: json['telefono'],
      segundoNombre: perfilJson['segundo_nombre'],
      apellidoPaterno: perfilJson['apellido_paterno'],
      apellidoMaterno: perfilJson['apellido_materno'],
      fotoPerfil: perfilJson['foto_perfil'],
      fechaNacimiento: perfilJson['fecha_nacimiento'],
    );
  }
}
