import 'package:flutter/material.dart';

/// FUNCIONES PURAS
/// No dependen del estado, solo de sus parámetros
/// Son fáciles de probar y reutilizar

/// Formatea la temperatura según la unidad
/// Parámetros:
///   - temperature: valor numérico de la temperatura
///   - unit: 'C' para Celsius, 'F' para Fahrenheit
/// Retorna: String formateado ej. "24°C" o "75°F"
String formatTemperature(double temperature, String unit) {
  // Redondear a entero para mostrar
  final roundedTemp = temperature.toStringAsFixed(0);
  return '$roundedTemp°$unit';
}

/// Retorna el ícono correspondiente a la condición del clima
/// Parámetro:
///   - condition: string con la condición ('sunny', 'cloudy', 'rainy', etc.)
/// Retorna: IconData para usar en Icon widget
IconData getWeatherIcon(String condition) {
  switch (condition.toLowerCase()) {
    case 'sunny':
      return Icons.wb_sunny;
    case 'cloudy':
      return Icons.cloud;
    case 'rainy':
      return Icons.umbrella;
    case 'stormy':
      return Icons.flash_on;
    case 'snowy':
      return Icons.ac_unit;
    case 'foggy':
      return Icons.foggy;
    default:
      return Icons.cloud_queue;
  }
}

/// Obtiene el color según la temperatura
/// Útil para efectos visuales
Color getTemperatureColor(double temperature) {
  if (temperature > 30) return Colors.red;
  if (temperature > 20) return Colors.orange;
  if (temperature > 10) return Colors.blue;
  return Colors.cyan;
}

/// Obtiene un mensaje sugerente según la temperatura
String getTemperatureMessage(double temperature) {
  if (temperature > 30) return '🔥 ¡Mucho calor! Hidrátate';
  if (temperature > 20) return '🌤️ Clima agradable';
  if (temperature > 10) return '🧥 Un poco fresco';
  return '❄️ Hace frío, abrígate';
}

/// Valida que una temperatura sea correcta
bool isValidTemperature(double temperature) {
  return temperature >= -60 && temperature <= 60;
}

/// Valida que una ciudad sea correcta
bool isValidCity(String city) {
  return city.trim().isNotEmpty && city.length >= 2;
}