import 'package:flutter/material.dart';

/// Snapshot inmutable del estado de actividad recibido del wearable.
@immutable
class ActivityData {
  const ActivityData({
    required this.steps,
    required this.heartRate,
    required this.calories,
    required this.status,
    required this.timestamp,
  });

  final int steps;
  final int heartRate;
  final int calories;
  final String status;
  final DateTime timestamp;

  ActivityData copyWith({
    int? steps,
    int? heartRate,
    int? calories,
    String? status,
    DateTime? timestamp,
  }) {
    return ActivityData(
      steps: steps ?? this.steps,
      heartRate: heartRate ?? this.heartRate,
      calories: calories ?? this.calories,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  String get heartRateZone {
    if (heartRate < 60) return 'Muy baja';
    if (heartRate < 90) return 'Reposo';
    if (heartRate < 120) return 'Moderada';
    if (heartRate < 150) return 'Alta';
    return 'Maxima';
  }

  Color get heartRateColor {
    if (heartRate < 120) return Colors.green;
    if (heartRate < 150) return Colors.amber;
    return Colors.red;
  }

  static ActivityData initial() => ActivityData(
        steps: 0,
        heartRate: 0,
        calories: 0,
        status: 'reposo',
        timestamp: DateTime.now(),
      );
}
