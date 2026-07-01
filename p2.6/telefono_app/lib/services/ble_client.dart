import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble_constants.dart';
import '../models/activity_data.dart';

/// Cliente BLE (rol central). Escanea, se conecta al wearable y se suscribe
/// a las 4 características NOTIFY.
class BleClient {
  BluetoothDevice? _device;
  final List<StreamSubscription<List<int>>> _characteristicSubs = [];

  final StreamController<ActivityData> _dataController =
      StreamController<ActivityData>.broadcast();
  ActivityData _current = ActivityData.initial();

  Stream<ActivityData> get dataStream => _dataController.stream;

  final Guid _serviceGuid = Guid(BleConstants.serviceUuid);

  /// Escanea, filtra por [BleConstants.serviceUuid] y conecta al primer
  /// match. Devuelve `true` si se conectó y se suscribió correctamente
  /// dentro de [timeout].
  Future<bool> scanAndConnect({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final completer = Completer<BluetoothDevice?>();
    late final StreamSubscription<List<ScanResult>> scanSub;
    scanSub = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        if (result.advertisementData.serviceUuids.contains(_serviceGuid)) {
          if (!completer.isCompleted) completer.complete(result.device);
          return;
        }
      }
    });

    await FlutterBluePlus.startScan(
      withServices: [_serviceGuid],
      timeout: timeout,
    );

    final device = await completer.future.timeout(
      timeout,
      onTimeout: () => null,
    );
    await scanSub.cancel();
    await FlutterBluePlus.stopScan();

    if (device == null) return false;

    try {
      _device = device;
      await device.connect(timeout: timeout);
      await _discoverAndSubscribe(device);
      return true;
    } catch (_) {
      await disconnect();
      return false;
    }
  }

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();
    final service = services.firstWhere((s) => s.uuid == _serviceGuid);

    for (final characteristic in service.characteristics) {
      await characteristic.setNotifyValue(true);
      final sub = characteristic.lastValueStream.listen(
        (value) => _handleValue(characteristic.uuid, value),
      );
      _characteristicSubs.add(sub);
    }
  }

  void _handleValue(Guid uuid, List<int> bytes) {
    if (bytes.isEmpty) return;
    final data = Uint8List.fromList(bytes);

    if (uuid == Guid(BleConstants.stepsCharUuid)) {
      final steps = ByteData.sublistView(data).getInt32(0, Endian.little);
      _current = _current.copyWith(steps: steps, timestamp: DateTime.now());
    } else if (uuid == Guid(BleConstants.heartRateCharUuid)) {
      _current = _current.copyWith(
        heartRate: data[0],
        timestamp: DateTime.now(),
      );
    } else if (uuid == Guid(BleConstants.caloriesCharUuid)) {
      final calories = ByteData.sublistView(data).getInt16(0, Endian.little);
      _current = _current.copyWith(
        calories: calories,
        timestamp: DateTime.now(),
      );
    } else if (uuid == Guid(BleConstants.statusCharUuid)) {
      _current = _current.copyWith(
        status: utf8.decode(data),
        timestamp: DateTime.now(),
      );
    } else {
      return;
    }
    _dataController.add(_current);
  }

  Future<void> disconnect() async {
    for (final sub in _characteristicSubs) {
      await sub.cancel();
    }
    _characteristicSubs.clear();
    try {
      await _device?.disconnect();
    } catch (_) {
      // Ya podría estar desconectado.
    }
    _device = null;
  }

  void dispose() {
    disconnect();
    _dataController.close();
  }
}
