import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity_data.dart';
import '../providers/activity_provider.dart';
import '../widgets/metric_card.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ActivityProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor de actividad'),
        actions: [
          IconButton(
            icon: Icon(
              provider.isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth,
            ),
            onPressed: () {
              if (provider.isConnected) {
                provider.disconnect();
              } else {
                provider.connect();
              }
            },
          ),
        ],
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, ActivityProvider provider) {
    switch (provider.status) {
      case ConnectionStatus.scanning:
        return const Center(child: CircularProgressIndicator());

      case ConnectionStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  provider.errorMessage ?? 'Error desconocido',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: provider.connect,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );

      case ConnectionStatus.disconnected:
        return Center(
          child: ElevatedButton.icon(
            onPressed: provider.connect,
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('Buscar wearable'),
          ),
        );

      case ConnectionStatus.connected:
        final data = provider.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _ConnectedBody(data: data);
    }
  }
}

class _ConnectedBody extends StatelessWidget {
  const _ConnectedBody({required this.data});

  final ActivityData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (data.heartRate > 120)
          Container(
            width: double.infinity,
            color: Colors.red,
            padding: const EdgeInsets.all(12),
            child: const Text(
              '¡Ritmo cardiaco elevado!',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        Container(
          width: double.infinity,
          color: Colors.blue,
          padding: const EdgeInsets.all(12),
          child: Text(
            'Estado: ${data.status}',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              MetricCard(
                icon: Icons.directions_walk,
                label: 'Pasos',
                value: '${data.steps}',
                unit: 'pasos',
                gradientColors: const [Color(0xFF42A5F5), Color(0xFF1E88E5)],
              ),
              MetricCard(
                icon: Icons.favorite,
                label: 'Ritmo cardiaco',
                value: '${data.heartRate}',
                unit: 'bpm',
                gradientColors: [
                  data.heartRateColor.withValues(alpha: 0.7),
                  data.heartRateColor,
                ],
              ),
              MetricCard(
                icon: Icons.local_fire_department,
                label: 'Calorías',
                value: '${data.calories}',
                unit: 'kcal',
                gradientColors: const [Color(0xFFFFA726), Color(0xFFFB8C00)],
              ),
              MetricCard(
                icon: Icons.monitor_heart,
                label: 'Zona FC',
                value: data.heartRateZone,
                unit: '',
                gradientColors: const [Color(0xFFAB47BC), Color(0xFF8E24AA)],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Última actualización: '
            '${data.timestamp.hour.toString().padLeft(2, '0')}:'
            '${data.timestamp.minute.toString().padLeft(2, '0')}:'
            '${data.timestamp.second.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
