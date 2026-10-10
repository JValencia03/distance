import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:distance/data/models.dart';
import 'package:distance/features/map/map_layout.dart';

import '../fake_api.dart';

Map<String, Object?> participantJson({
  String zoneId = 'chapinero',
  bool isMe = false,
  String bodyColor = 'mint',
}) => {
  'avatar': {
    'skin': 'basic',
    'bodyColor': bodyColor,
    'skinTone': 'tone2',
    'accessory': 'none',
  },
  'zoneId': zoneId,
  'isMe': isMe,
};

Map<String, Object?> mapPlanJson(
  String id,
  List<Map<String, Object?>> participants,
) => {...planJson(id: id), 'participants': participants};

const mapZonesJson = [
  {'id': 'chapinero', 'name': 'Chapinero', 'x': 0.6, 'y': 0.6},
  {'id': 'usaquen', 'name': 'Usaquén', 'x': 0.8, 'y': 0.3},
];

/// Places zones at fixed points, as the city asset would.
final _centers = {
  'chapinero': vm.Vector3(2, 0, 1),
  'usaquen': vm.Vector3(4, 0, 6),
};

MapLayout layoutOf(List<Map<String, Object?>> plans) => MapLayout.of(
  CityMap.fromJson({'zones': mapZonesJson, 'plans': plans}),
  place: (zone) => _centers[zone.id]!,
);

void main() {
  test('places each zone where the city says', () {
    final layout = layoutOf([]);
    final usaquen = layout.zones.firstWhere((z) => z.zone.id == 'usaquen');
    expect(usaquen.center, _centers['usaquen']);
  });

  test('groups each plan by the zone its participants chose', () {
    final layout = layoutOf([
      mapPlanJson('a', [
        participantJson(),
        participantJson(zoneId: 'usaquen'),
        participantJson(zoneId: 'usaquen', isMe: true),
      ]),
      mapPlanJson('b', [participantJson()]),
    ]);

    expect(layout.clusters, hasLength(3));
    final inUsaquen = layout.clusters.singleWhere(
      (c) => c.zone.id == 'usaquen',
    );
    expect(inUsaquen.plan.plan.id, 'a');
    expect(inUsaquen.peopleInZone, 2);
    expect(inUsaquen.includesMe, isTrue);
    expect(inUsaquen.participants.first.isMe, isTrue, reason: 'me first');
    expect((inUsaquen.center - _centers['usaquen']!).length, lessThan(1));

    final inChapinero = layout.clusters.where((c) => c.zone.id == 'chapinero');
    expect(inChapinero.map((c) => c.plan.plan.id), ['a', 'b']);
    // Two plans in one zone stand apart, further than their people spread.
    final [first, second] = inChapinero.toList();
    expect(
      (first.center - second.center).length,
      greaterThan(first.radius + second.radius),
    );
  });

  test('keeps a group close together and caps crowds', () {
    final crowd = [for (var i = 0; i < 12; i++) participantJson()];
    final layout = layoutOf([mapPlanJson('a', crowd)]);
    final cluster = layout.clusters.single;

    expect(cluster.participants, hasLength(MapLayout.maxAvatarsPerCluster));
    expect(cluster.hiddenCount, 12 - MapLayout.maxAvatarsPerCluster);
    expect(cluster.peopleInZone, 12);
    // Neighbours do not overlap, and the group fits in a few hundred metres.
    final positions = cluster.avatarPositions;
    for (var i = 0; i < positions.length; i++) {
      final next = positions[(i + 1) % positions.length];
      expect(
        (positions[i] - next).length,
        greaterThan(MapLayout.avatarSpacing * 0.9),
      );
    }
    expect(cluster.radius, lessThan(0.5));
  });

  test('participants in an unknown zone stand in the plan zone', () {
    final layout = layoutOf([
      mapPlanJson('a', [participantJson(zoneId: 'atlantis')]),
    ]);
    expect(layout.clusters.single.zone.id, 'chapinero');
  });
}
