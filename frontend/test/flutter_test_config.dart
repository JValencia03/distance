import 'dart:async';

import 'package:distance/shared/motion.dart';
import 'package:distance/shared/scene3d.dart';

/// Runs before every test file (a `flutter_test` convention).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Looping animations never end, so `pumpAndSettle` would never settle.
  // Tests that check them turn this back on.
  AmbientMotion.enabled = false;
  // flutter_test has no GPU: 3D views show their 2D fallback.
  Scene3d.enabled = false;
  await testMain();
}
