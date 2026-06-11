import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BLEService {
  // UUIDs del wearable simulado en LightBlue
  // Servicio: FFE0 | Temperatura: FFE1 | Ciudad: FFE2
  static const String serviceUuid = 'ffe0';
  static const String temperatureCharUuid = 'ffe1';
  static const String cityCharUuid = 'ffe2';

  BluetoothDevice? _device;

  BluetoothDevice? get device => _device;

  /// Solicita permisos BLE necesarios en Android
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final granted = statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted;

    if (!granted) {
      debugPrint('BLE: Permisos no otorgados');
    }
    return granted;
  }

  /// Inicia el escaneo y devuelve el stream de resultados acumulados
  Stream<List<ScanResult>> scanForDevices() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    return FlutterBluePlus.onScanResults;
  }

  /// Detiene el escaneo
  Future<void> stopScan() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
  }

  /// Conecta al dispositivo BLE especificado
  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    await device.connect(
      autoConnect: false,
      timeout: const Duration(seconds: 10),
    );
    debugPrint('BLE: Conectado a ${device.platformName}');
  }

  /// Stream del estado de conexión del dispositivo actual
  Stream<BluetoothConnectionState> get connectionState {
    if (_device == null) return const Stream.empty();
    return _device!.connectionState;
  }

  /// Desconecta el dispositivo actual
  Future<void> disconnect() async {
    if (_device != null) {
      await _device!.disconnect();
      debugPrint('BLE: Desconectado de ${_device!.platformName}');
      _device = null;
    }
  }

  /// Descubre servicios y lee las características del wearable (temp y ciudad).
  /// Reintenta una vez si el caché GATT de Android no tiene aún el servicio FFE0.
  Future<Map<String, dynamic>?> readWeatherCharacteristics() async {
    if (_device == null) {
      debugPrint('BLE: No hay dispositivo conectado');
      return null;
    }

    for (int attempt = 1; attempt <= 2; attempt++) {
      if (attempt == 2) {
        debugPrint('BLE: Reintentando en 2s (caché GATT)...');
        await Future.delayed(const Duration(seconds: 2));
      }

      final services = await _device!.discoverServices();

      debugPrint('BLE: ── Intento $attempt — ${services.length} servicios ──');
      for (final s in services) {
        debugPrint('BLE:   ${s.serviceUuid}');
      }

      foundServiceUuids = services.map((s) => s.serviceUuid.toString()).toList();

      BluetoothService? target;
      for (final s in services) {
        if (_uuidContains(s.serviceUuid.toString(), serviceUuid)) {
          target = s;
          break;
        }
      }

      if (target == null) {
        debugPrint('BLE: FFE0 no encontrado en intento $attempt');
        continue;
      }

      debugPrint('BLE: ✓ Servicio FFE0 encontrado en intento $attempt');
      final result = <String, dynamic>{};

      for (final char in target.characteristics) {
        final charId = char.characteristicUuid.toString();
        if (_uuidContains(charId, temperatureCharUuid)) {
          final bytes = await char.read();
          _parseTemperature(bytes, result);
        } else if (_uuidContains(charId, cityCharUuid)) {
          final bytes = await char.read();
          _parseCity(bytes, result);
        }
      }

      return result.isEmpty ? null : result;
    }

    return null;
  }

  /// UUIDs encontrados en el último discoverServices (para diagnóstico)
  List<String> foundServiceUuids = [];

  bool _uuidContains(String actual, String expected) {
    return actual.toLowerCase().contains(expected.toLowerCase());
  }

  void _parseTemperature(List<int> bytes, Map<String, dynamic> out) {
    // Criterio de seguridad: validar longitud antes de convertir
    if (bytes.isEmpty || bytes.length > 20) {
      debugPrint('BLE: Longitud de bytes de temperatura inválida: ${bytes.length}');
      return;
    }
    // Eliminar bytes nulos y espacios (algunos BLE añaden padding)
    final cleaned = bytes.where((b) => b != 0).toList();
    final raw = String.fromCharCodes(cleaned).trim();
    debugPrint('BLE: Bytes temperatura raw=$bytes cleaned="$raw"');
    final temp = double.tryParse(raw);
    if (temp == null) {
      debugPrint('BLE: No se pudo parsear temperatura: "$raw"');
      return;
    }
    // Criterio de seguridad: rango -60 a 60
    if (temp < -60 || temp > 60) {
      debugPrint('BLE: Temperatura fuera de rango (-60..60): $temp');
      return;
    }
    out['temperature'] = temp;
    debugPrint('BLE: Temperatura válida recibida: $temp°C');
  }

  void _parseCity(List<int> bytes, Map<String, dynamic> out) {
    // Criterio de seguridad: validar longitud antes de convertir
    if (bytes.isEmpty || bytes.length > 50) {
      debugPrint('BLE: Longitud de bytes de ciudad inválida: ${bytes.length}');
      return;
    }
    final city = String.fromCharCodes(bytes).trim();
    // Criterio de seguridad: ciudad < 50 caracteres
    if (city.isEmpty || city.length > 50) {
      debugPrint('BLE: Nombre de ciudad inválido: "$city"');
      return;
    }
    out['city'] = city;
    debugPrint('BLE: Ciudad válida recibida: $city');
  }
}
