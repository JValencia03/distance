import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import 'package:distance/data/models.dart';
import 'package:distance/features/avatar/avatar_badge.dart';
import 'package:distance/features/avatar/character.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/shared/scene3d.dart';

/// Shows [avatar] as a 3D character on a slowly turning stand that the user
/// can also spin by dragging. Falls back to a flat [AvatarBadge] when the
/// device cannot render 3D.
class CharacterPreview extends StatefulWidget {
  const CharacterPreview({super.key, required this.avatar});

  final Avatar avatar;

  @override
  State<CharacterPreview> createState() => _CharacterPreviewState();
}

class _CharacterPreviewState extends State<CharacterPreview> {
  late final Future<bool> _ready = Scene3d.ensureReady();
  Scene? _scene;
  final _turntable = Node(name: 'turntable');
  Character? _character;

  /// Rotation added by dragging, on top of the slow automatic turn.
  double _dragYaw = 0;

  @override
  void didUpdateWidget(CharacterPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatar != widget.avatar && _scene != null) _setCharacter();
  }

  Scene _buildScene() {
    final scene = Scene();
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.4, -1, 0.5),
      intensity: 3,
      castsShadow: true,
    );
    scene.environmentSettings = EnvironmentSettings(
      toneMapping: ToneMappingMode.aces,
      exposure: 1.1,
    );
    final stand = meshNode(
      CylinderGeometry(bottomRadius: 0.55, topRadius: 0.5, height: 0.08),
      clayMaterial(const Color(0xFFEDE7F6)),
      position: vm.Vector3(0, -0.04, 0),
    );
    scene.add(stand);
    scene.add(_turntable);
    _scene = scene;
    _setCharacter();
    return scene;
  }

  void _setCharacter() {
    final old = _character;
    if (old != null) _turntable.remove(old.root);
    final character = Character.build(widget.avatar);
    _turntable.add(character.root);
    _character = character;
  }

  void _tick(Duration elapsed, double deltaSeconds) {
    final seconds = elapsed.inMicroseconds / 1e6;
    _turntable.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      seconds * 0.4 + _dragYaw,
    );
    _character?.animate(seconds, lively: false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _ready,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data == false) return _Fallback(avatar: widget.avatar);
        final scene = _scene ?? _buildScene();
        return GestureDetector(
          onHorizontalDragUpdate: (details) =>
              _dragYaw += details.delta.dx * 0.012,
          child: SceneView(
            scene,
            camera: PerspectiveCamera(
              fovRadiansY: 30 * vm.degrees2Radians,
              position: vm.Vector3(0, 1.0, -3.4),
              target: vm.Vector3(0, 0.55, 0),
            ),
            onTick: _tick,
          ),
        );
      },
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.avatar});

  final Avatar avatar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AvatarBadge(avatar: avatar, size: math.max(48, size * 0.6)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                AppLocalizations.of(context).preview3dUnavailable,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}
