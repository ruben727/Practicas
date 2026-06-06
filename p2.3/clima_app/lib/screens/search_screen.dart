import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/weather_provider.dart';
import '../utils/weather_utils.dart';
import 'detail_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({Key? key}) : super(key: key);

  // Lista de ciudades disponibles
  final List<Map<String, dynamic>> availableCities = const [
    {'name': 'Santiago de Querétaro', 'temp': 24.0, 'condition': 'cloudy'},
    {'name': 'Ciudad de México', 'temp': 22.0, 'condition': 'sunny'},
    {'name': 'Guadalajara', 'temp': 26.0, 'condition': 'sunny'},
    {'name': 'Monterrey', 'temp': 28.0, 'condition': 'cloudy'},
    {'name': 'Cancún', 'temp': 30.0, 'condition': 'sunny'},
    {'name': 'Tijuana', 'temp': 20.0, 'condition': 'cloudy'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Ciudades'),
      ),
      body: ListView.builder(
        itemCount: availableCities.length,
        itemBuilder: (context, index) {
          final city = availableCities[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(
                getWeatherIcon(city['condition']),
                size: 40,
                color: Colors.blue,
              ),
              title: Text(
                city['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${city['temp'].toStringAsFixed(0)}°C | ${city['condition']}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Actualizar el provider con la ciudad seleccionada
                final provider = Provider.of<WeatherProvider>(context, listen: false);
                provider.changeCity(city['name']);
                provider.changeTemperature(city['temp']);
                provider.changeCondition(city['condition']);
                
                // Volver a la pantalla principal
                Navigator.pop(context);
                
                // Mostrar mensaje de confirmación
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Clima actualizado: ${city['name']}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}