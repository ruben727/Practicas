import 'package:flutter/material.dart';
import '../widgets/weather_icon.dart';
import '../widgets/custom_button.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {  // ← 'context' está definido AQUÍ
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clima Actual'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: isLandscape
              ? _buildLandscapeLayout(context)  // ← PASAS context como parámetro
              : _buildPortraitLayout(context),  // ← PASAS context como parámetro
        ),
      ),
    );
  }

  // Layout vertical - recibe context como parámetro
  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '24°C',
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Santiago de Querétaro',
          style: TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 32),
        const WeatherIcon(condition: 'cloudy', size: 120),
        const SizedBox(height: 32),
        const Text(
          'Humedad: 65% | Viento: 12 km/h',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 40),
        CustomButton(
          text: 'Buscar Ciudades',
          icon: Icons.search,
          onPressed: () {
            Navigator.push(
              context,  // ← Ahora context existe porque lo pasamos
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Layout horizontal - recibe context como parámetro
  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Columna izquierda
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                '24°C',
                style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Santiago de Querétaro',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        // Columna derecha
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const WeatherIcon(condition: 'cloudy', size: 80),
              const SizedBox(height: 16),
              const Text(
                'Humedad: 65% | Viento: 12 km/h',
                style: TextStyle(fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Buscar Ciudades',
                icon: Icons.search,
                onPressed: () {
                  Navigator.push(
                    context,  // ← Ahora context existe
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
}