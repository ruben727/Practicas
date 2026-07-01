/// UUIDs compartidos entre wearable_app y telefono_app.
///
/// Deben ser idénticos en ambos proyectos: si cambias uno aquí, cambia
/// también su copia en wearable_app/lib/ble_constants.dart.
class BleConstants {
  BleConstants._();

  static const String serviceUuid = '12345678-1234-1234-1234-123456789abc';

  /// int32 little-endian.
  static const String stepsCharUuid = 'aaaaaaaa-0001-1234-1234-123456789abc';

  /// uint8, latidos por minuto.
  static const String heartRateCharUuid =
      'aaaaaaaa-0002-1234-1234-123456789abc';

  /// int16 little-endian.
  static const String caloriesCharUuid =
      'aaaaaaaa-0003-1234-1234-123456789abc';

  /// string utf8: 'reposo' | 'caminando' | 'corriendo'.
  static const String statusCharUuid = 'aaaaaaaa-0004-1234-1234-123456789abc';
}
