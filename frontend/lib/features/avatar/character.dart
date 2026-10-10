import 'dart:math' as math;

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:distance/data/models.dart';
import 'package:distance/features/avatar/avatar_style.dart';
import 'package:distance/shared/scene3d.dart';

/// Height of a character from its feet (y = 0) to the top of its head,
/// without accessories, in model units.
const characterHeight = 1.1;

/// The pieces of the "basic" skin: a rounded body, a head, two arms and the
/// accessories, built from primitives and tinted by the avatar's colors.
/// Characters face local -Z.
///
/// Both renderers draw from this one definition: [Character] for a single
/// character with its own nodes, and [Crowd] for many characters drawn with
/// one instanced mesh per piece. Future skins (imported models) can be
/// added by switching on [Avatar.skin] here while keeping the same
/// customization fields.
class CharacterKit {
  CharacterKit._() {
    final p = _Geometries();
    _Piece piece(
      String id,
      Geometry geometry,
      double x,
      double y,
      double z, {
      _Limb limb = _Limb.head,
      vm.Quaternion? rotation,
      vm.Vector3? scale,
      required Color Function(Avatar) color,
      double roughness = 0.7,
    }) => _Piece(
      _shapes.putIfAbsent(id, () => _Shape(geometry, roughness)),
      vm.Matrix4.compose(
        vm.Vector3(x, y, z),
        rotation ?? vm.Quaternion.identity(),
        scale ?? vm.Vector3.all(1),
      ),
      color,
      limb,
    );

    Color body(Avatar a) => AvatarStyle.bodyColor(a.bodyColor);
    Color skin(Avatar a) => AvatarStyle.skinTone(a.skinTone);
    Color arm(Avatar a) => Color.lerp(body(a), skin(a), 0.25)!;
    Color Function(Avatar) fixed(int argb) =>
        (_) => Color(argb);
    final standUp = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 2);
    final faceForward = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      math.pi / 2,
    );

    _base = [
      piece('body', p.body, 0, 0.36, 0, limb: _Limb.body, color: body),
      piece('head', p.head, 0, 0.88, 0, color: skin, roughness: 0.6),
      // A white eye behind a dark pupil reads on every skin tone. The
      // head's surface is at z ≈ -0.217 there; the pupil pokes out
      // further than the white so it stays in front.
      for (final side in [-1.0, 1.0]) ...[
        piece(
          'eyeWhite',
          p.eyeWhite,
          0.075 * side,
          0.9,
          -0.196,
          color: fixed(0xFFFFFFFF),
          roughness: 0.3,
        ),
        piece(
          'pupil',
          p.pupil,
          0.075 * side,
          0.9,
          -0.222,
          color: fixed(0xFF2B2B3A),
          roughness: 0.3,
        ),
        piece(
          'cheek',
          p.cheek,
          0.13 * side,
          0.83,
          -0.17,
          scale: vm.Vector3(1, 0.6, 0.4),
          color: fixed(0xFFFF9AA2),
        ),
      ],
      // Arms hang from shoulder pivots so they can swing.
      piece('arm', p.arm, -0.02, -0.14, 0, limb: _Limb.leftArm, color: arm),
      piece('arm', p.arm, 0.02, -0.14, 0, limb: _Limb.rightArm, color: arm),
    ];

    // Hats sit on the upper head: at y = 0.92 the head is 0.226 wide and
    // its top is at 1.11, so a 0.2 tall crown centered at 1.02 covers it.
    final capColor = fixed(0xFFE85D75);
    final beanieColor = fixed(0xFF5B8DEF);
    final dark = fixed(0xFF2B2B3A);
    const flower = (x: 0.15, y: 1.03, z: -0.08);
    _accessories = {
      'cap': [
        piece('capCrown', p.capCrown, 0, 1.02, 0, color: capColor),
        piece('button', p.button, 0, 1.125, 0, color: capColor),
        // The brim sticks out over the eyes (y = 0.9).
        piece('capBrim', p.capBrim, 0, 0.945, -0.25, color: capColor),
      ],
      'beanie': [
        piece('beanie', p.beanie, 0, 1.03, 0, color: beanieColor),
        piece('cuff', p.cuff, 0, 0.935, 0, color: beanieColor),
        piece('pompom', p.pompom, 0, 1.17, 0, color: fixed(0xFFFFFFFF)),
      ],
      'headphones': [
        piece(
          'headband',
          p.headband,
          0,
          0.9,
          0,
          // The torus lies in XZ; stand it up across the head.
          rotation: standUp,
          color: dark,
          roughness: 0.4,
        ),
        for (final side in [-1.0, 1.0])
          piece(
            'earCup',
            p.earCup,
            0.23 * side,
            0.88,
            0,
            rotation: standUp,
            color: fixed(0xFFFF6F91),
          ),
      ],
      'flower': [
        for (var i = 0; i < 5; i++)
          piece(
            'petal',
            p.petal,
            flower.x + 0.045 * math.cos(i * 2 * math.pi / 5),
            flower.y + 0.045 * math.sin(i * 2 * math.pi / 5),
            flower.z - 0.01,
            color: fixed(0xFFFFB3D1),
          ),
        piece(
          'petal',
          p.petal,
          flower.x,
          flower.y,
          flower.z - 0.03,
          color: fixed(0xFFFFD166),
        ),
      ],
      'glasses': [
        for (final side in [-1.0, 1.0])
          piece(
            'lens',
            p.lens,
            0.08 * side,
            0.9,
            -0.24,
            // Face the lenses forward (-Z).
            rotation: faceForward,
            color: dark,
            roughness: 0.3,
          ),
        piece(
          'bridge',
          p.bridge,
          0,
          0.905,
          -0.245,
          color: dark,
          roughness: 0.3,
        ),
      ],
    };
  }

  /// The kit, built on first use; geometry needs the 3D engine ready.
  static final instance = CharacterKit._();

  final _shapes = <String, _Shape>{};
  late final List<_Piece> _base;
  late final Map<String, List<_Piece>> _accessories;

  List<_Piece> _piecesOf(Avatar avatar) => [
    ..._base,
    ...?_accessories[avatar.accessory],
  ];
}

/// Parts of the body that move on their own.
enum _Limb { body, head, leftArm, rightArm }

/// A geometry and its surface; every piece drawn with it shares one
/// material (or one instanced mesh in a [Crowd]) and is tinted per piece.
class _Shape {
  _Shape(this.geometry, this.roughness);

  final Geometry geometry;
  final double roughness;
}

class _Piece {
  _Piece(this.shape, this.local, this.color, this.limb);

  final _Shape shape;

  /// Placement relative to its limb.
  final vm.Matrix4 local;
  final Color Function(Avatar) color;
  final _Limb limb;
}

/// How a character stands at one instant.
class _Pose {
  _Pose(double seconds, {required bool lively, double phase = 0}) {
    final t = seconds + phase;
    if (lively) {
      hop = math.sin(t * 5).abs() * 0.07;
      leftArm = -0.25 - 0.2 * math.sin(t * 5);
      rightArm = 0.6 + 0.9 * (0.5 + 0.5 * math.sin(t * 6));
      breath = 1;
    } else {
      hop = 0;
      leftArm = -0.12;
      rightArm = 0.12;
      breath = 1 + 0.025 * math.sin(t * 2);
    }
  }

  late final double hop;
  late final double leftArm;
  late final double rightArm;
  late final double breath;

  /// Multiplies [out] by the transform from a limb's space to the
  /// character's, in place.
  void applyLimb(_Limb limb, vm.Matrix4 out) {
    out.translateByDouble(0, hop, 0, 1);
    switch (limb) {
      case _Limb.head:
        break;
      case _Limb.body:
        // Breathe around the body's center, keeping its volume.
        final thin = 1 / math.sqrt(breath);
        out
          ..translateByDouble(0, 0.36, 0, 1)
          ..scaleByDouble(thin, breath, thin, 1)
          ..translateByDouble(0, -0.36, 0, 1);
      case _Limb.leftArm || _Limb.rightArm:
        final left = limb == _Limb.leftArm;
        out
          ..translateByDouble(left ? -0.25 : 0.25, 0.55, 0, 1)
          ..rotateZ(left ? leftArm : rightArm);
    }
  }
}

/// One character with its own nodes, for showing a single avatar.
class Character {
  Character._(this.root, this._nodes);

  factory Character.build(Avatar avatar) {
    final root = Node(name: 'character');
    final nodes = <(Node, _Piece)>[];
    for (final piece in CharacterKit.instance._piecesOf(avatar)) {
      final node = Node(
        mesh: Mesh(
          piece.shape.geometry,
          _materials.clay(piece.color(avatar), piece.shape.roughness),
        ),
      );
      root.add(node);
      nodes.add((node, piece));
    }
    final character = Character._(root, nodes);
    character.animate(0, lively: false);
    return character;
  }

  /// Add this to a scene or a parent node.
  final Node root;
  final List<(Node, _Piece)> _nodes;

  /// Poses the character at [seconds] since it appeared. [lively] characters
  /// (in a plan that is happening now) hop and wave; the rest breathe gently.
  /// [phase] offsets the cycle so neighbours do not move in sync.
  void animate(double seconds, {required bool lively, double phase = 0}) {
    final pose = _Pose(seconds, lively: lively, phase: phase);
    for (final (node, piece) in _nodes) {
      final transform = vm.Matrix4.identity();
      pose.applyLimb(piece.limb, transform);
      node.localTransform = transform..multiply(piece.local);
    }
  }
}

/// Where a crowd member stands and how it moves.
class CrowdMember {
  const CrowdMember({
    required this.avatar,
    required this.position,
    required this.lively,
    required this.phase,
  });

  final Avatar avatar;
  final vm.Vector3 position;
  final bool lively;
  final double phase;
}

/// Many characters drawn with one instanced mesh per piece of the kit, so
/// the cost in draw calls stays the same however many people the map
/// shows. Each frame only rewrites instance matrices in place.
class Crowd {
  Crowd({required this.scale}) {
    for (final shape in CharacterKit.instance._shapes.values) {
      final mesh = InstancedMesh(
        geometry: shape.geometry,
        material: clayMaterial(
          const Color(0xFFFFFFFF),
          roughness: shape.roughness,
        ),
      );
      _meshes[shape] = mesh;
      root.add(Node()..addComponent(InstancedMeshComponent(mesh)));
    }
  }

  /// Size of a character in world units per model unit.
  final double scale;
  final root = Node(name: 'crowd');
  final _meshes = <_Shape, InstancedMesh>{};

  /// Per shape, which member and piece each instance draws, in order.
  final _instances = <_Shape, List<(int, _Piece)>>{};
  var _members = const <CrowdMember>[];

  /// Scratch matrices reused every frame: one per member and limb.
  var _limbs = <vm.Matrix4>[];

  void setMembers(List<CrowdMember> members) {
    _members = members;
    _limbs = [
      for (var i = 0; i < members.length * _Limb.values.length; i++)
        vm.Matrix4.identity(),
    ];
    for (final mesh in _meshes.values) {
      mesh.clearInstances();
    }
    _instances.clear();
    for (final (m, member) in members.indexed) {
      for (final piece in CharacterKit.instance._piecesOf(member.avatar)) {
        _meshes[piece.shape]!.addInstance(
          vm.Matrix4.identity(),
          color: linearColor(piece.color(member.avatar)),
        );
        _instances.putIfAbsent(piece.shape, () => []).add((m, piece));
      }
    }
    update(0, facing: 0);
  }

  /// Poses every member at [seconds], turned by [facing] radians around
  /// the vertical axis (towards the camera).
  void update(double seconds, {required double facing}) {
    final turn = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), facing);
    final size = vm.Vector3.all(scale);
    const limbCount = 4; // _Limb.values.length, without allocating.
    // Limb transforms are shared by every piece on that limb, so compute
    // them once per member into the scratch matrices.
    for (final (m, member) in _members.indexed) {
      final pose = _Pose(seconds, lively: member.lively, phase: member.phase);
      for (final limb in _Limb.values) {
        final out = _limbs[m * limbCount + limb.index]
          ..setFromTranslationRotationScale(member.position, turn, size);
        pose.applyLimb(limb, out);
      }
    }
    for (final MapEntry(key: shape, value: entries) in _instances.entries) {
      _meshes[shape]!.updateInstanceTransforms((transforms) {
        for (final (i, (member, piece)) in entries.indexed) {
          transforms[i]
            ..setFrom(_limbs[member * limbCount + piece.limb.index])
            ..multiply(piece.local);
        }
      });
    }
  }
}

/// Geometry of the kit, built after the engine is ready.
class _Geometries {
  final body = CapsuleGeometry(
    radius: 0.24,
    height: 0.2,
    radialSegments: 24,
    capRings: 6,
  );
  final head = SphereGeometry(radius: 0.23, segments: 24, rings: 14);
  final eyeWhite = SphereGeometry(radius: 0.042, segments: 12, rings: 8);
  final pupil = SphereGeometry(radius: 0.026, segments: 10, rings: 6);
  final cheek = SphereGeometry(radius: 0.04, segments: 10, rings: 6);
  final arm = CapsuleGeometry(
    radius: 0.055,
    height: 0.16,
    radialSegments: 10,
    capRings: 4,
  );
  final capCrown = CylinderGeometry(
    bottomRadius: 0.228,
    topRadius: 0.13,
    height: 0.2,
    radialSegments: 24,
  );
  final button = SphereGeometry(radius: 0.03, segments: 10, rings: 6);
  final capBrim = CuboidGeometry(vm.Vector3(0.26, 0.025, 0.16));
  final beanie = CylinderGeometry(
    bottomRadius: 0.232,
    topRadius: 0.11,
    height: 0.22,
    radialSegments: 24,
  );
  final cuff = TorusGeometry(
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

/// Materials shared by single characters with the same color.
final _materials = _MaterialCache();

class _MaterialCache {
  final _clay = <(int, double), PhysicallyBasedMaterial>{};

  PhysicallyBasedMaterial clay(Color color, double roughness) =>
      _clay.putIfAbsent((
        color.toARGB32(),
        roughness,
      ), () => clayMaterial(color, roughness: roughness));
}
