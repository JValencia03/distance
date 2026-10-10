import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import 'package:distance/features/avatar/avatar_badge.dart';
import 'package:distance/features/avatar/character.dart';
import 'package:distance/features/map/map_layout.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/shared/activity_style.dart';
import 'package:distance/shared/clay.dart';
import 'package:distance/shared/emoji.dart';
import 'package:distance/shared/formatting.dart';
import 'package:distance/shared/motion.dart';
import 'package:distance/shared/scene3d.dart';

/// Turns a world position into a point on the view, or null when it is not
/// visible.
typedef WorldProjector = Offset? Function(vm.Vector3 world);

/// Color of everything that says "happening now" on the map.
const liveColor = Color(0xFFFF4D6D);

/// The plans map: islands for zones and the participants' characters, as a
/// 3D scene the user can pan, zoom and turn, or as a flat top-down map on
/// devices without 3D. Tapping a group calls [onClusterTap].
class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.layout,
    required this.onClusterTap,
    this.focusZoneId,
  });

  final MapLayout layout;
  final ValueChanged<MapCluster> onClusterTap;

  /// Zone the 3D camera starts over, usually the user's.
  final String? focusZoneId;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late final Future<bool> _ready = Scene3d.ensureReady();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _ready,
      builder: (context, snapshot) => switch (snapshot.data) {
        null => const Center(child: CircularProgressIndicator()),
        true => _Map3d(
          layout: widget.layout,
          focusZoneId: widget.focusZoneId,
          onClusterTap: widget.onClusterTap,
        ),
        false => _Map2d(
          layout: widget.layout,
          onClusterTap: widget.onClusterTap,
        ),
      },
    );
  }
}

/// Sky behind both map views.
class _Sky extends StatelessWidget {
  const _Sky();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF1E2140), Color(0xFF3A3561)]
              : const [Color(0xFFBFE3FF), Color(0xFFFDEFF6)],
        ),
      ),
    );
  }
}

/// Tap targets and labels drawn over either view: a bubble above each
/// cluster and the name of each zone.
class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.layout,
    required this.project,
    required this.bubbleLift,
    required this.labelOffset,
    required this.onClusterTap,
  });

  final MapLayout layout;
  final WorldProjector project;

  /// Height above a cluster's center where its bubble points.
  final double bubbleLift;

  /// Where a zone's name goes relative to its island's center.
  final vm.Vector3 labelOffset;
  final ValueChanged<MapCluster> onClusterTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (final island in layout.zones)
          if (project(island.center + labelOffset) case final at?)
            Positioned(
              left: at.dx,
              top: at.dy,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      island.zone.name,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ),
              ),
            ),
        for (final (cluster, at) in _placeBubbles())
          Positioned(
            left: at.dx,
            top: at.dy,
            child: FractionalTranslation(
              // Anchor the bubble's bottom center on the point.
              translation: const Offset(-0.5, -1),
              child: ClusterBubble(
                cluster: cluster,
                onTap: () => onClusterTap(cluster),
              ),
            ),
          ),
      ],
    );
  }

  /// Approximate size of a bubble, enough to keep them from overlapping.
  static const _bubbleSize = Size(170, 40);

  /// Where each visible bubble goes: above its cluster, moved up while it
  /// would cover a bubble already placed. Bubbles nearer the bottom of the
  /// view (closer to the camera) are placed first and stay put.
  List<(MapCluster, Offset)> _placeBubbles() {
    final anchors = [
      for (final cluster in layout.clusters)
        if (project(cluster.center + vm.Vector3(0, bubbleLift, 0))
            case final at?)
          (cluster, at),
    ]..sort((a, b) => b.$2.dy.compareTo(a.$2.dy));
    final placed = <Rect>[];
    final result = <(MapCluster, Offset)>[];
    for (final (cluster, anchor) in anchors) {
      var at = anchor;
      Rect rectAt(Offset p) => Rect.fromLTWH(
        p.dx - _bubbleSize.width / 2,
        p.dy - _bubbleSize.height,
        _bubbleSize.width,
        _bubbleSize.height,
      );
      for (var tries = 0; tries < 8; tries++) {
        final rect = rectAt(at);
        final hit = placed.where((r) => r.overlaps(rect)).firstOrNull;
        if (hit == null) break;
        at = Offset(at.dx, hit.top - 4);
      }
      placed.add(rectAt(at));
      result.add((cluster, at));
    }
    return result;
  }
}

/// The label floating above a group of characters: the activity, how many
/// people, and whether the plan is happening now or when it starts.
class ClusterBubble extends StatelessWidget {
  const ClusterBubble({super.key, required this.cluster, required this.onTap});

  final MapCluster cluster;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final plan = cluster.plan.plan;
    final style = ActivityStyle.of(plan.activity.id);
    final ongoing = plan.isOngoingAt(DateTime.now());
    final people = l10n.mapPeople(cluster.peopleInZone);
    return Semantics(
      button: true,
      label: l10n.mapGroupLabel(
        plan.activity.name,
        plan.title,
        people,
        cluster.zone.name,
      ),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Pressable3d(
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
            decoration: clayDecoration(
              colors,
              cluster.includesMe ? colors.primaryContainer : colors.surface,
              radius: 100,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Emoji3d(style.emoji, size: 22),
                const SizedBox(width: 4),
                Text(
                  '${cluster.peopleInZone}',
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(width: 6),
                if (ongoing) ...[
                  const _LiveDot(),
                  const SizedBox(width: 4),
                  Text(l10n.mapNow, style: theme.textTheme.labelSmall),
                ] else
                  Text(
                    formatTime(plan.startsAt.toLocal(), l10n.localeName),
                    style: theme.textTheme.labelSmall,
                  ),
                if (cluster.includesMe) ...[
                  const SizedBox(width: 6),
                  Text(
                    l10n.mapYou,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A pulsing red dot, the "live" sign of a plan happening now.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    if (AmbientMotion.enabled) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
    child: Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(color: liveColor, shape: BoxShape.circle),
    ),
  );
}

// ---------------------------------------------------------------------------
// 2D fallback

/// Top-down map: islands as circles and characters as flat badges.
class _Map2d extends StatelessWidget {
  const _Map2d({required this.layout, required this.onClusterTap});

  final MapLayout layout;
  final ValueChanged<MapCluster> onClusterTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const _Sky(),
        LayoutBuilder(
          builder: (context, constraints) {
            final side = math.min(constraints.maxWidth, constraints.maxHeight);
            final origin = Offset(
              (constraints.maxWidth - side) / 2,
              (constraints.maxHeight - side) / 2,
            );
            Offset project(vm.Vector3 world) =>
                origin +
                Offset(
                  (world.x / MapLayout.worldSize + 0.5) * side,
                  (0.5 - world.z / MapLayout.worldSize) * side,
                );
            final scale = side / MapLayout.worldSize;
            final badge = MapLayout.avatarSpacing * scale * 1.6;
            return Stack(
              children: [
                for (final island in layout.zones)
                  Positioned(
                    left:
                        project(island.center).dx -
                        MapLayout.islandRadius * scale,
                    top:
                        project(island.center).dy -
                        MapLayout.islandRadius * scale,
                    child: Container(
                      width: MapLayout.islandRadius * 2 * scale,
                      height: MapLayout.islandRadius * 2 * scale,
                      decoration: const BoxDecoration(
                        color: Color(0xFFBFE3B0),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                for (final cluster in layout.clusters)
                  for (final (i, participant) in cluster.participants.indexed)
                    Positioned(
                      left: project(cluster.avatarPositions[i]).dx - badge / 2,
                      top: project(cluster.avatarPositions[i]).dy - badge / 2,
                      child: AvatarBadge(
                        avatar: participant.avatar,
                        size: badge,
                      ),
                    ),
                Positioned.fill(
                  child: _Overlay(
                    layout: layout,
                    project: project,
                    bubbleLift: 0,
                    labelOffset: vm.Vector3(0, 0, -MapLayout.islandRadius),
                    onClusterTap: onClusterTap,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3D

/// Camera that orbits the city center.
/// A map camera looking down at [target] on the ground: one finger pans,
/// two fingers zoom and turn. It tilts towards the horizon as it zooms in,
/// like map apps do.
class _MapCamera {
  _MapCamera(this.target);

  vm.Vector3 target;

  /// Angle around the vertical axis; 0 looks north.
  double azimuth = 0.25;
  double distance = 22;

  static const minDistance = 7.0;
  static const maxDistance = 48.0;

  /// Angle above the ground: lower when close, steeper when far.
  double get elevation {
    final t = (distance - minDistance) / (maxDistance - minDistance);
    return 0.7 + 0.5 * t.clamp(0.0, 1.0);
  }

  PerspectiveCamera camera() {
    final flat = distance * math.cos(elevation);
    return PerspectiveCamera(
      fovRadiansY: 40 * vm.degrees2Radians,
      position:
          target +
          vm.Vector3(
            flat * math.sin(azimuth),
            distance * math.sin(elevation),
            -flat * math.cos(azimuth),
          ),
      target: target,
      fovFar: 200,
    );
  }

  /// Horizontal unit vector from the target towards the camera.
  vm.Vector3 get towardsCamera =>
      vm.Vector3(math.sin(azimuth), 0, -math.cos(azimuth));

  /// Horizontal unit vector pointing to the right of the screen.
  vm.Vector3 get right => vm.Vector3(math.cos(azimuth), 0, math.sin(azimuth));

  /// Moves the ground with a drag of [delta] logical pixels, so the point
  /// under the finger follows it, roughly.
  void pan(Offset delta, double viewHeight) {
    final worldPerPixel =
        2 * distance * math.tan(20 * vm.degrees2Radians) / viewHeight;
    final away = -towardsCamera;
    final moved =
        target -
        right * (delta.dx * worldPerPixel) +
        away * (delta.dy * worldPerPixel / math.sin(elevation));
    const limit = MapLayout.worldSize / 2;
    target = vm.Vector3(
      moved.x.clamp(-limit, limit),
      0,
      moved.z.clamp(-limit, limit),
    );
  }
}

class _Map3d extends StatefulWidget {
  const _Map3d({
    required this.layout,
    required this.focusZoneId,
    required this.onClusterTap,
  });

  final MapLayout layout;
  final String? focusZoneId;
  final ValueChanged<MapCluster> onClusterTap;

  @override
  State<_Map3d> createState() => _Map3dState();
}

/// A character on the map with how it moves.
typedef _Actor = ({Character character, bool lively, double phase});

class _Map3dState extends State<_Map3d> {
  // Start over the user's zone; the rest of the city is a drag away.
  late final _view = _MapCamera(
    widget.layout.zones
            .where((z) => z.zone.id == widget.focusZoneId)
            .firstOrNull
            ?.center ??
        vm.Vector3.zero(),
  );
  late final Scene _scene = _buildWorld();
  final _people = Node(name: 'people');
  final _actors = <_Actor>[];
  final _markers = <Node>[];
  double _scaleStartDistance = 0;
  double _scaleStartAzimuth = 0;

  @override
  void initState() {
    super.initState();
    _buildPeople();
  }

  @override
  void didUpdateWidget(_Map3d oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layout != widget.layout) _buildPeople();
  }

  Scene _buildWorld() {
    final scene = Scene()
      ..directionalLight = DirectionalLight(
        direction: vm.Vector3(-0.5, -1, 0.35),
        intensity: 3.2,
        castsShadow: true,
        shadowMaxDistance: 70,
      )
      ..environmentSettings = EnvironmentSettings(
        toneMapping: ToneMappingMode.aces,
        exposure: 1.05,
      );
    final world = _World.instance;
    scene.add(
      meshNode(
        world.water,
        clayMaterial(const Color(0xFF9ED8F0), roughness: 0.35),
        position: vm.Vector3(0, -0.45, 0),
      ),
    );
    for (final (i, island) in widget.layout.zones.indexed) {
      scene.add(world.island(island, i));
    }
    scene.add(_people);
    return scene;
  }

  void _buildPeople() {
    _people.removeAll();
    _actors.clear();
    _markers.clear();
    final now = DateTime.now();
    for (final (c, cluster) in widget.layout.clusters.indexed) {
      final plan = cluster.plan.plan;
      final lively = plan.isOngoingAt(now);
      if (lively) {
        // A glowing ring marks plans happening now.
        final radius = cluster.avatarPositions.length > 1
            ? (cluster.avatarPositions.first - cluster.center).length + 0.32
            : 0.4;
        _people.add(
          meshNode(
            TorusGeometry(
              radius: radius,
              tubeRadius: 0.045,
              tubularSegments: 8,
            ),
            // The same red as the "happening now" dot of the labels.
            glowMaterial(liveColor),
            position: cluster.center + vm.Vector3(0, 0.03, 0),
          ),
        );
      }
      for (final (i, participant) in cluster.participants.indexed) {
        final character = Character.build(participant.avatar);
        character.root
          ..position = cluster.avatarPositions[i]
          ..scale = vm.Vector3.all(0.75);
        _people.add(character.root);
        _actors.add((
          character: character,
          lively: lively,
          phase: c * 0.7 + i * 0.37,
        ));
        if (participant.isMe) {
          final marker = meshNode(
            _World.instance.marker,
            glowMaterial(const Color(0xFFFF6F91)),
            position: cluster.avatarPositions[i] + vm.Vector3(0, 1.05, 0),
            // A cone pointing down at the user's character.
            rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi),
          );
          _people.add(marker);
          _markers.add(marker);
        }
      }
    }
  }

  void _tick(Duration elapsed, double deltaSeconds) {
    final seconds = elapsed.inMicroseconds / 1e6;
    // Characters turn to face the camera, so faces stay visible.
    final facing = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), -_view.azimuth);
    for (final actor in _actors) {
      actor.character.root.rotation = facing;
      actor.character.animate(
        seconds,
        lively: actor.lively,
        phase: actor.phase,
      );
    }
    for (final marker in _markers) {
      final base = marker.position;
      marker.position = vm.Vector3(
        base.x,
        1.05 + 0.08 * math.sin(seconds * 3),
        base.z,
      );
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleStartDistance = _view.distance;
    _scaleStartAzimuth = _view.azimuth;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double viewHeight) {
    setState(() {
      if (details.pointerCount > 1) {
        // Pinch zooms and twisting turns the map with the fingers.
        _view.distance = (_scaleStartDistance / details.scale).clamp(
          _MapCamera.minDistance,
          _MapCamera.maxDistance,
        );
        _view.azimuth = _scaleStartAzimuth - details.rotation;
      }
      _view.pan(details.focalPointDelta, viewHeight);
    });
  }

  void _onScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    setState(() {
      _view.distance = (_view.distance * math.exp(event.scrollDelta.dy * 0.002))
          .clamp(_MapCamera.minDistance, _MapCamera.maxDistance);
    });
  }

  /// Opens the cluster nearest to a tap on the scene, if close enough.
  void _onTapUp(TapUpDetails details, PerspectiveCamera camera, Size size) {
    MapCluster? nearest;
    var best = 56.0;
    for (final cluster in widget.layout.clusters) {
      final at = camera.worldToScreen(
        cluster.center + vm.Vector3(0, 0.4, 0),
        size,
      );
      if (at == null) continue;
      final d = (at - details.localPosition).distance;
      if (d < best) {
        best = d;
        nearest = cluster;
      }
    }
    if (nearest != null) widget.onClusterTap(nearest);
  }

  @override
  Widget build(BuildContext context) {
    final camera = _view.camera();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        Offset? project(vm.Vector3 world) {
          final at = camera.worldToScreen(world, size);
          if (at == null || !(Offset.zero & size).inflate(40).contains(at)) {
            return null;
          }
          return at;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            const _Sky(),
            Listener(
              onPointerSignal: _onScroll,
              child: GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: (details) =>
                    _onScaleUpdate(details, size.height),
                onTapUp: (details) => _onTapUp(details, camera, size),
                child: SceneView(_scene, camera: camera, onTick: _tick),
              ),
            ),
            _Overlay(
              layout: widget.layout,
              project: project,
              bubbleLift: 1.15,
              labelOffset: _view.towardsCamera * (MapLayout.islandRadius + 0.3),
              onClusterTap: widget.onClusterTap,
            ),
          ],
        );
      },
    );
  }
}

/// Geometry and scenery shared by the 3D map.
class _World {
  _World._();

  static final instance = _World._();

  final water = CylinderGeometry(
    bottomRadius: 30,
    topRadius: 30,
    height: 0.2,
    radialSegments: 64,
  );
  final islandShape = CylinderGeometry(
    bottomRadius: MapLayout.islandRadius + 0.08,
    topRadius: MapLayout.islandRadius,
    height: 0.5,
    radialSegments: 40,
  );
  final trunk = CylinderGeometry(
    bottomRadius: 0.06,
    topRadius: 0.05,
    height: 0.3,
    radialSegments: 8,
  );
  final crown = CylinderGeometry(
    bottomRadius: 0.3,
    topRadius: 0,
    height: 0.65,
    radialSegments: 10,
  );
  final bush = SphereGeometry(radius: 0.22, segments: 12, rings: 8);
  final house = CuboidGeometry(vm.Vector3(0.48, 0.4, 0.48));
  final roof = CylinderGeometry(
    bottomRadius: 0.44,
    topRadius: 0,
    height: 0.32,
    radialSegments: 4,
  );
  final marker = CylinderGeometry(
    bottomRadius: 0.11,
    topRadius: 0,
    height: 0.22,
    radialSegments: 12,
  );

  static const _grass = [
    Color(0xFFB8E0A8),
    Color(0xFFA8D8B9),
    Color(0xFFC9E6A3),
    Color(0xFFB5DDC6),
  ];
  static const _walls = [
    Color(0xFFFFF4E0),
    Color(0xFFFFE3E3),
    Color(0xFFE6E0FF),
    Color(0xFFE0F2FF),
  ];

  /// An island for [island] with a few trees and houses on its rim, placed
  /// from a seed of the zone id so each zone always looks the same.
  Node island(MapIsland island, int index) {
    final root = Node(name: 'zone:${island.zone.id}')..position = island.center;
    root.add(
      meshNode(
        islandShape,
        clayMaterial(_grass[index % _grass.length], roughness: 0.9),
        position: vm.Vector3(0, -0.25, 0),
      ),
    );
    final random = math.Random(
      island.zone.id.codeUnits.fold<int>(7, (h, c) => h * 31 + c),
    );
    final green = clayMaterial(const Color(0xFF5FAF6A), roughness: 0.8);
    final bark = clayMaterial(const Color(0xFF9C6B4E));
    final roofMaterial = clayMaterial(const Color(0xFFE07A5F));
    const items = 7;
    for (var i = 0; i < items; i++) {
      final angle = (i + random.nextDouble() * 0.6) * 2 * math.pi / items;
      final radius = 1.45 + random.nextDouble() * 0.25;
      final at = vm.Vector3(
        radius * math.sin(angle),
        0,
        radius * math.cos(angle),
      );
      final item = Node()..position = at;
      switch (random.nextInt(3)) {
        case 0:
          item
            ..add(meshNode(trunk, bark, position: vm.Vector3(0, 0.15, 0)))
            ..add(meshNode(crown, green, position: vm.Vector3(0, 0.6, 0)));
        case 1:
          item.add(meshNode(bush, green, position: vm.Vector3(0, 0.14, 0)));
        default:
          item
            ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), angle)
            ..add(
              meshNode(
                house,
                clayMaterial(_walls[random.nextInt(_walls.length)]),
                position: vm.Vector3(0, 0.2, 0),
              ),
            )
            ..add(
              meshNode(
                roof,
                roofMaterial,
                position: vm.Vector3(0, 0.56, 0),
                rotation: vm.Quaternion.axisAngle(
                  vm.Vector3(0, 1, 0),
                  math.pi / 4,
                ),
              ),
            );
      }
      root.add(item);
    }
    return root;
  }
}
