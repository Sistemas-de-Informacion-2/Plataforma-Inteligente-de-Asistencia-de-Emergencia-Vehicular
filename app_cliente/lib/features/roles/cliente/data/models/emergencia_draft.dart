import 'dart:convert';

class EmergenciaDraft {
  String? problemaDescripcion;
  int? vehiculoId;
  List<String> fotosPaths;
  String? audioPath;
  DateTime? lastUpdated;

  EmergenciaDraft({
    this.problemaDescripcion,
    this.vehiculoId,
    this.fotosPaths = const [],
    this.audioPath,
    this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'problemaDescripcion': problemaDescripcion,
      'vehiculoId': vehiculoId,
      'fotosPaths': fotosPaths,
      'audioPath': audioPath,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  factory EmergenciaDraft.fromJson(Map<String, dynamic> json) {
    return EmergenciaDraft(
      problemaDescripcion: json['problemaDescripcion'],
      vehiculoId: json['vehiculoId'],
      fotosPaths: List<String>.from(json['fotosPaths'] ?? []),
      audioPath: json['audioPath'],
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated']) : null,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory EmergenciaDraft.fromJsonString(String str) => EmergenciaDraft.fromJson(jsonDecode(str));
}
