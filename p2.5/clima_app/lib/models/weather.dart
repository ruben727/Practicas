/// Modelo que representa los datos del clima
class Weather {
  final String city;
  final double temperature;
  final String condition;
  final String unit; // 'C' para Celsius, 'F' para Fahrenheit

  // Constructor constante
  const Weather({
    required this.city,
    required this.temperature,
    required this.condition,
    this.unit = 'C',
  });

  // Método para crear una copia con datos actualizados
  Weather copyWith({
    String? city,
    double? temperature,
    String? condition,
    String? unit,
  }) {
    return Weather(
      city: city ?? this.city,
      temperature: temperature ?? this.temperature,
      condition: condition ?? this.condition,
      unit: unit ?? this.unit,
    );
  }

  // Validar si los datos son correctos
  bool get isValid {
    if (city.trim().isEmpty) return false;
    if (temperature < -60 || temperature > 60) return false;
    if (condition.trim().isEmpty) return false;
    return true;
  }

  @override
  String toString() {
    return 'Weather(city: $city, temp: $temperature°$unit, condition: $condition)';
  }
}