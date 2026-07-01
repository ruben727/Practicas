import 'dart:async';

import 'package:flutter/material.dart';

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
      theme: ThemeData.dark(useMaterial3: true),
      home: const WatchScreen(),
    );
  }
}

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  final SensorSimulator _simulator = SensorSimulator();
  late final BleServer _bleServer = BleServer(_simulator);

  StreamSubscription<int>? _stepsSub;
  StreamSubscription<int>? _heartRateSub;
  StreamSubscription<int>? _caloriesSub;
  StreamSubscription<String>? _statusSub;

  bool _running = false;
  int _steps = 0;
  int _heartRate = 72;
  int _calories = 0;
  String _status = 'reposo';

  @override
  void initState() {
    super.initState();
    _stepsSub =
        _simulator.stepsStream.listen((v) => setState(() => _steps = v));
    _heartRateSub = _simulator.heartRateStream
        .listen((v) => setState(() => _heartRate = v));
    _caloriesSub = _simulator.caloriesStream
        .listen((v) => setState(() => _calories = v));
    _statusSub =
        _simulator.statusStream.listen((v) => setState(() => _status = v));
  }

  @override
  void dispose() {
    _stepsSub?.cancel();
    _heartRateSub?.cancel();
    _caloriesSub?.cancel();
    _statusSub?.cancel();
    _bleServer.stop();
    _simulator.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_running) {
      await _bleServer.stop();
      _simulator.stop();
    } else {
      _simulator.start();
      await _bleServer.startAdvertising();
    }
    setState(() => _running = !_running);
  }

  @override
  Widget build(BuildContext context) {
    final bpmColor = _heartRate > 120 ? Colors.red : Colors.white;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: Colors.white24, width: 2),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$_heartRate',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: bpmColor,
                  ),
                ),
                const Text('bpm', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 12),
                Text('$_steps pasos',
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                Text('$_calories kcal',
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                Text(_status,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _toggle,
                  child: Text(_running ? 'Detener' : 'Iniciar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
