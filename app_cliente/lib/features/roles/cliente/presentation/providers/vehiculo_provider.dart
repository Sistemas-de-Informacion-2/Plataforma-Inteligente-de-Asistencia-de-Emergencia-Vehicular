import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../../core/network/api_client.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/vehiculo.dart';

class VehiculoProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  List<Vehiculo> vehiculos = [];
  bool isLoading = false;
  String errorMessage = '';

  VehiculoProvider() {
    _loadCache();
    fetchVehiculos();
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = prefs.getString('vehiculos_cache');
      if (cache != null) {
        final decoded = jsonDecode(cache);
        if (decoded is List) {
          vehiculos = decoded.map((item) => Vehiculo.fromJson(Map<String, dynamic>.from(item))).toList();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error loading vehicles cache: $e');
    }
  }

  Future<void> fetchVehiculos() async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      final response = await _apiClient.instance.get('/vehiculos/');
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('vehiculos_cache', jsonEncode(response.data));

        vehiculos = (response.data as List)
            .map((item) => Vehiculo.fromJson(item))
            .toList();
      }
    } on DioException catch (e) {
      errorMessage = 'Error al cargar vehículos: ${e.message}';
    } catch (e) {
      errorMessage = 'Error inesperado';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addVehiculo({
    required String marca,
    required String modelo,
    required int anio,
    required String placa,
  }) async {
    try {
      final response = await _apiClient.instance.post(
        '/vehiculos/',
        data: {
          'marca': marca,
          'modelo': modelo,
          'anio': anio,
          'placa': placa,
        },
      );

      if (response.statusCode == 201) {
        // En lugar de hacer refetch completo, podemos optimizar agregando a la lista local
        vehiculos.add(Vehiculo.fromJson(response.data));
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      errorMessage = 'Error al añadir vehículo: ${e.message}';
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error inesperado';
      notifyListeners();
    }
    return false;
  }

  Future<bool> updateVehiculo(int id, {
    String? marca,
    String? modelo,
    int? anio,
    String? placa,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (marca != null) data['marca'] = marca;
      if (modelo != null) data['modelo'] = modelo;
      if (anio != null) data['anio'] = anio;
      if (placa != null) data['placa'] = placa;

      final response = await _apiClient.instance.patch(
        '/vehiculos/$id',
        data: data,
      );

      if (response.statusCode == 200) {
        final index = vehiculos.indexWhere((v) => v.id == id);
        if (index != -1) {
          vehiculos[index] = Vehiculo.fromJson(response.data);
          notifyListeners();
        }
        return true;
      }
    } on DioException catch (e) {
      errorMessage = 'Error al actualizar vehículo: ${e.message}';
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error inesperado';
      notifyListeners();
    }
    return false;
  }

  Future<bool> deleteVehiculo(int id) async {
    try {
      final response = await _apiClient.instance.delete('/vehiculos/$id');
      
      if (response.statusCode == 204) {
        vehiculos.removeWhere((v) => v.id == id);
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      errorMessage = 'Error al eliminar vehículo: ${e.message}';
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error inesperado';
      notifyListeners();
    }
    return false;
  }
}
