import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/activity_data.dart';

/// Transporte de respaldo por WebSocket.
///
/// Se usa cuando [BleClient] no logra encontrar/conectar al wearable dentro
/// del timeout. En este proyecto eso ocurre siempre que el wearable corre en
/// el emulador de Wear OS y el cliente en un teléfono físico, porque el
/// Bluetooth del emulador es virtual (Rootcanal) y nunca llega al radio real
/// del teléfono. Ver README.md para el puente `adb forward`/`adb reverse`
/// que hace posible esta conexión igualmente por el mismo cable USB.
class WsFallbackClient {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;

  final StreamController<ActivityData> _dataController =
      StreamController<ActivityData>.broadcast();

  Stream<ActivityData> get dataStream => _dataController.stream;

  Future<bool> connect({
    String host = '127.0.0.1',
    int port = 8080,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final channel = WebSocketChannel.connect(Uri.parse('ws://$host:$port'));
      await channel.ready.timeout(timeout);
      _channel = channel;
      _channelSub = channel.stream.listen(
        _handleMessage,
        onError: (_) {},
        onDone: () {},
      );
      return true;
    } catch (_) {
      _channel = null;
      return false;
    }
  }

  void _handleMessage(dynamic message) {
    if (message is! String) return;
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    _dataController.add(
      ActivityData(
        steps: json['steps'] as int,
        heartRate: json['heartRate'] as int,
        calories: json['calories'] as int,
        status: json['status'] as String,
        timestamp:
            DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now(),
      ),
    );
  }

  Future<void> disconnect() async {
    await _channelSub?.cancel();
    _channelSub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _dataController.close();
  }
}
