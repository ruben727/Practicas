class Weather {
  final String city;
  final int temperature;
  final String condition;
  final String description;
  final int humidity;
  final double windSpeed;

  const Weather({
    required this.city,
    required this.temperature,
    required this.condition,
    required this.description,
    required this.humidity,
    required this.windSpeed,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('main') || !json.containsKey('weather')) {
      throw const FormatException('Faltan campos requeridos en la respuesta');
    }
    final weatherList = json['weather'] as List;
    if (weatherList.isEmpty) {
      throw const FormatException('Lista de condiciones vacía');
    }
    final main = json['main'] as Map<String, dynamic>;
    if (main['temp'] is! num) {
      throw const FormatException('Valor de temperatura inválido');
    }
    return Weather(
      city: json['name'] as String? ?? 'Desconocida',
      temperature: (main['temp'] as num).round(),
      condition: (weatherList[0] as Map)['main'] as String? ?? '',
      description: (weatherList[0] as Map)['description'] as String? ?? '',
      humidity: (main['humidity'] as num?)?.toInt() ?? 0,
      windSpeed: (json['wind']?['speed'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() =>
      'Weather(city: $city, temp: $temperature°C, condition: $condition, '
      'description: $description, humidity: $humidity%, wind: ${windSpeed}m/s)';
}
