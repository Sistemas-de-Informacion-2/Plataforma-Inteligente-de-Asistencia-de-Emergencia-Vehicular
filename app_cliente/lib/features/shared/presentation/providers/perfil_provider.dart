import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/perfil.dart';

class PerfilProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  Perfil? perfil;
  bool isLoading = false;
  String errorMessage = '';

  PerfilProvider() {
    fetchPerfil();
  }

  Future<void> fetchPerfil() async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      final response = await _apiClient.instance.get('/usuarios/me');
      if (response.statusCode == 200) {
        perfil = Perfil.fromJson(response.data);
      }
    } on DioException catch (e) {
      errorMessage = 'Error al cargar perfil: ${e.message}';
    } catch (e) {
      errorMessage = 'Error inesperado';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePerfil({
    String? nombre,
    String? telefono,
    String? segundoNombre,
    String? apellidoPaterno,
    String? apellidoMaterno,
    String? fechaNacimiento,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> data = {};
      if (nombre != null && nombre.isNotEmpty) data['nombre'] = nombre;
      if (telefono != null) data['telefono'] = telefono;
      if (segundoNombre != null) data['segundo_nombre'] = segundoNombre;
      if (apellidoPaterno != null) data['apellido_paterno'] = apellidoPaterno;
      if (apellidoMaterno != null) data['apellido_materno'] = apellidoMaterno;
      if (fechaNacimiento != null && fechaNacimiento.isNotEmpty) data['fecha_nacimiento'] = fechaNacimiento;

      final response = await _apiClient.instance.patch(
        '/usuarios/me/perfil',
        data: data,
      );

      if (response.statusCode == 200) {
        perfil = Perfil.fromJson(response.data);
        isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      errorMessage = 'Error al actualizar perfil: ${e.message}';
    } catch (e) {
      errorMessage = 'Error inesperado';
    }
    
    isLoading = false;
    notifyListeners();
    return false;
  }
}
