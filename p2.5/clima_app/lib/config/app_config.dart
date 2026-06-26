import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiKey => dotenv.env['OPENWEATHER_API_KEY'] ?? '';
  static String get baseUrl => dotenv.env['OPENWEATHER_BASE_URL'] ?? '';
  static bool isConfigured() => apiKey.isNotEmpty && baseUrl.isNotEmpty;
}
