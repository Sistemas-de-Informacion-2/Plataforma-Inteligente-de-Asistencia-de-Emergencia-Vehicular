class Vehiculo {
  final int id;
  final String marca;
  final String modelo;
  final int anio;
  final String placa;

  Vehiculo({
    required this.id,
    required this.marca,
    required this.modelo,
    required this.anio,
    required this.placa,
  });

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    return Vehiculo(
      id: json['id'],
      marca: json['marca'],
      modelo: json['modelo'],
      anio: json['anio'],
      placa: json['placa'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'placa': placa,
    };
  }
}
