import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

import 'ble_constants.dart';
import 'fallback_server.dart';
import 'sensor_simulator.dart';

/// Servidor GATT real del wearable.
///
/// flutter_blue_plus (usado en telefono_app como cliente) NO implementa rol
/// periférico/servidor en Android, solo rol central. Por eso aquí se usa
/// `bluetooth_low_energy`, que sí expone `PeripheralManager` con soporte
/// completo de advertising + características GATT + notificaciones en
/// Android/iOS/macOS.
///
/// En paralelo siempre se levanta [FallbackServer]: el emulador de Wear OS
/// no tiene forma de anunciarse por BLE hacia un dispositivo físico externo
/// (su Bluetooth es virtual, vía Rootcanal, y no toca el radio real del
/// host), así que para esta combinación concreta (wearable emulado +
/// teléfono físico) el WebSocket es el único canal que de verdad va a
/// entregar datos. Ver README.md.
class BleServer {
  BleServer(this._simulator) : fallbackServer = FallbackServer(_simulator);

  final SensorSimulator _simulator;
  final PeripheralManager _manager = PeripheralManager();
  final FallbackServer fallbackServer;

  late final GATTCharacteristic _stepsChar;
  late final GATTCharacteristic _heartRateChar;
  late final GATTCharacteristic _caloriesChar;
  late final GATTCharacteristic _statusChar;

  final Map<UUID, Set<Central>> _subscribedCentrals = {};

  StreamSubscription? _stateChangedSub;
  StreamSubscription? _notifySub;
  StreamSubscription<int>? _stepsSub;
  StreamSubscription<int>? _heartRateSub;
  StreamSubscription<int>? _caloriesSub;
  StreamSubscription<String>? _statusSub;

  bool _advertising = false;
  String? lastError;

  bool get isAdvertising => _advertising;

  Future<void> startAdvertising() async {
    if (_advertising) return;

    // El WebSocket de respaldo siempre corre: es el camino garantizado en
    // este entorno (wearable emulado + teléfono físico).
    await fallbackServer.start();

    _stateChangedSub = _manager.stateChanged.listen((eventArgs) async {
      if (eventArgs.state == BluetoothLowEnergyState.unauthorized &&
          Platform.isAndroid) {
        await _manager.authorize();
      }
    });

    try {
      await _setupGattService();
      final advertisement = Advertisement(
        name: 'Wearable P2.6',
        serviceUUIDs: [UUID.fromString(BleConstants.serviceUuid)],
      );
      await _manager.startAdvertising(advertisement);
      _advertising = true;
    } catch (e) {
      // No se pudo anunciar por BLE real (típico en el emulador de Wear
      // OS). No es fatal: el FallbackServer ya está corriendo.
      lastError = e.toString();
      _advertising = false;
    }

    _stepsSub = _simulator.stepsStream.listen(
      (value) => _notify(_stepsChar, _int32LE(value)),
    );
    _heartRateSub = _simulator.heartRateStream.listen(
      (value) => _notify(_heartRateChar, Uint8List.fromList([value & 0xFF])),
    );
    _caloriesSub = _simulator.caloriesStream.listen(
      (value) => _notify(_caloriesChar, _int16LE(value)),
    );
    _statusSub = _simulator.statusStream.listen(
      (value) => _notify(_statusChar, Uint8List.fromList(utf8.encode(value))),
    );
  }

  Future<void> stop() async {
    await _stepsSub?.cancel();
    await _heartRateSub?.cancel();
    await _caloriesSub?.cancel();
    await _statusSub?.cancel();
    await _notifySub?.cancel();
    await _stateChangedSub?.cancel();
    _stepsSub = null;
    _heartRateSub = null;
    _caloriesSub = null;
    _statusSub = null;
    _notifySub = null;
    _stateChangedSub = null;
    _subscribedCentrals.clear();

    if (_advertising) {
      try {
        await _manager.stopAdvertising();
        await _manager.removeAllServices();
      } catch (_) {
        // El manager puede no estar en un estado válido si nunca llegó a
        // anunciarse de verdad; no bloquea el apagado del simulador.
      }
      _advertising = false;
    }

    await fallbackServer.stop();
  }

  Future<void> _setupGattService() async {
    await _manager.removeAllServices();

    _stepsChar = GATTCharacteristic.mutable(
      uuid: UUID.fromString(BleConstants.stepsCharUuid),
      properties: [GATTCharacteristicProperty.notify],
      permissions: [],
      descriptors: [],
    );
    _heartRateChar = GATTCharacteristic.mutable(
      uuid: UUID.fromString(BleConstants.heartRateCharUuid),
      properties: [GATTCharacteristicProperty.notify],
      permissions: [],
      descriptors: [],
    );
    _caloriesChar = GATTCharacteristic.mutable(
      uuid: UUID.fromString(BleConstants.caloriesCharUuid),
      properties: [GATTCharacteristicProperty.notify],
      permissions: [],
      descriptors: [],
    );
    _statusChar = GATTCharacteristic.mutable(
      uuid: UUID.fromString(BleConstants.statusCharUuid),
      properties: [GATTCharacteristicProperty.notify],
      permissions: [],
      descriptors: [],
    );

    final service = GATTService(
      uuid: UUID.fromString(BleConstants.serviceUuid),
      isPrimary: true,
      includedServices: [],
      characteristics: [
        _stepsChar,
        _heartRateChar,
        _caloriesChar,
        _statusChar,
      ],
    );
    await _manager.addService(service);

    _notifySub = _manager.characteristicNotifyStateChanged.listen((
      eventArgs,
    ) {
      final subscribers = _subscribedCentrals.putIfAbsent(
        eventArgs.characteristic.uuid,
        () => {},
      );
      if (eventArgs.state) {
        subscribers.add(eventArgs.central);
        _notify(eventArgs.characteristic, _currentValueFor(eventArgs.characteristic));
      } else {
        subscribers.remove(eventArgs.central);
      }
    });
  }

  Uint8List _currentValueFor(GATTCharacteristic characteristic) {
    if (characteristic.uuid == _stepsChar.uuid) {
      return _int32LE(_simulator.currentSteps);
    }
    if (characteristic.uuid == _heartRateChar.uuid) {
      return Uint8List.fromList([_simulator.currentHeartRate & 0xFF]);
    }
    if (characteristic.uuid == _caloriesChar.uuid) {
      return _int16LE(_simulator.currentCalories);
    }
    return Uint8List.fromList(utf8.encode(_simulator.currentStatus));
  }

  void _notify(GATTCharacteristic characteristic, Uint8List value) {
    if (!_advertising) return;
    final subscribers = _subscribedCentrals[characteristic.uuid];
    if (subscribers == null || subscribers.isEmpty) return;
    for (final central in Set<Central>.of(subscribers)) {
      _manager
          .notifyCharacteristic(central, characteristic, value: value)
          .catchError((_) => subscribers.remove(central));
    }
  }

  Uint8List _int32LE(int value) {
    final data = ByteData(4)..setInt32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  Uint8List _int16LE(int value) {
    final data = ByteData(2)..setInt16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }
}
