import 'package:flutter/material.dart';

import 'package:distance/features/home/home_screen.dart';

class DistanceApp extends StatelessWidget {
  const DistanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Distance',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.teal),
      ),
      home: const HomeScreen(),
    );
  }
}
