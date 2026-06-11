import 'package:flutter/material.dart';

class WeatherIcon extends StatelessWidget {
  final String condition;
  final double size;
  final Color? color;

  const WeatherIcon({
    Key? key,
    required this.condition,
    this.size = 80,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    
    switch (condition.toLowerCase()) {
      case 'sunny':
        iconData = Icons.wb_sunny;
        break;
      case 'cloudy':
        iconData = Icons.cloud;
        break;
      case 'rainy':
        iconData = Icons.umbrella;
        break;
      default:
        iconData = Icons.cloud_queue;
    }
    
    return Icon(
      iconData,
      size: size,
      color: color ?? Colors.blue,
    );
  }
}