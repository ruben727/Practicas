import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/weather.dart';
import '../services/ble_service.dart';

/// Provider que maneja el estado del clima
class WeatherProvider extends ChangeNotifier {
  // ── BLE ─────────────────────────────────────────────────────────────
  final BLEService _bleService = BLEService();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  bool _isBleConnected = false;
  String _bleStatus = 'Sin conexión BLE';
  String? _bleDeviceName;

  BLEService get bleService => _bleService;
  List<ScanResult> get scanResults => List.unmodifiable(_scanResults);
  bool get isScanning => _isScanning;
  bool get isBleConnected => _isBleConnected;
  String get bleStatus => _bleStatus;
  String? get bleDeviceName => _bleDeviceName;
  // ────────────────────────────────────────────────────────────────────

  // Estado inicial
  Weather _currentWeather = Weather(
    city: 'Santiago de Querétaro',
    temperature: 24.0,
    condition: 'cloudy',
    unit: 'C',
  );

  // Getter para acceder al estado desde la UI
  Weather get currentWeather => _currentWeather;

  // Getter para la temperatura formateada
  String get formattedTemperature {
    return '${_currentWeather.temperature.toStringAsFixed(0)}°${_currentWeather.unit}';
  }

  // Método para cambiar la ciudad con validación
  void changeCity(String newCity) {
    if (newCity.trim().isEmpty) {
      debugPrint('Error: La ciudad no puede estar vacía');
      return;
    }

    _currentWeather = _currentWeather.copyWith(city: newCity.trim());
    notifyListeners();
    debugPrint('Ciudad cambiada a: $newCity');
  }

  // Método para cambiar la temperatura con validación
  void changeTemperature(double newTemperature) {
    if (newTemperature < -60 || newTemperature > 60) {
      debugPrint('Error: Temperatura $newTemperature°C fuera de rango (-60 a 60)');
      return;
    }

    _currentWeather = _currentWeather.copyWith(temperature: newTemperature);
    notifyListeners();
    debugPrint('Temperatura cambiada a: ${newTemperature.toStringAsFixed(0)}°C');
  }

  // Método para cambiar la condición del clima
  void changeCondition(String newCondition) {
    if (newCondition.trim().isEmpty) {
      debugPrint('Error: La condición no puede estar vacía');
      return;
    }

    _currentWeather = _currentWeather.copyWith(condition: newCondition.toLowerCase());
    notifyListeners();
    debugPrint('Condición cambiada a: $newCondition');
  }

  // Método para cambiar entre Celsius y Fahrenheit
  void toggleUnit() {
    final newUnit = _currentWeather.unit == 'C' ? 'F' : 'C';
    double newTemperature = _currentWeather.temperature;
    
    if (newUnit == 'F') {
      // Celsius a Fahrenheit: (C × 9/5) + 32
      newTemperature = (_currentWeather.temperature * 9 / 5) + 32;
    } else {
      // Fahrenheit a Celsius: (F - 32) × 5/9
      newTemperature = (_currentWeather.temperature - 32) * 5 / 9;
    }

    _currentWeather = _currentWeather.copyWith(
      unit: newUnit,
      temperature: double.parse(newTemperature.toStringAsFixed(1)),
    );
    notifyListeners();
    debugPrint('Unidad cambiada a: $newUnit');
  }

  // Método para cargar datos de ejemplo
  void loadExampleData() {
    _currentWeather = Weather(
      city: 'Ciudad de México',
      temperature: 22.0,
      condition: 'sunny',
      unit: 'C',
    );
    notifyListeners();
  }

  // Método para resetear a valores por defecto
  void resetToDefault() {
    _currentWeather = Weather(
      city: 'Santiago de Querétaro',
      temperature: 24.0,
      condition: 'cloudy',
      unit: 'C',
    );
    notifyListeners();
  }

  // ── Métodos BLE ──────────────────────────────────────────────────────

  /// Solicita permisos e inicia el escaneo de dispositivos BLE
  Future<void> startBleScan() async {
    // Verificar que el Bluetooth esté encendido
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      _bleStatus = 'Activa el Bluetooth para escanear';
      notifyListeners();
      return;
    }

    final granted = await _bleService.requestPermissions();
    if (!granted) {
      _bleStatus = 'Permisos BLE denegados';
      notifyListeners();
      return;
    }

    _scanResults.clear();
    _isScanning = true;
    _bleStatus = 'Buscando dispositivos...';
    notifyListeners();

    try {
      _scanSubscription?.cancel();
      _scanSubscription = _bleService.scanForDevices().listen(
        (results) {
          _scanResults = results;
          notifyListeners();
        },
        onDone: () {
          _isScanning = false;
          _bleStatus = _scanResults.isEmpty
              ? 'No se encontraron dispositivos'
              : 'Búsqueda completada';
          notifyListeners();
        },
        onError: (e) {
          _isScanning = false;
          _bleStatus = 'Error al escanear';
          debugPrint('BLE scan error: $e');
          notifyListeners();
        },
      );
    } catch (e) {
      _isScanning = false;
      _bleStatus = 'Error al iniciar escaneo';
      debugPrint('BLE startScan exception: $e');
      notifyListeners();
    }

    Future.delayed(const Duration(seconds: 11), () {
      if (_isScanning) stopBleScan();
    });
  }

  /// Detiene el escaneo BLE
  Future<void> stopBleScan() async {
    await _bleService.stopScan();
    _scanSubscription?.cancel();
    _isScanning = false;
    notifyListeners();
  }

  /// Conecta a un dispositivo BLE y escucha desconexiones
  Future<void> connectToDevice(BluetoothDevice device) async {
    _bleStatus = 'Conectando...';
    notifyListeners();

    try {
      await stopBleScan();
      await _bleService.connect(device);

      _bleDeviceName = device.platformName.isNotEmpty
          ? device.platformName
          : device.remoteId.toString();
      _isBleConnected = true;
      _bleStatus = 'Conectado a $_bleDeviceName';
      notifyListeners();

      // Escuchar desconexión del wearable
      _connectionSubscription?.cancel();
      _connectionSubscription = _bleService.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _isBleConnected = false;
          _bleStatus = 'Sin conexión BLE';
          _bleDeviceName = null;
          notifyListeners();
          debugPrint('BLE: Wearable desconectado');
        }
      });
    } catch (e) {
      _isBleConnected = false;
      _bleStatus = 'Error al conectar';
      debugPrint('BLE connect error: $e');
      notifyListeners();
    }
  }

  /// Lee temperatura y ciudad del wearable y actualiza el clima
  Future<void> readFromWearable() async {
    if (!_isBleConnected) return;

    _bleStatus = 'Leyendo datos del wearable...';
    notifyListeners();

    try {
      final data = await _bleService.readWeatherCharacteristics();

      if (data == null) {
        final found = _bleService.foundServiceUuids;
        if (found.isEmpty) {
          _bleStatus = 'No se encontraron servicios en el dispositivo';
        } else {
          // Mostrar el primer UUID encontrado para ayudar a diagnosticar
          final short = found.first.length > 8 ? found.first.substring(4, 8) : found.first;
          _bleStatus = 'Servicio FFE0 no encontrado. Hallado: $short... (${found.length} servicios)';
        }
        notifyListeners();
        return;
      }

      if (data['temperature'] != null) {
        changeTemperature(data['temperature'] as double);
      }
      if (data['city'] != null) {
        changeCity(data['city'] as String);
      }

      _bleStatus = 'Datos del wearable actualizados';
    } catch (e) {
      _bleStatus = 'Error al leer datos';
      debugPrint('BLE read error: $e');
    }
    notifyListeners();
  }

  /// Desconecta el wearable actual
  Future<void> disconnectBle() async {
    await _bleService.disconnect();
    _connectionSubscription?.cancel();
    _isBleConnected = false;
    _bleDeviceName = null;
    _bleStatus = 'Sin conexión BLE';
    notifyListeners();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
  // ────────────────────────────────────────────────────────────────────
}