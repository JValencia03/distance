import 'package:flutter/material.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/features/activities/activities_screen.dart';

class DistanceApp extends StatelessWidget {
  const DistanceApp({super.key, required this.api});

  final DistanceApi api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Distance',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.teal)),
      home: ActivitiesScreen(api: api),
    );
  }
}
