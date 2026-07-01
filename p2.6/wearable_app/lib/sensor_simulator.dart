import 'dart:async';
import 'dart:math';

class SensorSimulator {
  static const List<String> _activities = ['reposo', 'caminando', 'corriendo'];

  final _rand = Random();

  int _steps = 0;
  int _heartRate = 72;
  double _calories = 0.0;
  String _status = 'reposo';
  int _statusCounter = 0;

  final _stepsCtrl     = StreamController<int>.broadcast();
  final _heartRateCtrl = StreamController<int>.broadcast();
  final _caloriesCtrl  = StreamController<double>.broadcast();
  final _statusCtrl    = StreamController<String>.broadcast();

  Stream<int>    get stepsStream    => _stepsCtrl.stream;
  Stream<int>    get heartRateStream => _heartRateCtrl.stream;
  Stream<double> get caloriesStream => _caloriesCtrl.stream;
  Stream<String> get statusStream   => _statusCtrl.stream;

  int    get steps     => _steps;
  int    get heartRate => _heartRate;
  double get calories  => _calories;
  String get status    => _status;

  Timer? _timer;
  bool get isRunning => _timer != null;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick(Timer _) {
    _statusCounter++;

    // Random activity change ~every 30 s (30% chance after 30 ticks)
    if (_statusCounter >= 30 && _rand.nextDouble() < 0.3) {
      _statusCounter = 0;
      final next = _activities[_rand.nextInt(_activities.length)];
      if (next != _status) {
        _status = next;
        _statusCtrl.add(_status);
      }
    }

    // Steps per tick based on activity
    final int stepInc = switch (_status) {
      'caminando' => 1 + _rand.nextInt(2),   // 1-2 steps
      'corriendo' => 3 + _rand.nextInt(4),   // 3-6 steps
      _           => 0,                       // reposo
    };
    _steps += stepInc;
    _stepsCtrl.add(_steps);

    // Heart rate drifts toward target ±3 bpm/tick
    final int target = switch (_status) {
      'caminando' => 95,
      'corriendo' => 145,
      _           => 72,
    };
    final int noise = _rand.nextInt(7) - 3; // -3..+3
    final int drift = _heartRate < target ? 2 : (_heartRate > target ? -2 : 0);
    _heartRate = (_heartRate + noise + drift).clamp(45, 210);
    _heartRateCtrl.add(_heartRate);

    // Calories ~0.04 kcal/step (displayed as integer kcal)
    _calories += stepInc * 0.04;
    _caloriesCtrl.add(_calories);
  }

  void dispose() {
    stop();
    _stepsCtrl.close();
    _heartRateCtrl.close();
    _caloriesCtrl.close();
    _statusCtrl.close();
  }
}
