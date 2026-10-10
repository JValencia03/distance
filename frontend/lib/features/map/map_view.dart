import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import 'package:distance/features/avatar/avatar_badge.dart';
import 'package:distance/features/avatar/character.dart';
import 'package:distance/features/map/city_map.dart';
import 'package:distance/features/map/city_scene.dart';
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

/// The plans map: the real city, drawn in the app's style, with the
/// characters of the people taking part in each plan standing in the
/// district they chose. A 3D scene the user can pan, zoom and turn, or a
/// flat map on devices without 3D. Tapping a group calls [onClusterTap].
class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.city,
    required this.layout,
    required this.onClusterTap,
    this.focusZoneId,
  });

  final CityMapAsset city;
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
    final map = FutureBuilder(
      future: _ready,
      builder: (context, snapshot) => switch (snapshot.data) {
        null => const Center(child: CircularProgressIndicator()),
        true => _Map3d(
          city: widget.city,
          layout: widget.layout,
          focusZoneId: widget.focusZoneId,
          onClusterTap: widget.onClusterTap,
        ),
        false => _Map2d(
          city: widget.city,
          layout: widget.layout,
          onClusterTap: widget.onClusterTap,
        ),
      },
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        map,
        // The data license requires the attribution next to the map.
        Positioned(
          left: 8,
          top: 8,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.city.attribution,
                style: const TextStyle(fontSize: 10, color: Color(0xFF4A4458)),
              ),
            ),
          ),
        ),
      ],
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

/// Tap targets and labels drawn over either view. Group bubbles come
/// first, then landmarks, then district names. A bubble that would cover
/// one already placed moves up a little, or is left out if it would end up
/// far from its people; names that collide are left out.
///
/// From afar ([onZoneTap] set), each zone gets a single summary bubble
/// instead of one per group, so the map stays readable.
class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.city,
    required this.layout,
    required this.project,
    required this.bubbleLift,
    required this.onClusterTap,
    this.onZoneTap,
  });

  final CityMapAsset city;
  final MapLayout layout;
  final WorldProjector project;

  /// Height above a cluster's center where its bubble points.
  final double bubbleLift;
  final ValueChanged<MapCluster> onClusterTap;

  /// When set, zones are summarized and tapping one calls this.
  final ValueChanged<ZoneSpot>? onZoneTap;

  static const _bubbleSize = Size(170, 40);

  /// How far a bubble may move up to avoid another before it is dropped.
  static const _maxShift = 90.0;

  @override
  Widget build(BuildContext context) {
    final placed = <Rect>[];
    final children = <Widget>[];

    // Bubbles nearer the bottom of the view (closer to the camera) are
    // placed first and stay put; the others move up when they collide.
    void bubbles<T>(
      Iterable<(T, vm.Vector3)> items,
      Widget Function(T item) build,
    ) {
      final anchors = [
        for (final (item, world) in items)
          if (project(world + vm.Vector3(0, bubbleLift, 0)) case final at?)
            (item, at),
      ]..sort((a, b) => b.$2.dy.compareTo(a.$2.dy));
      for (final (item, anchor) in anchors) {
        Rect rectAt(Offset p) => Rect.fromLTWH(
          p.dx - _bubbleSize.width / 2,
          p.dy - _bubbleSize.height,
          _bubbleSize.width,
          _bubbleSize.height,
        );
        Offset? at = anchor;
        while (at != null) {
          final hit = placed.where((r) => r.overlaps(rectAt(at!))).firstOrNull;
          if (hit == null) break;
          final moved = Offset(at.dx, hit.top - 4);
          at = anchor.dy - moved.dy > _maxShift ? null : moved;
        }
        if (at == null) continue;
        placed.add(rectAt(at));
        children.add(
          Positioned(
            left: at.dx,
            top: at.dy,
            child: FractionalTranslation(
              // Anchor the bubble's bottom center on the point.
              translation: const Offset(-0.5, -1),
              child: build(item),
            ),
          ),
        );
      }
    }

    final zoneTap = onZoneTap;
    if (zoneTap == null) {
      bubbles(
        [for (final c in layout.clusters) (c, c.center)],
        (cluster) =>
            ClusterBubble(cluster: cluster, onTap: () => onClusterTap(cluster)),
      );
    } else {
      final byZone = <ZoneSpot, List<MapCluster>>{};
      for (final cluster in layout.clusters) {
        final spot = layout.zones.firstWhere(
          (z) => z.zone.id == cluster.zone.id,
        );
        byZone.putIfAbsent(spot, () => []).add(cluster);
      }
      bubbles(
        [for (final spot in byZone.keys) (spot, spot.center)],
        (spot) => _ZoneBubble(
          zone: spot,
          clusters: byZone[spot]!,
          onTap: () => zoneTap(spot),
        ),
      );
    }

    void label(vm.Vector3 world, String text, {required bool landmark}) {
      final at = project(world);
      if (at == null) return;
      final width = text.length * (landmark ? 6.5 : 6.0) + (landmark ? 26 : 14);
      final rect = Rect.fromCenter(center: at, width: width, height: 20);
      if (placed.any((r) => r.overlaps(rect))) return;
      placed.add(rect);
      children.add(
        Positioned(
          left: at.dx,
          top: at.dy,
          child: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: IgnorePointer(
              child: _Label(text: text, landmark: landmark),
            ),
          ),
        ),
      );
    }

    for (final landmark in city.landmarks) {
      label(
        vm.Vector3(landmark.x, 0, landmark.z),
        landmark.name,
        landmark: true,
      );
    }
    for (final region in city.regions) {
      label(
        vm.Vector3(region.labelX, 0, region.labelZ),
        region.name,
        landmark: false,
      );
    }
    return Stack(clipBehavior: Clip.hardEdge, children: children);
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.landmark});

  final String text;
  final bool landmark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = landmark
        ? theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.labelSmall;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: landmark ? 0.85 : 0.65,
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (landmark) ...[
            Icon(
              Icons.star_rounded,
              size: 12,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 2),
          ],
          Text(text, style: style),
        ],
      ),
    );
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

/// The label of a zone seen from afar: how many people and plans it has,
/// and whether any is happening now. Tapping it flies the camera there.
class _ZoneBubble extends StatelessWidget {
  const _ZoneBubble({
    required this.zone,
    required this.clusters,
    required this.onTap,
  });

  final ZoneSpot zone;
  final List<MapCluster> clusters;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final people = clusters.fold(0, (sum, c) => sum + c.peopleInZone);
    final plans = l10n.mapZonePlans(clusters.length);
    final ongoing = clusters.any((c) => c.plan.plan.isOngoingAt(now));
    final includesMe = clusters.any((c) => c.includesMe);
    return Semantics(
      button: true,
      label: l10n.mapZoneLabel(zone.zone.name, plans, l10n.mapPeople(people)),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Pressable3d(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
            decoration: clayDecoration(
              colors,
              includesMe ? colors.primaryContainer : colors.surface,
              radius: 100,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.groups_rounded, size: 18, color: colors.primary),
                const SizedBox(width: 4),
                Text('$people', style: theme.textTheme.labelLarge),
                const SizedBox(width: 6),
                if (ongoing) ...[const _LiveDot(), const SizedBox(width: 4)],
                Text(plans, style: theme.textTheme.labelSmall),
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

/// Top-down city drawn with the same triangles as the 3D scene, and the
/// characters as flat badges.
class _Map2d extends StatelessWidget {
  const _Map2d({
    required this.city,
    required this.layout,
    required this.onClusterTap,
  });

  final CityMapAsset city;
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
            final view = _FlatView(city.bounds, constraints.biggest);
            final badge = math.max(
              12.0,
              MapLayout.avatarSpacing * view.scale * 1.5,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _CityPainter(city, view)),
                ),
                for (final cluster in layout.clusters)
                  for (final (i, participant) in cluster.participants.indexed)
                    Positioned(
                      left:
                          view.project(cluster.avatarPositions[i]).dx -
                          badge / 2,
                      top:
                          view.project(cluster.avatarPositions[i]).dy -
                          badge / 2,
                      child: AvatarBadge(
                        avatar: participant.avatar,
                        size: badge,
                      ),
                    ),
                Positioned.fill(
                  child: _Overlay(
                    city: city,
                    layout: layout,
                    project: view.project,
                    bubbleLift: 0,
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

/// Fits the city's bounds into a view, north up.
class _FlatView {
  factory _FlatView(Float32List bounds, Size size) {
    final width = bounds[2] - bounds[0], depth = bounds[3] - bounds[1];
    final scale = math.min(size.width / width, size.height / depth);
    return _FlatView._(
      bounds[0],
      bounds[3],
      scale,
      Offset(
        (size.width - width * scale) / 2,
        (size.height - depth * scale) / 2,
      ),
    );
  }

  _FlatView._(this.minX, this.maxZ, this.scale, this.origin);

  final double minX;
  final double maxZ;

  /// Pixels per kilometre.
  final double scale;
  final Offset origin;

  Offset project(vm.Vector3 world) => offset(world.x, world.z);

  Offset offset(double x, double z) =>
      origin + Offset((x - minX) * scale, (maxZ - z) * scale);
}

class _CityPainter extends CustomPainter {
  _CityPainter(this.city, this.view);

  final CityMapAsset city;
  final _FlatView view;

  @override
  void paint(Canvas canvas, Size size) {
    final regionColors = [
      for (final (i, r) in city.regions.indexed) CityPalette.region(r, i),
    ];
    void layer(CityLayer kind, Color Function(int attribute) color) {
      final mesh = city.layers[kind];
      if (mesh == null || mesh.indices.isEmpty) return;
      final positions = <Offset>[
        for (var i = 0; i < mesh.vertexCount; i++)
          view.offset(mesh.positions[i * 2], mesh.positions[i * 2 + 1]),
      ];
      canvas.drawVertices(
        ui.Vertices(
          VertexMode.triangles,
          positions,
          colors: [for (final a in mesh.attributes) color(a)],
          indices: mesh.indices,
        ),
        BlendMode.dst,
        Paint(),
      );
    }

    layer(CityLayer.land, (a) => regionColors[a]);
    layer(CityLayer.forest, (_) => CityPalette.forest);
    layer(CityLayer.airport, (_) => CityPalette.airport);
    layer(CityLayer.park, (a) => a == 1 ? CityPalette.golf : CityPalette.park);
    layer(CityLayer.water, (_) => CityPalette.water);
    layer(CityLayer.borders, (_) => CityPalette.border);
    layer(CityLayer.roads, (a) => CityPalette.road(CityRoadClass.values[a]));
  }

  @override
  bool shouldRepaint(_CityPainter oldDelegate) =>
      oldDelegate.city != city ||
      oldDelegate.view.scale != view.scale ||
      oldDelegate.view.origin != view.origin;
}

// ---------------------------------------------------------------------------
// 3D

/// A map camera looking down at [target] on the ground: one finger pans,
/// two fingers zoom and turn. It tilts towards the horizon as it zooms in,
/// like map apps do. Units are kilometres.
class _MapCamera {
  _MapCamera(this.target, this.bounds);

  vm.Vector3 target;
  final Float32List bounds;

  /// Angle around the vertical axis; 0 looks north.
  double azimuth = 0.2;
  double distance = 9;

  static const minDistance = 2.5;
  static const maxDistance = 40.0;

  /// Angle above the ground: lower when close, steeper when far.
  double get elevation {
    final t = (distance - minDistance) / (maxDistance - minDistance);
    return 0.62 + 0.55 * t.clamp(0.0, 1.0);
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
  /// under the finger follows it, roughly, within the city.
  void pan(Offset delta, double viewHeight) {
    final worldPerPixel =
        2 * distance * math.tan(20 * vm.degrees2Radians) / viewHeight;
    final moved =
        target -
        right * (delta.dx * worldPerPixel) -
        towardsCamera * (delta.dy * worldPerPixel / math.sin(elevation));
    target = vm.Vector3(
      moved.x.clamp(bounds[0], bounds[2]),
      0,
      moved.z.clamp(bounds[1], bounds[3]),
    );
  }
}

class _Map3d extends StatefulWidget {
  const _Map3d({
    required this.city,
    required this.layout,
    required this.focusZoneId,
    required this.onClusterTap,
  });

  final CityMapAsset city;
  final MapLayout layout;
  final String? focusZoneId;
  final ValueChanged<MapCluster> onClusterTap;

  @override
  State<_Map3d> createState() => _Map3dState();
}

class _Map3dState extends State<_Map3d> {
  // Start over the user's zone; the rest of the city is a drag away.
  late final _view = _MapCamera(
    widget.layout.zones
            .where((z) => z.zone.id == widget.focusZoneId)
            .firstOrNull
            ?.center ??
        vm.Vector3(
          (widget.city.bounds[0] + widget.city.bounds[2]) / 2,
          0,
          (widget.city.bounds[1] + widget.city.bounds[3]) / 2,
        ),
    widget.city.bounds,
  );
  late final Scene _scene = _buildScene();
  final _crowd = Crowd(scale: MapLayout.characterScale);
  final _markers = Node(name: 'markers');
  final _meMarkers = <Node>[];
  double _scaleStartDistance = 0;
  double _scaleStartAzimuth = 0;

  /// Height of a character's head on the map, in kilometres.
  static const _headHeight = characterHeight * MapLayout.characterScale;

  @override
  void initState() {
    super.initState();
    _placePeople();
  }

  @override
  void didUpdateWidget(_Map3d oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layout != widget.layout) _placePeople();
  }

  Scene _buildScene() => Scene()
    ..directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.5, -1, 0.35),
      intensity: 3.2,
      castsShadow: true,
      shadowMaxDistance: 25,
      shadowCascadeCount: 2,
    )
    ..environmentSettings = EnvironmentSettings(
      toneMapping: ToneMappingMode.aces,
      exposure: 1.05,
    )
    ..add(buildCityScene(widget.city))
    ..add(_crowd.root)
    ..add(_markers);

  void _placePeople() {
    _markers.removeAll();
    _meMarkers.clear();
    final now = DateTime.now();
    final members = <CrowdMember>[];
    for (final (c, cluster) in widget.layout.clusters.indexed) {
      final lively = cluster.plan.plan.isOngoingAt(now);
      if (lively) {
        // A glowing ring marks plans happening now, in the same red as the
        // "now" dot of the labels.
        _markers.add(
          meshNode(
            TorusGeometry(
              radius: cluster.radius + 0.12,
              tubeRadius: 0.018,
              tubularSegments: 8,
            ),
            glowMaterial(liveColor),
            position: cluster.center + vm.Vector3(0, 0.01, 0),
          ),
        );
      }
      for (final (i, participant) in cluster.participants.indexed) {
        members.add(
          CrowdMember(
            avatar: participant.avatar,
            position: cluster.avatarPositions[i],
            lively: lively,
            phase: c * 0.7 + i * 0.37,
          ),
        );
        if (participant.isMe) {
          final marker = meshNode(
            _MarkerGeometry.instance.cone,
            glowMaterial(const Color(0xFFFF6F91)),
            position: cluster.avatarPositions[i],
            // A cone pointing down at the user's character.
            rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi),
          );
          _markers.add(marker);
          _meMarkers.add(marker);
        }
      }
    }
    _crowd.setMembers(members);
  }

  void _tick(Duration elapsed, double deltaSeconds) {
    final seconds = elapsed.inMicroseconds / 1e6;
    _flyStep(deltaSeconds);
    // Characters turn to face the camera, so faces stay visible.
    _crowd.update(seconds, facing: -_view.azimuth);
    for (final marker in _meMarkers) {
      final at = marker.position;
      marker.position = vm.Vector3(
        at.x,
        _headHeight + 0.1 + 0.03 * math.sin(seconds * 3),
        at.z,
      );
    }
  }

  /// Beyond this distance each zone shows one summary instead of a bubble
  /// per group, and tapping it flies there.
  static const _summaryDistance = 13.0;

  /// Where the camera is flying to, if anywhere.
  ({vm.Vector3 target, double distance})? _flight;

  void _flyTo(ZoneSpot zone) => _flight = (target: zone.center, distance: 7);

  /// Eases the camera towards [_flight], frame-rate independently.
  void _flyStep(double deltaSeconds) {
    final flight = _flight;
    if (flight == null) return;
    final t = 1 - math.exp(-deltaSeconds * 5);
    setState(() {
      _view.target += (flight.target - _view.target) * t;
      _view.distance += (flight.distance - _view.distance) * t;
      if ((flight.target - _view.target).length < 0.01 &&
          (flight.distance - _view.distance).abs() < 0.01) {
        _flight = null;
      }
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    // Touching the map takes over from any flight.
    _flight = null;
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
        cluster.center + vm.Vector3(0, _headHeight / 2, 0),
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
              city: widget.city,
              layout: widget.layout,
              project: project,
              bubbleLift: _headHeight + 0.15,
              onZoneTap: _view.distance > _summaryDistance ? _flyTo : null,
              onClusterTap: widget.onClusterTap,
            ),
          ],
        );
      },
    );
  }
}

class _MarkerGeometry {
  _MarkerGeometry._();

  static final instance = _MarkerGeometry._();

  final cone = CylinderGeometry(
    bottomRadius: 0.04,
    topRadius: 0,
    height: 0.08,
    radialSegments: 12,
  );
}
