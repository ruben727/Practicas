// BleServer: first tries BLE GATT peripheral (bluetooth_low_energy ^6.2.1).
// If advertising fails it automatically falls back to a WebSocket server on
// port 8080, bound to 0.0.0.0 (all interfaces) so it is reachable from
// outside the AVD via `adb forward` regardless of the emulator's internal
// NAT address (10.0.2.x).
//
// --- LIMITATION (emulator) ---
// bluetooth_low_energy's own docs state BLE is not supported on emulators.
// In practice, this Wear OS AVD's virtual Bluetooth stack (rootcanal) DOES
// let addService()/startAdvertising() succeed with status=0 locally — but
// that does not guarantee the advertisement reaches a physical phone's real
// radio. Verify with the phone app; if it can't discover "WearableMonitor",
// use the WebSocket fallback. Two scenarios:
//
//   A) Phone plugged into the PC via USB (adb sees it):
//      1. adb -s emulator-XXXX forward tcp:8080 tcp:8080
//      2. adb -s PHONE_SERIAL  reverse tcp:8080 tcp:8080
//      3. Phone app connects to ws://localhost:8080
//
//   B) Phone only on WiFi, not plugged in (see WIFI_FALLBACK.md at repo root):
//      `adb forward` only binds 127.0.0.1 on the host, never the WiFi NIC,
//      so step 2 above isn't available. You must relay the host's loopback
//      port onto the LAN interface yourself, e.g. on Windows:
//      1. adb -s emulator-XXXX forward tcp:8080 tcp:8080
//      2. netsh interface portproxy add v4tov4 listenaddress=<PC_LAN_IP> \
//           listenport=8080 connectaddress=127.0.0.1 connectport=8080
//      3. Phone app connects to ws://<PC_LAN_IP>:8080
//      This mapping resets whenever the emulator/adb server restarts or the
//      PC's WiFi network changes — rerun it.
//
// --- PRODUCTION (real wearable) ---
// Remove the fallback; bluetooth_low_energy advertises correctly on real hardware.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';

import 'ble_constants.dart';
import 'sensor_simulator.dart';

enum ServerMode { ble, websocket, idle }

class BleServer {
  final SensorSimulator simulator;

  final PeripheralManager _peripheralManager = PeripheralManager();

  ServerMode _mode = ServerMode.idle;
  ServerMode get mode => _mode;

  // Centrals currently subscribed (NOTIFY enabled), keyed by characteristic UUID.
  final Map<UUID, Set<Central>> _subscriptions = {};

  late final GATTCharacteristic _stepsChar;
  late final GATTCharacteristic _heartRateChar;
  late final GATTCharacteristic _caloriesChar;
  late final GATTCharacteristic _statusChar;

  StreamSubscription<GATTCharacteristicReadRequestedEventArgs>? _readSub;
  StreamSubscription<GATTCharacteristicNotifyStateChangedEventArgs>? _notifySub;

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
      await _readSub?.cancel();
      await _notifySub?.cancel();
      _readSub = null;
      _notifySub = null;
      try { await _peripheralManager.stopAdvertising(); } catch (_) {}
      try { await _peripheralManager.removeAllServices(); } catch (_) {}
      _subscriptions.clear();
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
    _stepsChar = _makeChar(BleConstants.stepsUuid);
    _heartRateChar = _makeChar(BleConstants.heartRateUuid);
    _caloriesChar = _makeChar(BleConstants.caloriesUuid);
    _statusChar = _makeChar(BleConstants.statusUuid);

    // Read requests: reply with the current sensor snapshot.
    _readSub = _peripheralManager.characteristicReadRequested.listen((args) {
      final bytes = _currentBytes(args.characteristic.uuid);
      _peripheralManager.respondReadRequestWithValue(args.request, value: bytes);
    });

    // Track which centrals have NOTIFY enabled per characteristic.
    _notifySub = _peripheralManager.characteristicNotifyStateChanged.listen((args) {
      final centrals = _subscriptions.putIfAbsent(args.characteristic.uuid, () => {});
      if (args.state) {
        centrals.add(args.central);
      } else {
        centrals.remove(args.central);
      }
    });

    await _peripheralManager.addService(
      GATTService(
        uuid: UUID.fromString(BleConstants.serviceUuid),
        isPrimary: true,
        includedServices: [],
        characteristics: [_stepsChar, _heartRateChar, _caloriesChar, _statusChar],
      ),
    );

    await _peripheralManager.startAdvertising(
      Advertisement(
        name: BleConstants.deviceName,
        serviceUUIDs: [UUID.fromString(BleConstants.serviceUuid)],
      ),
    );

    _attachBleSubs();
  }

  GATTCharacteristic _makeChar(String uuid) => GATTCharacteristic.mutable(
        uuid: UUID.fromString(uuid),
        properties: [
          GATTCharacteristicProperty.notify,
          GATTCharacteristicProperty.read,
        ],
        permissions: [GATTCharacteristicPermission.read],
        descriptors: [],
      );

  void _attachBleSubs() {
    _subs.add(
      simulator.stepsStream.listen(
          (v) => _notifyChar(_stepsChar, _int32Le(v))),
    );
    _subs.add(
      simulator.heartRateStream.listen(
          (v) => _notifyChar(_heartRateChar, Uint8List.fromList([v.clamp(0, 255)]))),
    );
    _subs.add(
      simulator.caloriesStream.listen(
          (v) => _notifyChar(_caloriesChar, _int16Le(v.round()))),
    );
    _subs.add(
      simulator.statusStream.listen(
          (v) => _notifyChar(_statusChar, Uint8List.fromList(utf8.encode(v)))),
    );
  }

  Future<void> _notifyChar(GATTCharacteristic char, Uint8List bytes) async {
    final centrals = _subscriptions[char.uuid];
    if (centrals == null || centrals.isEmpty) return;
    for (final central in List<Central>.from(centrals)) {
      try {
        await _peripheralManager.notifyCharacteristic(central, char, value: bytes);
      } catch (_) {
        centrals.remove(central);
      }
    }
  }

  Uint8List _currentBytes(UUID uuid) {
    if (uuid == _stepsChar.uuid) return _int32Le(simulator.steps);
    if (uuid == _heartRateChar.uuid) {
      return Uint8List.fromList([simulator.heartRate.clamp(0, 255)]);
    }
    if (uuid == _caloriesChar.uuid) return _int16Le(simulator.calories.round());
    if (uuid == _statusChar.uuid) {
      return Uint8List.fromList(utf8.encode(simulator.status));
    }
    return Uint8List(0);
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
