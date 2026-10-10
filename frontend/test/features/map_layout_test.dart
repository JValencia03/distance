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

MapLayout layoutOf(List<Map<String, Object?>> plans) =>
    MapLayout.of(CityMap.fromJson({'zones': mapZonesJson, 'plans': plans}));

void main() {
  test('places zones like the city, with north away from the camera', () {
    final layout = layoutOf([]);
    final chapinero = layout.zones.firstWhere((z) => z.zone.id == 'chapinero');
    final usaquen = layout.zones.firstWhere((z) => z.zone.id == 'usaquen');

    // Usaquén is north-east of Chapinero: larger x (east) and z (north).
    expect(usaquen.center.x, greaterThan(chapinero.center.x));
    expect(usaquen.center.z, greaterThan(chapinero.center.z));
    expect(MapLayout.worldPosition(0.5, 0.5), vm.Vector3.zero());
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

    final inChapinero = layout.clusters.where((c) => c.zone.id == 'chapinero');
    expect(inChapinero.map((c) => c.plan.plan.id), ['a', 'b']);
    // Two plans in one zone stand apart.
    final [first, second] = inChapinero.toList();
    expect((first.center - second.center).length, greaterThan(1));
  });

  test('keeps everyone on their island and caps crowds', () {
    final crowd = [for (var i = 0; i < 12; i++) participantJson()];
    final layout = layoutOf([mapPlanJson('a', crowd)]);
    final cluster = layout.clusters.single;
    final island = layout.zones.firstWhere((z) => z.zone.id == 'chapinero');

    expect(cluster.participants, hasLength(MapLayout.maxAvatarsPerCluster));
    expect(cluster.hiddenCount, 12 - MapLayout.maxAvatarsPerCluster);
    expect(cluster.peopleInZone, 12);
    for (final position in cluster.avatarPositions) {
      expect(
        (position - island.center).length,
        lessThan(MapLayout.islandRadius - 0.3),
      );
    }
  });

  test('participants in an unknown zone stand in the plan zone', () {
    final layout = layoutOf([
      mapPlanJson('a', [participantJson(zoneId: 'atlantis')]),
    ]);
    expect(layout.clusters.single.zone.id, 'chapinero');
  });
}
