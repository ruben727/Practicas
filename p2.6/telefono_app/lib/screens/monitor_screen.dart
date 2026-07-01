import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/activity_data.dart';
import '../providers/activity_provider.dart';
import '../widgets/metric_card.dart';

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  final _wsCtrl = TextEditingController(text: 'localhost');

  @override
  void dispose() {
    _wsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Monitor Actividad'),
            actions: [
              IconButton(
                icon: Icon(
                  provider.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: provider.isConnected ? Colors.blue : null,
                ),
                onPressed: provider.isConnected
                    ? () => provider.disconnect()
                    : null,
                tooltip: provider.isConnected ? 'Desconectar' : 'Sin conexión',
              ),
            ],
          ),
          body: _buildBody(context, provider),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ActivityProvider provider) {
    switch (provider.status) {
      case ConnectionStatus.scanning:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Buscando wearable…'),
            ],
          ),
        );

      case ConnectionStatus.error:
        return _buildError(context, provider);

      case ConnectionStatus.disconnected:
        return _buildDisconnected(context, provider);

      case ConnectionStatus.connected:
        return _buildConnected(context, provider.data);
    }
  }

  Widget _buildDisconnected(BuildContext context, ActivityProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.watch, size: 72, color: Colors.white38),
            const SizedBox(height: 16),
            const Text('Sin conexión al wearable',
                style: TextStyle(fontSize: 16, color: Colors.white54)),
            const SizedBox(height: 24),

            // BLE connect
            ElevatedButton.icon(
              icon: const Icon(Icons.bluetooth),
              label: const Text('Buscar wearable (BLE)'),
              onPressed: () => provider.connect(),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            // WebSocket fallback section
            const Text('Fallback WiFi (emulador)',
                style: TextStyle(fontSize: 12, color: Colors.white38)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _wsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'IP de tu PC (o "localhost" si usas USB)',
                      hintText: 'ej. 192.168.1.50',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => provider.connectWs(_wsCtrl.text.trim()),
                  child: const Text('WiFi'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              // NOTE: escribe aquí la IP LAN de tu PC (ipconfig), no la del
              // wearable — el emulador no es alcanzable directamente desde
              // un teléfono físico. Detalle completo en WIFI_FALLBACK.md.
              'Solo WiFi (sin cable):\n'
              '  1) adb -s emulator-XXXX forward tcp:8080 tcp:8080\n'
              '  2) netsh interface portproxy add v4tov4 listenaddress=<IP_PC> '
              'listenport=8080 connectaddress=127.0.0.1 connectport=8080\n'
              '  3) Escribe la IP de tu PC arriba y pulsa WiFi\n\n'
              'Con cable USB (más simple): adb reverse tcp:8080 tcp:8080 '
              'y usa "localhost"',
              style: TextStyle(fontSize: 9, color: Colors.white24),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, ActivityProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar BLE'),
              onPressed: () => provider.connect(),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.wifi),
              label: const Text('Conectar por WiFi'),
              onPressed: () => provider.disconnect(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnected(BuildContext context, ActivityData data) {
    return Column(
      children: [
        // High HR alert banner
        if (data.heartRate > 120)
          Container(
            width: double.infinity,
            color: Colors.red.shade800,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('¡Ritmo cardíaco elevado!',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),

        // Activity status banner
        Container(
          width: double.infinity,
          color: Colors.blue.shade800,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.directions_run, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Text('Estado: ${data.status}',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),

        // Metrics grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                MetricCard(
                  icon: Icons.directions_walk,
                  label: 'Pasos',
                  value: '${data.steps}',
                  unit: 'pasos',
                  gradientColors: const [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                ),
                MetricCard(
                  icon: Icons.favorite,
                  label: 'Ritmo cardíaco',
                  value: '${data.heartRate}',
                  unit: 'bpm',
                  gradientColors: data.heartRate > 120
                      ? const [Color(0xFFB71C1C), Color(0xFFC62828)]
                      : const [Color(0xFF880E4F), Color(0xFFAD1457)],
                ),
                MetricCard(
                  icon: Icons.local_fire_department,
                  label: 'Calorías',
                  value: '${data.calories}',
                  unit: 'kcal',
                  gradientColors: const [Color(0xFFE65100), Color(0xFFF57C00)],
                ),
                MetricCard(
                  icon: Icons.monitor_heart,
                  label: 'Zona FC',
                  value: data.heartRateZone,
                  unit: '${data.heartRate} bpm',
                  gradientColors: [
                    data.heartRateColor.withAlpha(200),
                    data.heartRateColor.withAlpha(160),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Timestamp
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Actualizado: ${_formatTime(data.timestamp)}',
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';
}
