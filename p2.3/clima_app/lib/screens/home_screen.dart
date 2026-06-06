import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/weather_provider.dart';
import '../utils/weather_utils.dart';
import '../widgets/weather_icon.dart';
import '../widgets/custom_button.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios en el provider
    // Cuando el estado cambie, este widget se reconstruye automáticamente
    final weatherProvider = Provider.of<WeatherProvider>(context);
    final weather = weatherProvider.currentWeather;
    
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clima Actual'),
        centerTitle: true,
        actions: [
          // Botón para cambiar unidades (Celsius/Fahrenheit)
          IconButton(
            icon: Icon(weather.unit == 'C' ? Icons.thermostat : Icons.thermostat_auto),
            onPressed: () {
              weatherProvider.toggleUnit();
            },
            tooltip: 'Cambiar a ${weather.unit == 'C' ? 'Fahrenheit' : 'Celsius'}',
          ),
          // Botón de reset
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              weatherProvider.resetToDefault();
            },
            tooltip: 'Resetear a valores por defecto',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: isLandscape
              ? _buildLandscapeLayout(context, weatherProvider, weather)
              : _buildPortraitLayout(context, weatherProvider, weather),
        ),
      ),
    );
  }

  // Layout vertical
  Widget _buildPortraitLayout(
    BuildContext context,
    WeatherProvider provider,
    weather,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Temperatura - usando función pura
        Text(
          formatTemperature(weather.temperature, weather.unit),
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            color: getTemperatureColor(weather.temperature),
          ),
        ),
        const SizedBox(height: 16),
        // Ciudad
        Text(
          weather.city,
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 8),
        // Mensaje sugerente según temperatura
        Text(
          getTemperatureMessage(weather.temperature),
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 32),
        // Ícono - usando función pura
        WeatherIcon(
          condition: weather.condition,
          size: 120,
          color: getTemperatureColor(weather.temperature),
        ),
        const SizedBox(height: 32),
        // Info adicional
        Text(
          'Humedad: 65% | Viento: 12 km/h',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 20),
        // Botones de prueba (para demostrar cambio de estado)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTestButton(
              context,
              '🌡️ +5°',
              () => provider.changeTemperature(weather.temperature + 5),
            ),
            const SizedBox(width: 10),
            _buildTestButton(
              context,
              '🌡️ -5°',
              () => provider.changeTemperature(weather.temperature - 5),
            ),
            const SizedBox(width: 10),
            _buildTestButton(
              context,
              '☀️ Soleado',
              () => provider.changeCondition('sunny'),
            ),
            const SizedBox(width: 10),
            _buildTestButton(
              context,
              '☁️ Nublado',
              () => provider.changeCondition('cloudy'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Botón principal
        CustomButton(
          text: 'Buscar Ciudades',
          icon: Icons.search,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Layout horizontal
  Widget _buildLandscapeLayout(
    BuildContext context,
    WeatherProvider provider,
    weather,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Columna izquierda: Temperatura y ciudad
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formatTemperature(weather.temperature, weather.unit),
                style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: getTemperatureColor(weather.temperature),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                weather.city,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                getTemperatureMessage(weather.temperature),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        // Columna derecha: Ícono, info y botones
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              WeatherIcon(
                condition: weather.condition,
                size: 80,
                color: getTemperatureColor(weather.temperature),
              ),
              const SizedBox(height: 16),
              const Text(
                'Humedad: 65% | Viento: 12 km/h',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Botones pequeños en horizontal
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildTestButton(
                    context,
                    '+5°',
                    () => provider.changeTemperature(weather.temperature + 5),
                    small: true,
                  ),
                  _buildTestButton(
                    context,
                    '-5°',
                    () => provider.changeTemperature(weather.temperature - 5),
                    small: true,
                  ),
                  _buildTestButton(
                    context,
                    '☀️',
                    () => provider.changeCondition('sunny'),
                    small: true,
                  ),
                  _buildTestButton(
                    context,
                    '☁️',
                    () => provider.changeCondition('cloudy'),
                    small: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Buscar Ciudades',
                icon: Icons.search,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SearchScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget para botones de prueba
  Widget _buildTestButton(
    BuildContext context,
    String text,
    VoidCallback onPressed, {
    bool small = false,
  }) {
    if (small) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(50, 35),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(text),
    );
  }
}