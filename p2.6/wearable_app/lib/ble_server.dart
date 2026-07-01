// BleServer: first tries BLE GATT peripheral (ble_peripheral ^1.0.0).
// If advertising fails (common on Wear OS emulators that lack real Bluetooth radio),
// it automatically falls back to a WebSocket server on port 8080.
//
// --- LIMITATION (emulator) ---
// A Wear OS AVD cannot advertise BLE to a physical phone over real radio.
// Workaround (WebSocket fallback):
//   1. On host PC run: adb -s emulator-XXXX forward tcp:8080 tcp:8080
//   2. On host PC run: adb -s PHONE_SERIAL  reverse tcp:8080 tcp:8080
//   3. Phone app connects to ws://localhost:8080
//
// --- PRODUCTION (real wearable) ---
// Remove the fallback; ble_peripheral advertises correctly on real hardware.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:flutter/foundation.dart';

import 'ble_constants.dart';
import 'sensor_simulator.dart';

enum ServerMode { ble, websocket, idle }

class BleServer {
  final SensorSimulator simulator;

  ServerMode _mode = ServerMode.idle;
  ServerMode get mode => _mode;

  // Connected BLE device IDs (to send notifications)
  final Set<String> _connectedDevices = {};

  // Sensor stream subscriptions
  final List<StreamSubscription<dynamic>> _subs = [];

  // WebSocket server state
  HttpServer? _wsServer;
  final Set<WebSocket> _wsClients = {};

  BleServer(this.simulator);

  /// Tries BLE first; on any exception falls back to WebSocket automatically.
  Future<void> startAdvertising() async {
    try {
      await _startBle();
      _mode = ServerMode.ble;
    } catch (e) {
      debugPrint('[BleServer] BLE failed ($e) → WebSocket fallback');
      await _startWebSocket();
      _mode = ServerMode.websocket;
    }
  }

  /// Force WebSocket mode (useful when BLE starts but AVD is not discoverable).
  Future<void> startWebSocket() async {
    await stop();
    await _startWebSocket();
    _mode = ServerMode.websocket;
  }

  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();

    if (_mode == ServerMode.ble) {
      try { await BlePeripheral.stopAdvertising(); } catch (_) {}
      _connectedDevices.clear();
    }

    if (_mode == ServerMode.websocket) {
      for (final ws in List<WebSocket>.from(_wsClients)) {
        try { await ws.close(); } catch (_) {}
      }
      _wsClients.clear();
      await _wsServer?.close(force: true);
      _wsServer = null;
    }

    _mode = ServerMode.idle;
  }

  // ─── BLE implementation ──────────────────────────────────────────────────

  Future<void> _startBle() async {
    await BlePeripheral.initialize();

    // Track connected centrals so we can address notifications
    BlePeripheral.setConnectionStateChangeCallback((deviceId, connected) {
      if (connected) {
        _connectedDevices.add(deviceId);
      } else {
        _connectedDevices.remove(deviceId);
      }
    });

    // Read callback: 3 params — (characteristicId, offset, value)
    BlePeripheral.setReadRequestCallback(
      (charId, offset, value) => ReadRequestResult(
        value: _currentBytes(charId),
        offset: offset,
      ),
    );

    await BlePeripheral.addService(
      BleService(
        uuid: BleConstants.serviceUuid,
        primary: true,
        characteristics: [
          _makeChar(BleConstants.stepsUuid),
          _makeChar(BleConstants.heartRateUuid),
          _makeChar(BleConstants.caloriesUuid),
          _makeChar(BleConstants.statusUuid),
        ],
      ),
    );

    await BlePeripheral.startAdvertising(
      services: [BleConstants.serviceUuid],
      localName: BleConstants.deviceName,
    );

    _attachBleSubs();
  }

  // Properties and permissions must be int? (use .index on the enum)
  BleCharacteristic _makeChar(String uuid) => BleCharacteristic(
        uuid: uuid,
        properties: [
          CharacteristicProperties.notify.index,
          CharacteristicProperties.read.index,
        ],
        permissions: [AttributePermissions.readable.index],
        value: null,
        descriptors: [],
      );

  void _attachBleSubs() {
    _subs.add(
      simulator.stepsStream.listen(
          (v) => _notifyAll(BleConstants.stepsUuid, _int32Le(v))),
    );
    _subs.add(
      simulator.heartRateStream.listen(
          (v) => _notifyAll(BleConstants.heartRateUuid, Uint8List.fromList([v.clamp(0, 255)]))),
    );
    _subs.add(
      simulator.caloriesStream.listen(
          (v) => _notifyAll(BleConstants.caloriesUuid, _int16Le(v.round()))),
    );
    _subs.add(
      simulator.statusStream.listen(
          (v) => _notifyAll(BleConstants.statusUuid, Uint8List.fromList(utf8.encode(v)))),
    );
  }

  Future<void> _notifyAll(String charUuid, Uint8List bytes) async {
    for (final deviceId in List<String>.from(_connectedDevices)) {
      try {
        await BlePeripheral.updateCharacteristic(
          deviceId: deviceId,
          characteristicId: charUuid,
          value: bytes,
        );
      } catch (_) {}
    }
  }

  Uint8List _currentBytes(String charId) {
    return switch (charId.toLowerCase()) {
      BleConstants.stepsUuid     => _int32Le(simulator.steps),
      BleConstants.heartRateUuid => Uint8List.fromList([simulator.heartRate.clamp(0, 255)]),
      BleConstants.caloriesUuid  => _int16Le(simulator.calories.round()),
      BleConstants.statusUuid    => Uint8List.fromList(utf8.encode(simulator.status)),
      _                          => Uint8List(0),
    };
  }

  // ─── WebSocket fallback ───────────────────────────────────────────────────

  Future<void> _startWebSocket() async {
    _wsServer = await HttpServer.bind(InternetAddress.anyIPv4, BleConstants.wsPort);

    _wsServer!.transform(WebSocketTransformer()).listen((ws) {
      _wsClients.add(ws);
      // Push current snapshot on connect
      _sendWs(ws, {'type': 'steps',  'value': simulator.steps});
      _sendWs(ws, {'type': 'hr',     'value': simulator.heartRate});
      _sendWs(ws, {'type': 'cal',    'value': simulator.calories.round()});
      _sendWs(ws, {'type': 'status', 'value': simulator.status});
      ws.done.then((_) => _wsClients.remove(ws));
    });

    _subs.add(simulator.stepsStream.listen(
        (v) => _broadcast({'type': 'steps',  'value': v})));
    _subs.add(simulator.heartRateStream.listen(
        (v) => _broadcast({'type': 'hr',     'value': v})));
    _subs.add(simulator.caloriesStream.listen(
        (v) => _broadcast({'type': 'cal',    'value': v.round()})));
    _subs.add(simulator.statusStream.listen(
        (v) => _broadcast({'type': 'status', 'value': v})));
  }

  void _broadcast(Map<String, dynamic> msg) {
    final data = jsonEncode(msg);
    for (final ws in List<WebSocket>.from(_wsClients)) {
      try { ws.add(data); } catch (_) {}
    }
  }

  void _sendWs(WebSocket ws, Map<String, dynamic> msg) {
    try { ws.add(jsonEncode(msg)); } catch (_) {}
  }

  // ─── Encoding helpers ─────────────────────────────────────────────────────

  Uint8List _int32Le(int v) {
    final bd = ByteData(4);
    bd.setInt32(0, v, Endian.little);
    return bd.buffer.asUint8List();
  }

  Uint8List _int16Le(int v) {
    final bd = ByteData(2);
    bd.setInt16(0, v.clamp(-32768, 32767), Endian.little);
    return bd.buffer.asUint8List();
  }
}
