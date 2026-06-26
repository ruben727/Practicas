import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/weather_model.dart';

class WeatherService {
  static const _timeout = Duration(seconds: 10);

  Future<Weather> getWeather(String city) async {
    if (city.trim().isEmpty) {
      throw ArgumentError('El nombre de la ciudad no puede estar vacío');
    }
    final sanitized =
        city.replaceAll(RegExp(r'[^a-zA-ZáéíóúÁÉÍÓÚüÜñÑ0-9 ]'), '').trim();
    if (!AppConfig.isConfigured()) {
      throw StateError('API no configurada. Verifica tu archivo .env');
    }
    final uri = Uri.parse(AppConfig.baseUrl).replace(queryParameters: {
      'q': sanitized,
      'appid': AppConfig.apiKey,
      'units': 'metric',
      'lang': 'es',
    });
    try {
      final response = await http.get(uri).timeout(_timeout);
      switch (response.statusCode) {
        case 200:
          return Weather.fromJson(
              jsonDecode(response.body) as Map<String, dynamic>);
        case 401:
          throw Exception('API key inválida o no autorizada');
        case 404:
          throw Exception('Ciudad "$sanitized" no encontrada');
        case 429:
          throw Exception('Límite de solicitudes excedido. Intenta más tarde');
        default:
          throw Exception('Error del servidor: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('Sin conexión a internet');
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado. Verifica tu conexión');
    } on FormatException {
      throw Exception('Error al procesar la respuesta del servidor');
    }
  }

  Future<List<Weather>> getWeatherForCities(List<String> cities) {
    return Future.wait(cities.map(getWeather));
  }
}
