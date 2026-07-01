import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_constants.dart';
import 'ble_server.dart';
import 'sensor_simulator.dart';

void main() {
  runApp(const WearableApp());
}

class WearableApp extends StatelessWidget {
  const WearableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Colors.redAccent,
        ),
      ),
      home: const WearableScreen(),
    );
  }
}

class WearableScreen extends StatefulWidget {
  const WearableScreen({super.key});

  @override
  State<WearableScreen> createState() => _WearableScreenState();
}

class _WearableScreenState extends State<WearableScreen> {
  final _simulator = SensorSimulator();
  late final BleServer _server;

  bool _active = false;
  String _modeLabel = '';
  String _localIp = '';

  int _steps = 0;
  int _hr = 72;
  double _cal = 0;
  String _status = 'reposo';

  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  void initState() {
    super.initState();
    _server = BleServer(_simulator);
    _subs.add(_simulator.stepsStream.listen((v) => setState(() => _steps = v)));
    _subs.add(_simulator.heartRateStream.listen((v) => setState(() => _hr = v)));
    _subs.add(_simulator.caloriesStream.listen((v) => setState(() => _cal = v)));
    _subs.add(_simulator.statusStream.listen((v) => setState(() => _status = v)));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _server.stop();
    _simulator.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();
    }
  }

  Future<void> _resolveLocalIp() async {
    try {
      final interfaces =
          await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            if (mounted) setState(() => _localIp = addr.address);
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _toggle() async {
    if (_active) {
      _simulator.stop();
      await _server.stop();
      setState(() {
        _active = false;
        _modeLabel = '';
        _localIp = '';
      });
    } else {
      await _requestPermissions();
      _simulator.start();
      await _server.startAdvertising();

      if (_server.mode == ServerMode.websocket) {
        await _resolveLocalIp();
      }

      if (mounted) {
        setState(() {
          _active = true;
          _modeLabel = _server.mode == ServerMode.ble ? 'BLE' : 'WiFi/WS';
        });
      }
    }
  }

  /// Manual override: switch from BLE mode to WebSocket when the emulator
  /// starts advertising without error but no physical device finds it.
  Future<void> _switchToWs() async {
    if (!_active) return;
    _simulator.stop();
    await _server.stop();
    _simulator.start();
    await _server.startWebSocket();
    await _resolveLocalIp();
    if (mounted) setState(() => _modeLabel = 'WiFi/WS');
  }

  @override
  Widget build(BuildContext context) {
    final hrColor = _hr > 120 ? Colors.red : Colors.redAccent;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // BPM display
                Text(
                  '$_hr',
                  style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: hrColor),
                ),
                Text('bpm',
                    style: TextStyle(color: hrColor, fontSize: 13)),

                const SizedBox(height: 16),

                // Steps and calories row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _chip(Icons.directions_walk, '$_steps', 'pasos'),
                    _chip(Icons.local_fire_department,
                        _cal.toStringAsFixed(1), 'kcal'),
                  ],
                ),

                const SizedBox(height: 10),

                // Activity badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_status,
                      style: const TextStyle(fontSize: 13)),
                ),

                const SizedBox(height: 18),

                // Start / Stop
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _active
                        ? Colors.red.shade900
                        : Colors.green.shade800,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                  ),
                  onPressed: _toggle,
                  child: Text(_active ? 'Detener' : 'Iniciar',
                      style: const TextStyle(fontSize: 15)),
                ),

                if (_active) ...[
                  const SizedBox(height: 8),
                  Text('Modo: $_modeLabel',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white54)),

                  // WebSocket: this IP is the emulator's internal NAT address
                  // (10.0.2.x) — it is NOT reachable from a physical phone.
                  // Show the port + adb forward hint instead; see
                  // WIFI_FALLBACK.md at the repo root for the full steps.
                  if (_server.mode == ServerMode.websocket)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        children: [
                          Text(
                            'Puerto local: ${BleConstants.wsPort} (usa "adb forward" en tu PC)',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.cyanAccent),
                            textAlign: TextAlign.center,
                          ),
                          if (_localIp.isNotEmpty)
                            Text(
                              'IP interna AVD: $_localIp (no la uses en el teléfono)',
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.white24),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),

                  // Offer manual switch when BLE might be invisible to phone
                  if (_server.mode == ServerMode.ble)
                    TextButton(
                      onPressed: _switchToWs,
                      child: const Text(
                        '¿No detectado? → Cambiar a WiFi',
                        style: TextStyle(fontSize: 10, color: Colors.cyan),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String value, String unit) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.white70),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        Text(unit,
            style:
                const TextStyle(fontSize: 10, color: Colors.white54)),
      ],
    );
  }
}
