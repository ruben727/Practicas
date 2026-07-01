import 'package:flutter/material.dart';

class ActivityData {
  final int steps;
  final int heartRate;
  final int calories;
  final String status;
  final DateTime timestamp;

  const ActivityData({
    required this.steps,
    required this.heartRate,
    required this.calories,
    required this.status,
    required this.timestamp,
  });

  factory ActivityData.empty() => ActivityData(
        steps: 0,
        heartRate: 0,
        calories: 0,
        status: '--',
        timestamp: DateTime.now(),
      );

  ActivityData copyWith({
    int? steps,
    int? heartRate,
    int? calories,
    String? status,
    DateTime? timestamp,
  }) =>
      ActivityData(
        steps:     steps     ?? this.steps,
        heartRate: heartRate ?? this.heartRate,
        calories:  calories  ?? this.calories,
        status:    status    ?? this.status,
        timestamp: timestamp ?? this.timestamp,
      );

  String get heartRateZone {
    if (heartRate < 60)  return 'Muy baja';
    if (heartRate < 90)  return 'Reposo';
    if (heartRate < 120) return 'Moderada';
    if (heartRate < 150) return 'Alta';
    return 'Máxima';
  }

  Color get heartRateColor {
    if (heartRate < 90)  return Colors.green;
    if (heartRate < 120) return Colors.amber;
    return Colors.red;
  }
}
