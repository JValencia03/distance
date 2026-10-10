import 'dart:math' as math;

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:distance/data/models.dart';
import 'package:distance/features/avatar/avatar_style.dart';
import 'package:distance/shared/scene3d.dart';

/// Height of a character from its feet (y = 0) to the top of its head,
/// without accessories, in world units.
const characterHeight = 1.1;

/// A character built for an [Avatar], with handles to the parts it animates.
///
/// Only the "basic" skin exists: a rounded body, a head and two arms built
/// from primitives and tinted by the avatar's colors. Future skins (imported
/// models) can be added here by switching on [Avatar.skin] while keeping the
/// same customization fields. Characters face local -Z.
class Character {
  Character._(
    this.root,
    this._torso,
    this._body,
    this._leftArm,
    this._rightArm,
  );

  factory Character.build(Avatar avatar) {
    final parts = _Parts.instance;
    final body = AvatarStyle.bodyColor(avatar.bodyColor);
    final skin = AvatarStyle.skinTone(avatar.skinTone);
    final bodyMaterial = _materials.clay(body);
    final skinMaterial = _materials.clay(skin, roughness: 0.6);
    final armMaterial = _materials.clay(Color.lerp(body, skin, 0.25)!);

    final root = Node(name: 'character');
    final torso = Node(name: 'torso');
    root.add(torso);

    final bodyNode = meshNode(
      parts.body,
      bodyMaterial,
      position: vm.Vector3(0, 0.36, 0),
      name: 'body',
    );
    torso.add(bodyNode);
    torso.add(
      meshNode(parts.head, skinMaterial, position: vm.Vector3(0, 0.88, 0)),
    );

    // A white eye behind a dark pupil reads on every skin tone. The head's
    // surface is at z ≈ -0.217 where the eyes sit; the pupil pokes out
    // further than the white so it stays in front.
    final white = _materials.clay(const Color(0xFFFFFFFF), roughness: 0.3);
    final pupil = _materials.clay(const Color(0xFF2B2B3A), roughness: 0.3);
    for (final side in [-1.0, 1.0]) {
      torso
        ..add(
          meshNode(
            parts.eyeWhite,
            white,
            position: vm.Vector3(0.075 * side, 0.9, -0.196),
          ),
        )
        ..add(
          meshNode(
            parts.eye,
            pupil,
            position: vm.Vector3(0.075 * side, 0.9, -0.222),
          ),
        );
    }
    final cheek = _materials.clay(const Color(0xFFFF9AA2));
    for (final side in [-1.0, 1.0]) {
      torso.add(
        meshNode(
          parts.cheek,
          cheek,
          position: vm.Vector3(0.13 * side, 0.83, -0.17),
          scale: vm.Vector3(1, 0.6, 0.4),
        ),
      );
    }

    // Arms hang from a shoulder pivot so they can swing.
    Node arm(double side) {
      final pivot = Node(name: 'arm')
        ..position = vm.Vector3(0.25 * side, 0.55, 0);
      pivot.add(
        meshNode(
          parts.arm,
          armMaterial,
          position: vm.Vector3(0.02 * side, -0.14, 0),
        ),
      );
      torso.add(pivot);
      return pivot;
    }

    final leftArm = arm(-1);
    final rightArm = arm(1);
    _addAccessory(torso, avatar.accessory, parts);
    return Character._(root, torso, bodyNode, leftArm, rightArm);
  }

  /// Add this to a scene or a parent node.
  final Node root;
  final Node _torso;
  final Node _body;
  final Node _leftArm;
  final Node _rightArm;

  /// Poses the character at [seconds] since it appeared. [lively] characters
  /// (in a plan that is happening now) hop and wave; the rest breathe gently.
  /// [phase] offsets the cycle so neighbours do not move in sync.
  void animate(double seconds, {required bool lively, double phase = 0}) {
    final t = seconds + phase;
    if (lively) {
      final hop = math.sin(t * 5).abs() * 0.07;
      _torso.position = vm.Vector3(0, hop, 0);
      _leftArm.rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 0, 1),
        -0.25 - 0.2 * math.sin(t * 5),
      );
      _rightArm.rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 0, 1),
        0.6 + 0.9 * (0.5 + 0.5 * math.sin(t * 6)),
      );
    } else {
      final breath = 1 + 0.025 * math.sin(t * 2);
      _body.scale = vm.Vector3(
        1 / math.sqrt(breath),
        breath,
        1 / math.sqrt(breath),
      );
      _leftArm.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -0.12);
      _rightArm.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), 0.12);
    }
  }
}

void _addAccessory(Node torso, String accessory, _Parts parts) {
  switch (accessory) {
    case 'cap':
      final color = _materials.clay(const Color(0xFFE85D75));
      torso
        ..add(meshNode(parts.capCrown, color, position: vm.Vector3(0, 1.02, 0)))
        ..add(
          meshNode(parts.capButton, color, position: vm.Vector3(0, 1.125, 0)),
        )
        // The brim sticks out over the eyes (y = 0.9).
        ..add(
          meshNode(parts.capBrim, color, position: vm.Vector3(0, 0.945, -0.25)),
        );
    case 'beanie':
      final color = _materials.clay(const Color(0xFF5B8DEF));
      torso
        ..add(meshNode(parts.beanie, color, position: vm.Vector3(0, 1.03, 0)))
        ..add(
          meshNode(parts.beanieCuff, color, position: vm.Vector3(0, 0.935, 0)),
        )
        ..add(
          meshNode(
            parts.pompom,
            _materials.clay(const Color(0xFFFFFFFF)),
            position: vm.Vector3(0, 1.17, 0),
          ),
        );
    case 'headphones':
      final color = _materials.clay(const Color(0xFF3A3A4A), roughness: 0.4);
      torso.add(
        meshNode(
          parts.headband,
          color,
          position: vm.Vector3(0, 0.9, 0),
          // The torus lies in XZ; stand it up across the head.
          rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 2),
        ),
      );
      for (final side in [-1.0, 1.0]) {
        torso.add(
          meshNode(
            parts.earCup,
            _materials.clay(const Color(0xFFFF6F91)),
            position: vm.Vector3(0.23 * side, 0.88, 0),
            rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 2),
          ),
        );
      }
    case 'flower':
      final petal = _materials.clay(const Color(0xFFFFB3D1));
      const center = (x: 0.15, y: 1.03, z: -0.08);
      for (var i = 0; i < 5; i++) {
        final angle = i * 2 * math.pi / 5;
        torso.add(
          meshNode(
            parts.petal,
            petal,
            position: vm.Vector3(
              center.x + 0.045 * math.cos(angle),
              center.y + 0.045 * math.sin(angle),
              center.z - 0.01,
            ),
          ),
        );
      }
      torso.add(
        meshNode(
          parts.petal,
          _materials.clay(const Color(0xFFFFD166)),
          position: vm.Vector3(center.x, center.y, center.z - 0.03),
        ),
      );
    case 'glasses':
      final frame = _materials.clay(const Color(0xFF2B2B3A), roughness: 0.3);
      for (final side in [-1.0, 1.0]) {
        torso.add(
          meshNode(
            parts.lens,
            frame,
            position: vm.Vector3(0.08 * side, 0.9, -0.215),
            // Face the lenses forward (-Z).
            rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2),
          ),
        );
      }
      torso.add(
        meshNode(parts.bridge, frame, position: vm.Vector3(0, 0.905, -0.225)),
      );
  }
}

/// Geometry shared by every character, built after the engine is ready.
class _Parts {
  _Parts._();

  static final instance = _Parts._();

  final body = CapsuleGeometry(
    radius: 0.24,
    height: 0.2,
    radialSegments: 24,
    capRings: 6,
  );
  final head = SphereGeometry(radius: 0.23, segments: 24, rings: 14);
  final eye = SphereGeometry(radius: 0.026, segments: 10, rings: 6);
  final eyeWhite = SphereGeometry(radius: 0.042, segments: 12, rings: 8);
  final cheek = SphereGeometry(radius: 0.04, segments: 10, rings: 6);
  final arm = CapsuleGeometry(
    radius: 0.055,
    height: 0.16,
    radialSegments: 10,
    capRings: 4,
  );
  // Hats sit on the upper head: at y = 0.92 the head is 0.226 wide and its
  // top is at 1.11, so a 0.2 tall crown centered at 1.02 covers it.
  final capCrown = CylinderGeometry(
    bottomRadius: 0.228,
    topRadius: 0.13,
    height: 0.2,
    radialSegments: 24,
  );
  final capButton = SphereGeometry(radius: 0.03, segments: 10, rings: 6);
  final capBrim = CuboidGeometry(vm.Vector3(0.26, 0.025, 0.16));
  final beanie = CylinderGeometry(
    bottomRadius: 0.232,
    topRadius: 0.11,
    height: 0.22,
    radialSegments: 24,
  );
  final beanieCuff = TorusGeometry(
    radius: 0.228,
    tubeRadius: 0.03,
    radialSegments: 24,
    tubularSegments: 8,
  );
  final pompom = SphereGeometry(radius: 0.06, segments: 12, rings: 8);
  final headband = TorusGeometry(
    radius: 0.235,
    tubeRadius: 0.022,
    radialSegments: 24,
    tubularSegments: 8,
  );
  final earCup = CylinderGeometry(
    bottomRadius: 0.07,
    topRadius: 0.07,
    height: 0.06,
    radialSegments: 16,
  );
  final petal = SphereGeometry(radius: 0.032, segments: 10, rings: 6);
  final lens = TorusGeometry(
    radius: 0.055,
    tubeRadius: 0.011,
    radialSegments: 16,
    tubularSegments: 6,
  );
  final bridge = CuboidGeometry(vm.Vector3(0.05, 0.012, 0.012));
}

/// Materials shared by every character with the same color, so a crowd of
/// characters does not create hundreds of identical materials.
final _materials = _MaterialCache();

class _MaterialCache {
  final _clay = <(int, double), PhysicallyBasedMaterial>{};

  PhysicallyBasedMaterial clay(Color color, {double roughness = 0.7}) =>
      _clay.putIfAbsent((
        color.toARGB32(),
        roughness,
      ), () => clayMaterial(color, roughness: roughness));
}
