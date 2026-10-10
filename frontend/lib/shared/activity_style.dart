import 'package:flutter/material.dart';

import 'package:distance/shared/emoji.dart';

/// Visual identity of an activity id from the server catalog: a 3D emoji, a
/// pastel tint and a small line icon. Unknown ids get neutral fallbacks, so
/// new activities added on the server still render.
class ActivityStyle {
  const ActivityStyle._(this.emoji, this._tint, this.icon);

  factory ActivityStyle.of(String activityId) =>
      _styles[activityId] ?? _fallback;

  /// Asset path of the 3D emoji.
  final String emoji;
  final Color _tint;

  /// Line icon for compact places, such as detail rows.
  final IconData icon;

  /// Pastel background for the activity. In dark mode it is blended into
  /// the surface so it reads as a muted tone instead of a bright patch.
  Color tint(ColorScheme colors) => colors.brightness == Brightness.light
      ? _tint
      : Color.lerp(_tint, colors.surface, 0.6)!;

  static const _fallback = ActivityStyle._(
    Emojis.calendar,
    Color(0xFFEADFF5),
    Icons.event_outlined,
  );

  static const _styles = {
    'reading': ActivityStyle._(
      'assets/emoji/reading.png',
      Color(0xFFDCD3FF),
      Icons.menu_book_outlined,
    ),
    'walking': ActivityStyle._(
      'assets/emoji/walking.png',
      Color(0xFFCDEFD9),
      Icons.directions_walk,
    ),
    'running': ActivityStyle._(
      'assets/emoji/running.png',
      Color(0xFFFFD3C4),
      Icons.directions_run,
    ),
    'coffee': ActivityStyle._(
      'assets/emoji/coffee.png',
      Color(0xFFFBE0C3),
      Icons.local_cafe_outlined,
    ),
    'studying': ActivityStyle._(
      'assets/emoji/studying.png',
      Color(0xFFCFE4FF),
      Icons.school_outlined,
    ),
    'gym': ActivityStyle._(
      'assets/emoji/gym.png',
      Color(0xFFFFD0E1),
      Icons.fitness_center,
    ),
    'gaming': ActivityStyle._(
      'assets/emoji/gaming.png',
      Color(0xFFE9D0FF),
      Icons.sports_esports_outlined,
    ),
    'photography': ActivityStyle._(
      'assets/emoji/photography.png',
      Color(0xFFFFF0B8),
      Icons.photo_camera_outlined,
    ),
    'eating': ActivityStyle._(
      'assets/emoji/eating.png',
      Color(0xFFFFCFCB),
      Icons.restaurant_outlined,
    ),
    'exploring': ActivityStyle._(
      'assets/emoji/exploring.png',
      Color(0xFFC6EEF0),
      Icons.explore_outlined,
    ),
  };
}

/// Hero tag shared by an activity's emoji on the home grid and the plans
/// screen, so it flies between them.
Object activityHeroTag(String activityId) => 'activity-emoji-$activityId';

/// Hero tag of a plan's emoji, shared by its card and its detail screen.
Object planHeroTag(String planId) => 'plan-emoji-$planId';
