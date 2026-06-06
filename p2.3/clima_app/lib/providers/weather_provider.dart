import 'package:flutter/material.dart';
import '../models/weather.dart';

/// Provider que maneja el estado del clima
class WeatherProvider extends ChangeNotifier {
  // Estado inicial
  Weather _currentWeather = Weather(
    city: 'Santiago de Querétaro',
    temperature: 24.0,
    condition: 'cloudy',
    unit: 'C',
  );

  // Getter para acceder al estado desde la UI
  Weather get currentWeather => _currentWeather;

  // Getter para la temperatura formateada
  String get formattedTemperature {
    return '${_currentWeather.temperature.toStringAsFixed(0)}°${_currentWeather.unit}';
  }

  // Método para cambiar la ciudad con validación
  void changeCity(String newCity) {
    if (newCity.trim().isEmpty) {
      debugPrint('Error: La ciudad no puede estar vacía');
      return;
    }

    _currentWeather = _currentWeather.copyWith(city: newCity.trim());
    notifyListeners();
    debugPrint('Ciudad cambiada a: $newCity');
  }

  // Método para cambiar la temperatura con validación
  void changeTemperature(double newTemperature) {
    if (newTemperature < -60 || newTemperature > 60) {
      debugPrint('Error: Temperatura $newTemperature°C fuera de rango (-60 a 60)');
      return;
    }

    _currentWeather = _currentWeather.copyWith(temperature: newTemperature);
    notifyListeners();
    debugPrint('Temperatura cambiada a: ${newTemperature.toStringAsFixed(0)}°C');
  }

  // Método para cambiar la condición del clima
  void changeCondition(String newCondition) {
    if (newCondition.trim().isEmpty) {
      debugPrint('Error: La condición no puede estar vacía');
      return;
    }

    _currentWeather = _currentWeather.copyWith(condition: newCondition.toLowerCase());
    notifyListeners();
    debugPrint('Condición cambiada a: $newCondition');
  }

  // Método para cambiar entre Celsius y Fahrenheit
  void toggleUnit() {
    final newUnit = _currentWeather.unit == 'C' ? 'F' : 'C';
    double newTemperature = _currentWeather.temperature;
    
    if (newUnit == 'F') {
      // Celsius a Fahrenheit: (C × 9/5) + 32
      newTemperature = (_currentWeather.temperature * 9 / 5) + 32;
    } else {
      // Fahrenheit a Celsius: (F - 32) × 5/9
      newTemperature = (_currentWeather.temperature - 32) * 5 / 9;
    }

    _currentWeather = _currentWeather.copyWith(
      unit: newUnit,
      temperature: double.parse(newTemperature.toStringAsFixed(1)),
    );
    notifyListeners();
    debugPrint('Unidad cambiada a: $newUnit');
  }

  // Método para cargar datos de ejemplo
  void loadExampleData() {
    _currentWeather = Weather(
      city: 'Ciudad de México',
      temperature: 22.0,
      condition: 'sunny',
      unit: 'C',
    );
    notifyListeners();
  }

  // Método para resetear a valores por defecto
  void resetToDefault() {
    _currentWeather = Weather(
      city: 'Santiago de Querétaro',
      temperature: 24.0,
      condition: 'cloudy',
      unit: 'C',
    );
    notifyListeners();
  }
}