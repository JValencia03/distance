import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import 'package:distance/data/models.dart';

/// Where everything on the plans map goes, in world units, independent of
/// how it is drawn.
///
/// Zones become islands laid out like the real city: world +X is east and
/// +Z is north, so a camera looking along +Z sees north at the top. Each
/// participant stands on the island of the zone they chose, grouped with
/// the people of the same plan in a [MapCluster].
class MapLayout {
  MapLayout._(this.zones, this.clusters);

  factory MapLayout.of(CityMap map) {
    final zones = {
      for (final zone in map.zones)
        zone.id: MapIsland(zone, worldPosition(zone.x, zone.y)),
    };

    // Group each plan's participants by zone, keeping plans in API order
    // (soonest first) so the earliest plans get the best spots.
    final groups = <String, List<(MapPlan, List<MapParticipant>)>>{};
    for (final plan in map.plans) {
      final byZone = <String, List<MapParticipant>>{};
      for (final participant in plan.participants) {
        // Participants in a zone the map does not know stand in the plan's.
        final zoneId = zones.containsKey(participant.zoneId)
            ? participant.zoneId
            : plan.plan.zone.id;
        byZone.putIfAbsent(zoneId, () => []).add(participant);
      }
      for (final MapEntry(key: zoneId, value: people) in byZone.entries) {
        if (!zones.containsKey(zoneId)) continue;
        groups.putIfAbsent(zoneId, () => []).add((plan, people));
      }
    }

    final clusters = <MapCluster>[];
    for (final MapEntry(key: zoneId, value: zoneGroups) in groups.entries) {
      final island = zones[zoneId]!;
      final shown = zoneGroups.take(maxClustersPerZone).toList();
      for (final (index, (plan, people)) in shown.indexed) {
        final center = island.center + _ringOffset(index, shown.length, 0.95);
        // The current user is always drawn, ahead of the others.
        final ordered = [
          ...people.where((p) => p.isMe),
          ...people.where((p) => !p.isMe),
        ];
        final visible = ordered.take(maxAvatarsPerCluster).toList();
        clusters.add(
          MapCluster(
            plan: plan,
            zone: island.zone,
            center: center,
            participants: visible,
            avatarPositions: [
              for (var i = 0; i < visible.length; i++)
                center + _ringOffset(i, visible.length, avatarSpacing),
            ],
            hiddenCount: ordered.length - visible.length,
            peopleInZone: ordered.length,
          ),
        );
      }
    }
    return MapLayout._(zones.values.toList(), clusters);
  }

  /// Side of the square the 0..1 zone layout is scaled to.
  static const worldSize = 32.0;

  /// Radius of a zone island. Zones are at least ~4 units apart.
  static const islandRadius = 1.9;

  /// More plans in one zone are left out of the drawing; the list view
  /// still has them.
  static const maxClustersPerZone = 6;
  static const maxAvatarsPerCluster = 8;

  /// Distance between neighbouring characters in a cluster.
  static const avatarSpacing = 0.32;

  final List<MapIsland> zones;
  final List<MapCluster> clusters;

  /// Maps a normalized zone position (x east, y south) to the world.
  static vm.Vector3 worldPosition(double x, double y) =>
      vm.Vector3((x - 0.5) * worldSize, 0, (0.5 - y) * worldSize);

  /// Offset of item [index] of [count] spread on a circle. A single item
  /// stays at the center; the radius grows with the count so neighbours
  /// keep about [spacing] between them.
  static vm.Vector3 _ringOffset(int index, int count, double spacing) {
    if (count <= 1) return vm.Vector3.zero();
    final radius = math.max(spacing, spacing * count / (2 * math.pi));
    final angle = index * 2 * math.pi / count;
    return vm.Vector3(radius * math.sin(angle), 0, radius * math.cos(angle));
  }
}

class MapIsland {
  const MapIsland(this.zone, this.center);

  final MapZone zone;
  final vm.Vector3 center;
}

/// The people of one plan who chose the same zone.
class MapCluster {
  const MapCluster({
    required this.plan,
    required this.zone,
    required this.center,
    required this.participants,
    required this.avatarPositions,
    required this.hiddenCount,
    required this.peopleInZone,
  });

  final MapPlan plan;
  final MapZone zone;
  final vm.Vector3 center;

  /// The participants drawn, the current user first.
  final List<MapParticipant> participants;

  /// Where each of [participants] stands, in the same order.
  final List<vm.Vector3> avatarPositions;

  /// Participants in this zone left out of the drawing.
  final int hiddenCount;
  final int peopleInZone;

  bool get includesMe => participants.any((p) => p.isMe);
}
