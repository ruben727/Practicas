import 'dart:async';
import 'dart:math';

/// Simula los sensores de un wearable: pasos, ritmo cardiaco, calorías y
/// estado de actividad. Se actualiza cada segundo y expone un stream
/// broadcast por métrica para que capas superiores (BLE, WebSocket, UI)
/// puedan suscribirse de forma independiente.
class SensorSimulator {
  static const List<String> _activities = ['reposo', 'caminando', 'corriendo'];

  static const Map<String, int> _targetHeartRate = {
    'reposo': 72,
    'caminando': 95,
    'corriendo': 145,
  };

  final Random _random = Random();

  final StreamController<int> _stepsController =
      StreamController<int>.broadcast();
  final StreamController<int> _heartRateController =
      StreamController<int>.broadcast();
  final StreamController<int> _caloriesController =
      StreamController<int>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  Timer? _timer;

  int _steps = 0;
  int _heartRate = _targetHeartRate['reposo']!;
  double _calories = 0;
  String _status = 'reposo';
  int _ticksSinceStatusChange = 0;

  Stream<int> get stepsStream => _stepsController.stream;
  Stream<int> get heartRateStream => _heartRateController.stream;
  Stream<int> get caloriesStream => _caloriesController.stream;
  Stream<String> get statusStream => _statusController.stream;

  int get currentSteps => _steps;
  int get currentHeartRate => _heartRate;
  int get currentCalories => _calories.round();
  String get currentStatus => _status;

  bool get isRunning => _timer != null;

  void start() {
    if (isRunning) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _stepsController.close();
    _heartRateController.close();
    _caloriesController.close();
    _statusController.close();
  }

  void _tick() {
    _maybeChangeStatus();
    _updateSteps();
    _updateHeartRate();
    _updateCalories();
  }

  void _maybeChangeStatus() {
    _ticksSinceStatusChange++;
    if (_ticksSinceStatusChange < 25) return;
    if (_random.nextDouble() >= 0.15) return;

    final options = _activities.where((a) => a != _status).toList();
    _status = options[_random.nextInt(options.length)];
    _ticksSinceStatusChange = 0;
    _statusController.add(_status);
  }

  void _updateSteps() {
    final int increment;
    switch (_status) {
      case 'caminando':
        increment = 1 + _random.nextInt(2); // 1-2
        break;
      case 'corriendo':
        increment = 3 + _random.nextInt(4); // 3-6
        break;
      default:
        increment = 0;
    }
    if (increment == 0) return;
    _steps += increment;
    _stepsController.add(_steps);
  }

  void _updateHeartRate() {
    final target = _targetHeartRate[_status]!;
    final drift = _random.nextInt(7) - 3; // -3..+3
    final towardTarget = (target - _heartRate).sign * _random.nextInt(4);
    final next = (_heartRate + towardTarget + drift).clamp(40, 200).toInt();
    if (next == _heartRate) return;
    _heartRate = next;
    _heartRateController.add(_heartRate);
  }

  void _updateCalories() {
    if (_steps == 0) return;
    _calories += _steps * 0.00004;
    _caloriesController.add(_calories.round());
  }
}
