import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/activity_data.dart';
import '../services/ble_client.dart';
import '../services/ws_fallback_client.dart';

enum ConnectionStatus { disconnected, scanning, connected, error }

/// Orquesta la conexión con el wearable: intenta BLE real primero y, si no
/// encuentra/conecta a tiempo, cae al WebSocket de respaldo (ver
/// ws_fallback_client.dart y el README para el porqué). La UI no distingue
/// el transporte: solo consume [data]/[status]/[errorMessage].
class ActivityProvider extends ChangeNotifier {
  final BleClient _bleClient = BleClient();
  final WsFallbackClient _wsClient = WsFallbackClient();
  StreamSubscription<ActivityData>? _dataSub;
  bool _usingFallback = false;

  ActivityData? _data;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String? _errorMessage;

  ActivityData? get data => _data;
  ConnectionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _status == ConnectionStatus.connected;

  Future<void> connect() async {
    _status = ConnectionStatus.scanning;
    _errorMessage = null;
    notifyListeners();

    final granted = await _requestPermissions();
    if (!granted) {
      _status = ConnectionStatus.error;
      _errorMessage =
          'Se necesitan permisos de Bluetooth (y ubicación) para escanear.';
      notifyListeners();
      return;
    }

    final bleConnected = await _bleClient.scanAndConnect();
    if (bleConnected) {
      _usingFallback = false;
      _dataSub = _bleClient.dataStream.listen(_onData);
      _status = ConnectionStatus.connected;
      notifyListeners();
      return;
    }

    final wsConnected = await _wsClient.connect();
    if (wsConnected) {
      _usingFallback = true;
      _dataSub = _wsClient.dataStream.listen(_onData);
      _status = ConnectionStatus.connected;
      notifyListeners();
      return;
    }

    _status = ConnectionStatus.error;
    _errorMessage = 'No se encontró el wearable por BLE ni por el WebSocket '
        'de respaldo. Si usas el emulador de Wear OS, revisa que el túnel '
        '"adb forward"/"adb reverse" esté activo (ver README.md).';
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _dataSub?.cancel();
    _dataSub = null;
    if (_usingFallback) {
      await _wsClient.disconnect();
    } else {
      await _bleClient.disconnect();
    }
    _data = null;
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  void _onData(ActivityData data) {
    _data = data;
    notifyListeners();
  }

  Future<bool> _requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _bleClient.dispose();
    _wsClient.dispose();
    super.dispose();
  }
}
