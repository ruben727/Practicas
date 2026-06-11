import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../providers/weather_provider.dart';

class BleScreen extends StatelessWidget {
  const BleScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WeatherProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Dispositivos BLE'),
            centerTitle: true,
            actions: [
              if (provider.isScanning)
                IconButton(
                  icon: const Icon(Icons.stop),
                  tooltip: 'Detener búsqueda',
                  onPressed: () => provider.stopBleScan(),
                ),
            ],
          ),
          body: Column(
            children: [
              _BleStatusCard(provider: provider),
              Expanded(
                child: provider.isBleConnected
                    ? _ConnectedView(provider: provider)
                    : _ScanView(provider: provider),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tarjeta de estado BLE ─────────────────────────────────────────────

class _BleStatusCard extends StatelessWidget {
  final WeatherProvider provider;
  const _BleStatusCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;

    if (provider.isScanning) {
      color = Colors.blue;
      icon = Icons.bluetooth_searching;
    } else if (provider.isBleConnected) {
      color = Colors.green;
      icon = Icons.bluetooth_connected;
    } else {
      color = Colors.grey;
      icon = Icons.bluetooth_disabled;
    }

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.bleStatus,
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ),
          if (provider.isScanning)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
        ],
      ),
    );
  }
}

// ── Vista de escaneo (no conectado) ──────────────────────────────────

class _ScanView extends StatelessWidget {
  final WeatherProvider provider;
  const _ScanView({required this.provider});

  String _deviceName(ScanResult r) {
    final adv = r.advertisementData.advName;
    if (adv.isNotEmpty) return adv;
    final platform = r.device.platformName;
    if (platform.isNotEmpty) return platform;
    return '(sin nombre)';
  }

  // Señal en barras: ████ según RSSI
  String _signalBars(int rssi) {
    if (rssi >= -60) return '████  Excelente';
    if (rssi >= -70) return '███░  Buena';
    if (rssi >= -80) return '██░░  Regular';
    return '█░░░  Débil';
  }

  @override
  Widget build(BuildContext context) {
    // Ordenar por RSSI: más fuerte (más cercano) primero
    final sorted = [...provider.scanResults]
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Column(
      children: [
        const SizedBox(height: 20),
        // Botón principal de búsqueda
        ElevatedButton.icon(
          icon: const Icon(Icons.bluetooth_searching),
          label: Text(
            provider.isScanning ? 'Buscando...' : 'Buscar dispositivos BLE',
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          onPressed: provider.isScanning
              ? null
              : () => provider.startBleScan(),
        ),
        const SizedBox(height: 8),
        if (sorted.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${sorted.length} dispositivo(s) encontrado(s) — ordenados por señal',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        const SizedBox(height: 8),
        if (sorted.isEmpty && !provider.isScanning)
          const Expanded(
            child: Center(
              child: Text(
                'Presiona el botón para buscar\ndispositivos BLE cercanos',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final r = sorted[i];
                final name = _deviceName(r);
                final hasName = r.advertisementData.advName.isNotEmpty ||
                    r.device.platformName.isNotEmpty;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: hasName ? Colors.blue.shade50 : null,
                  child: ListTile(
                    leading: Icon(
                      hasName ? Icons.watch : Icons.device_unknown,
                      color: hasName ? Colors.blue : Colors.grey,
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hasName ? Colors.blue.shade800 : Colors.black54,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.device.remoteId.toString(),
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          '${r.rssi} dBm  •  ${_signalBars(r.rssi)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      onPressed: () => _connect(context, provider, r.device),
                      child: const Text('Conectar'),
                    ),
                    onTap: () => _connect(context, provider, r.device),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _connect(BuildContext context, WeatherProvider provider, BluetoothDevice device) {
    provider.connectToDevice(device);
  }
}

// ── Vista de dispositivo conectado ───────────────────────────────────

class _ConnectedView extends StatelessWidget {
  final WeatherProvider provider;
  const _ConnectedView({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.watch, size: 72, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            provider.bleDeviceName ?? 'Wearable',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Dispositivo BLE conectado',
            style: TextStyle(color: Colors.green, fontSize: 16),
          ),
          const SizedBox(height: 32),
          // Leer datos del wearable
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Leer datos del Wearable'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await provider.readFromWearable();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.bleStatus),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          // Desconectar
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.bluetooth_disabled),
              label: const Text('Desconectar'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              onPressed: () async {
                await provider.disconnectBle();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Los datos leídos del wearable se\nreflejarán en la pantalla principal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
