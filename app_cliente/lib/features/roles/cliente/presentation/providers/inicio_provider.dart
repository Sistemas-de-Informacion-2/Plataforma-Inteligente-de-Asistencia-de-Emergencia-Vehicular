// src/features/roles/cliente/presentation/providers/inicio_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/vehiculo.dart';
import '../../data/models/emergencia_draft.dart';

class InicioProvider extends ChangeNotifier {
  final TextEditingController descripcionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  late final AudioRecorder _audioRecorder;
  late final AudioPlayer _audioPlayer;

  // Estados
  List<File> imagenesSeleccionadas = [];
  Vehiculo? vehiculoSeleccionado;
  LatLng? userLocation;

  File? recordedAudio;
  bool isRecording = false;
  bool isPlayingAudio = false;

  // SharedPreferences
  SharedPreferences? _prefs;
  static const String _draftKey = 'emergencia_draft';

  InicioProvider() {
    _audioRecorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    
    // Escuchar cuando el audio termina de reproducirse
    _audioPlayer.onPlayerComplete.listen((event) {
      isPlayingAudio = false;
      notifyListeners();
    });

    // Escuchar cambios en el texto para actualizar el botón de envío
    descripcionController.addListener(() {
      _saveDraft();
      notifyListeners();
    });
    
    determinePosition();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    _prefs = await SharedPreferences.getInstance();
    final draftStr = _prefs?.getString(_draftKey);
    if (draftStr != null) {
      try {
        final draft = EmergenciaDraft.fromJsonString(draftStr);
        descripcionController.text = draft.problemaDescripcion ?? '';
        
        // Restore photos
        for (var path in draft.fotosPaths) {
          final file = File(path);
          if (await file.exists()) {
            imagenesSeleccionadas.add(file);
          }
        }
        
        // Restore audio
        if (draft.audioPath != null) {
          final audioFile = File(draft.audioPath!);
          if (await audioFile.exists()) {
            recordedAudio = audioFile;
          }
        }
        
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading draft: $e');
      }
    }
  }

  Future<void> _saveDraft() async {
    if (_prefs == null) return;
    if (!hasContent && vehiculoSeleccionado == null) {
      await clearDraft();
      return;
    }
    
    final draft = EmergenciaDraft(
      problemaDescripcion: descripcionController.text,
      vehiculoId: vehiculoSeleccionado?.id,
      fotosPaths: imagenesSeleccionadas.map((f) => f.path).toList(),
      audioPath: recordedAudio?.path,
      lastUpdated: DateTime.now(),
    );
    await _prefs?.setString(_draftKey, draft.toJsonString());
  }

  Future<void> clearDraft() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.remove(_draftKey);
  }

  @override
  void dispose() {
    descripcionController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  bool get hasContent => 
      descripcionController.text.trim().isNotEmpty ||
      imagenesSeleccionadas.isNotEmpty || 
      recordedAudio != null;

  void setVehiculo(Vehiculo? vehiculo) {
    vehiculoSeleccionado = vehiculo;
    _saveDraft();
    notifyListeners();
  }

  // ── Location ────────────────────────────────────────────────
  Future<bool> determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    
    try {
      // Intenta obtener la última posición conocida primero para no bloquear el mapa
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        userLocation = LatLng(lastPos.latitude, lastPos.longitude);
        notifyListeners();
      }

      // Configuración de los ajustes de ubicación
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high, // Aquí defines la precisión
        distanceFilter: 10,
      );

      final position = await Geolocator.getCurrentPosition(locationSettings: locationSettings);
      userLocation = LatLng(position.latitude, position.longitude);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Media ────────────────────────────────────────────────────
  Future<void> pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      final tempDir = await getApplicationDocumentsDirectory();
      for (var x in images) {
        final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${x.name}';
        final savedImage = await File(x.path).copy('${tempDir.path}/$uniqueName');
        imagenesSeleccionadas.add(savedImage);
      }
      _saveDraft();
      notifyListeners();
    }
  }

  Future<void> pickFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final tempDir = await getApplicationDocumentsDirectory();
      final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final savedImage = await File(image.path).copy('${tempDir.path}/$uniqueName');
      imagenesSeleccionadas.add(savedImage);
      _saveDraft();
      notifyListeners();
    }
  }

  void removeImage(int index) {
    imagenesSeleccionadas.removeAt(index);
    _saveDraft();
    notifyListeners();
  }

  // ── Audio Recording & Playback ──────────────────────────────
  Future<String?> iniciarGrabacion() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getApplicationDocumentsDirectory();
        final path = '${tempDir.path}${Platform.pathSeparator}audio_sos_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        
        isRecording = true;
        recordedAudio = null;
        notifyListeners();
        return null; // Sin error
      } else {
        return 'Permiso de micrófono denegado';
      }
    } catch (e) {
      debugPrint("Error al grabar: $e");
      return 'Error al iniciar grabación';
    }
  }

  Future<void> detenerGrabacion() async {
    try {
      final path = await _audioRecorder.stop();
      isRecording = false;
      if (path != null) {
        String cleanPath = path;
        // Dependiendo de la plataforma, record puede retornar un URI con file://
        if (cleanPath.startsWith('file://')) {
          cleanPath = Uri.parse(cleanPath).toFilePath();
        }
        recordedAudio = File(cleanPath);
      }
      _saveDraft();
      notifyListeners();
    } catch (e) {
      debugPrint("Error al detener grabación: $e");
    }
  }

  Future<void> toggleAudioPlayback() async {
    if (isPlayingAudio) {
      await _audioPlayer.stop();
      isPlayingAudio = false;
    } else if (recordedAudio != null) {
      await _audioPlayer.play(DeviceFileSource(recordedAudio!.path));
      isPlayingAudio = true;
    }
    notifyListeners();
  }

  void removeAudio() {
    recordedAudio = null;
    _saveDraft();
    notifyListeners();
  }

  Future<void> validarAudioExistente() async {
    if (recordedAudio != null && !(await recordedAudio!.exists())) {
      recordedAudio = null;
      notifyListeners();
    }
  }

  void limpiarFormulario() {
    descripcionController.clear();
    imagenesSeleccionadas.clear();
    recordedAudio = null;
    clearDraft();
    notifyListeners();
  }
}
