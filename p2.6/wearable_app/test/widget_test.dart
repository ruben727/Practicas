import 'package:flutter_test/flutter_test.dart';
import 'package:wearable_app/sensor_simulator.dart';

// El widget principal (WatchScreen) instancia BleServer -> PeripheralManager,
// que requiere un canal de plataforma real (Android/iOS) y no está
// disponible en el harness de `flutter test`. Por eso la prueba de humo se
// enfoca en SensorSimulator, que no depende de ningún plugin nativo.
void main() {
  test('En reposo no acumula pasos ni calorías', () async {
    final simulator = SensorSimulator();
    simulator.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(simulator.currentStatus, 'reposo');
    expect(simulator.currentSteps, 0);
    expect(simulator.currentCalories, 0);
    simulator.dispose();
  });

  test('Los streams emiten valores dentro de rangos válidos', () async {
    final simulator = SensorSimulator();
    final heartRates = <int>[];
    final sub = simulator.heartRateStream.listen(heartRates.add);

    simulator.start();
    await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 100));
    simulator.stop();
    await sub.cancel();
    simulator.dispose();

    for (final bpm in heartRates) {
      expect(bpm, inInclusiveRange(40, 200));
    }
  });
}
