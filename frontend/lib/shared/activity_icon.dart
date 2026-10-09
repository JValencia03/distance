import 'package:flutter/material.dart';

/// Icon for an activity id from the server catalog, with a fallback for ids
/// the app does not know yet.
IconData activityIcon(String activityId) => switch (activityId) {
  'reading' => Icons.menu_book_outlined,
  'walking' => Icons.directions_walk,
  'running' => Icons.directions_run,
  'coffee' => Icons.local_cafe_outlined,
  'studying' => Icons.school_outlined,
  'gym' => Icons.fitness_center,
  'gaming' => Icons.sports_esports_outlined,
  'photography' => Icons.photo_camera_outlined,
  'eating' => Icons.restaurant_outlined,
  'exploring' => Icons.explore_outlined,
  _ => Icons.event_outlined,
};
