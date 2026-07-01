import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sensor_simulator.dart';

/// Transporte de respaldo para cuando el advertising BLE real no puede
/// llegar al dispositivo cliente (caso de este proyecto: wearable corriendo
/// en el emulador de Wear OS + teléfono físico — el Bluetooth virtual del
/// emulador, Rootcanal, nunca toca el radio Bluetooth real del host, así
/// que ningún dispositivo físico externo puede verlo jamás).
///
/// Expone un WebSocket server plano (sin librerías extra, solo dart:io) que
/// transmite el mismo estado que las características BLE en JSON. El
/// puente hacia el teléfono físico se arma con `adb forward`/`adb reverse`
/// (ver README.md), reutilizando el mismo cable/adb que ya conecta ambos
/// dispositivos a la máquina de desarrollo.
class FallbackServer {
  FallbackServer(this._simulator);

  static const int port = 8080;

  final SensorSimulator _simulator;
  HttpServer? _httpServer;
  final List<WebSocket> _clients = [];

  StreamSubscription<int>? _stepsSub;
  StreamSubscription<int>? _heartRateSub;
  StreamSubscription<int>? _caloriesSub;
  StreamSubscription<String>? _statusSub;

  bool get isRunning => _httpServer != null;

  Future<void> start() async {
    if (isRunning) return;
    _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _httpServer!.listen(_handleRequest);

    _stepsSub = _simulator.stepsStream.listen((_) => _broadcastSnapshot());
    _heartRateSub =
        _simulator.heartRateStream.listen((_) => _broadcastSnapshot());
    _caloriesSub =
        _simulator.caloriesStream.listen((_) => _broadcastSnapshot());
    _statusSub = _simulator.statusStream.listen((_) => _broadcastSnapshot());
  }

  Future<void> stop() async {
    await _stepsSub?.cancel();
    await _heartRateSub?.cancel();
    await _caloriesSub?.cancel();
    await _statusSub?.cancel();
    _stepsSub = null;
    _heartRateSub = null;
    _caloriesSub = null;
    _statusSub = null;

    for (final client in List<WebSocket>.of(_clients)) {
      await client.close();
    }
    _clients.clear();

    await _httpServer?.close(force: true);
    _httpServer = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('Solo WebSocket')
        ..close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    _clients.add(socket);
    socket.add(jsonEncode(_snapshot()));
    socket.listen(
      (_) {},
      onDone: () => _clients.remove(socket),
      onError: (_) => _clients.remove(socket),
      cancelOnError: true,
    );
  }

  Map<String, dynamic> _snapshot() => {
        'steps': _simulator.currentSteps,
        'heartRate': _simulator.currentHeartRate,
        'calories': _simulator.currentCalories,
        'status': _simulator.currentStatus,
        'timestamp': DateTime.now().toIso8601String(),
      };

  void _broadcastSnapshot() {
    if (_clients.isEmpty) return;
    final payload = jsonEncode(_snapshot());
    for (final client in List<WebSocket>.of(_clients)) {
      try {
        client.add(payload);
      } catch (_) {
        _clients.remove(client);
      }
    }
  }
}
