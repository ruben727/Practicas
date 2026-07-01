// BleClient: attempts a BLE GATT central connection first.
// If scan times out with no device found, the provider offers WebSocket fallback.
//
// WebSocket fallback (emulator scenario):
//   On host PC:
//     adb -s emulator-XXXX forward tcp:8080 tcp:8080
//     adb -s PHONE_SERIAL  reverse tcp:8080 tcp:8080
//   Then phone app connects to ws://localhost:8080

import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../ble_constants.dart';
import '../models/activity_data.dart';

class BleClient {
  final _dataCtrl = StreamController<ActivityData>.broadcast();
  Stream<ActivityData> get dataStream => _dataCtrl.stream;

  ActivityData _current = ActivityData.empty();

  BluetoothDevice? _device;
  final List<StreamSubscription<dynamic>> _charSubs = [];
  StreamSubscription<dynamic>? _scanSub;

  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSub;

  bool get isConnected =>
      (_device != null && _device!.isConnected) || _wsChannel != null;

  // ─── BLE central ──────────────────────────────────────────────────────────

  /// Scans for [BleConstants.deviceName], connects, subscribes to all notify
  /// characteristics. Throws [TimeoutException] if nothing found in 15 s.
  Future<void> scanAndConnect() async {
    await FlutterBluePlus.startScan(
      withServices: [Guid(BleConstants.serviceUuid)],
      timeout: const Duration(seconds: 15),
    );

    final completer = Completer<BluetoothDevice>();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (!completer.isCompleted) {
          completer.complete(r.device);
        }
      }
    });

    // Race: first result wins, or 15-second timeout
    late BluetoothDevice device;
    try {
      device = await completer.future
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      await FlutterBluePlus.stopScan();
      _scanSub?.cancel();
      throw TimeoutException(
          'Wearable no encontrado (BLE). Usa la opción WiFi.', const Duration(seconds: 15));
    }

    await FlutterBluePlus.stopScan();
    _scanSub?.cancel();

    await device.connect(timeout: const Duration(seconds: 10));
    _device = device;

    await _discoverAndSubscribe(device);
  }

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();
    for (final svc in services) {
      if (svc.uuid.str128.toLowerCase() == BleConstants.serviceUuid) {
        for (final char in svc.characteristics) {
          if (char.properties.notify) {
            await char.setNotifyValue(true);
            final sub = char.lastValueStream.listen((bytes) {
              _handleBleValue(char.uuid.str128.toLowerCase(), bytes);
            });
            _charSubs.add(sub);
          }
        }
      }
    }
  }

  void _handleBleValue(String uuid, List<int> bytes) {
    if (bytes.isEmpty) return;
    final data = Uint8List.fromList(bytes);
    final bd = ByteData.sublistView(data);

    ActivityData next;
    switch (uuid) {
      case BleConstants.stepsUuid:
        next = _current.copyWith(
            steps: bd.getInt32(0, Endian.little), timestamp: DateTime.now());
      case BleConstants.heartRateUuid:
        next = _current.copyWith(
            heartRate: data[0], timestamp: DateTime.now());
      case BleConstants.caloriesUuid:
        next = _current.copyWith(
            calories: bd.getInt16(0, Endian.little), timestamp: DateTime.now());
      case BleConstants.statusUuid:
        next = _current.copyWith(
            status: utf8.decode(bytes), timestamp: DateTime.now());
      default:
        return;
    }
    _current = next;
    _dataCtrl.add(_current);
  }

  // ─── WebSocket client ──────────────────────────────────────────────────────

  Future<void> connectWs(String serverAddress) async {
    final uri = Uri.parse('ws://$serverAddress:${BleConstants.wsPort}');
    _wsChannel = WebSocketChannel.connect(uri);

    // Wait for the connection to be established (throws on failure)
    await _wsChannel!.ready;

    _wsSub = _wsChannel!.stream.listen(
      _handleWsMessage,
      onError: (e) => debugPrint('[BleClient WS] error: $e'),
      onDone: () => debugPrint('[BleClient WS] closed'),
    );
  }

  void _handleWsMessage(dynamic raw) {
    try {
      final Map<String, dynamic> msg = jsonDecode(raw as String);
      ActivityData next;
      switch (msg['type']) {
        case 'steps':
          next = _current.copyWith(
              steps: (msg['value'] as num).toInt(), timestamp: DateTime.now());
        case 'hr':
          next = _current.copyWith(
              heartRate: (msg['value'] as num).toInt(), timestamp: DateTime.now());
        case 'cal':
          next = _current.copyWith(
              calories: (msg['value'] as num).toInt(), timestamp: DateTime.now());
        case 'status':
          next = _current.copyWith(
              status: msg['value'] as String, timestamp: DateTime.now());
        default:
          return;
      }
      _current = next;
      _dataCtrl.add(_current);
    } catch (_) {}
  }

  // ─── Disconnect ────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    for (final s in _charSubs) { await s.cancel(); }
    _charSubs.clear();
    await _scanSub?.cancel();

    try { await _device?.disconnect(); } catch (_) {}
    _device = null;

    await _wsSub?.cancel();
    await _wsChannel?.sink.close();
    _wsChannel = null;
  }

  void dispose() {
    disconnect();
    _dataCtrl.close();
  }
}
