import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/activity_provider.dart';
import 'screens/monitor_screen.dart';

void main() {
  runApp(const TelefonoApp());
}

class TelefonoApp extends StatelessWidget {
  const TelefonoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ActivityProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Monitor Actividad',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
        ),
        home: const MonitorScreen(),
      ),
    );
  }
}
