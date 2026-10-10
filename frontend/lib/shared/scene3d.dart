import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Entry point to 3D rendering with flutter_scene, which draws through
/// Flutter GPU. Screens ask [ensureReady] before building a scene and show a
/// 2D fallback when it returns false.
abstract final class Scene3d {
  /// Whether 3D may be used at all. Widget tests turn it off: `flutter_test`
  /// has no GPU, so scenes cannot render there.
  static bool enabled = true;

  static Future<bool>? _ready;

  /// Initializes the engine's shared resources once. Completes with false
  /// when 3D is disabled or the device cannot render it, for example when
  /// Flutter GPU is not enabled for the platform.
  static Future<bool> ensureReady() {
    if (!enabled) return Future.value(false);
    return _ready ??= Scene.initializeStaticResources()
        .timeout(const Duration(seconds: 15))
        .then((_) => true)
        .catchError((Object error) {
          debugPrint('3D unavailable: $error');
          return false;
        });
  }
}

/// Converts a display (sRGB) color to the linear RGBA materials expect.
vm.Vector4 linearColor(Color color) {
  double channel(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return vm.Vector4(
    channel(color.r),
    channel(color.g),
    channel(color.b),
    color.a,
  );
}

/// A matte, slightly soft material, the look of every procedural model.
PhysicallyBasedMaterial clayMaterial(Color color, {double roughness = 0.7}) =>
    PhysicallyBasedMaterial()
      ..baseColorFactor = linearColor(color)
      ..metallicFactor = 0
      ..roughnessFactor = roughness;

/// A material that glows with [color], for markers that must stand out.
PhysicallyBasedMaterial glowMaterial(Color color, {double strength = 1.5}) {
  final linear = linearColor(color);
  return PhysicallyBasedMaterial()
    ..baseColorFactor = linear
    ..metallicFactor = 0
    ..roughnessFactor = 0.4
    ..emissiveFactor = vm.Vector4(
      linear.x * strength,
      linear.y * strength,
      linear.z * strength,
      1,
    );
}

/// A node holding [mesh] at [position], optionally rotated and scaled.
Node meshNode(
  Geometry geometry,
  Material material, {
  vm.Vector3? position,
  vm.Quaternion? rotation,
  vm.Vector3? scale,
  String name = '',
}) {
  final node = Node(name: name, mesh: Mesh(geometry, material));
  if (position != null) node.position = position;
  if (rotation != null) node.rotation = rotation;
  if (scale != null) node.scale = scale;
  return node;
}
