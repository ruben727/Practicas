import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/activity_data.dart';
import '../services/ble_client.dart';

enum ConnectionStatus { disconnected, scanning, connected, error }

class ActivityProvider extends ChangeNotifier {
  final BleClient _client = BleClient();

  ConnectionStatus _status = ConnectionStatus.disconnected;
  ActivityData _data = ActivityData.empty();
  String _errorMessage = '';

  ConnectionStatus get status => _status;
  ActivityData get data => _data;
  String get errorMessage => _errorMessage;
  bool get isConnected => _status == ConnectionStatus.connected;

  StreamSubscription<ActivityData>? _dataSub;

  ActivityProvider() {
    _dataSub = _client.dataStream.listen((d) {
      _data = d;
      notifyListeners();
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  /// Connect via BLE (primary path).
  Future<void> connect() async {
    _status = ConnectionStatus.scanning;
    _errorMessage = '';
    notifyListeners();

    try {
      await _requestPermissions();
      await _client.scanAndConnect();
      _status = ConnectionStatus.connected;
    } catch (e) {
      _errorMessage = e.toString();
      _status = ConnectionStatus.error;
    }
    notifyListeners();
  }

  /// Connect via WebSocket fallback (emulator scenario).
  /// [serverAddress] defaults to 'localhost' (works with adb forward/reverse).
  Future<void> connectWs([String serverAddress = 'localhost']) async {
    _status = ConnectionStatus.scanning;
    _errorMessage = '';
    notifyListeners();

    try {
      await _client.connectWs(serverAddress);
      _status = ConnectionStatus.connected;
    } catch (e) {
      _errorMessage = 'WebSocket: $e';
      _status = ConnectionStatus.error;
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _client.disconnect();
    _status = ConnectionStatus.disconnected;
    _data = ActivityData.empty();
    notifyListeners();
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _client.dispose();
    super.dispose();
  }
}
