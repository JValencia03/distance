import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:distance/features/map/city_map_asset.dart';

void main() {
  test('round-trips through the binary format', () {
    final asset = CityMapAsset(
      attribution: '© test',
      projection: CityProjection.centeredOn(4.65, -74.1),
      bounds: Float32List.fromList([-1, -2, 3, 4]),
      regions: [
        CityRegion(
          name: 'Chapinero',
          zoneId: 'chapinero',
          labelX: 0.5,
          labelZ: 0.25,
          rings: [
            Float32List.fromList([0, 0, 1, 0, 1, 1]),
          ],
        ),
        CityRegion(
          name: 'Bosa',
          zoneId: null,
          labelX: 2,
          labelZ: 2,
          rings: [
            Float32List.fromList([2, 2, 3, 2, 3, 3, 2, 3]),
          ],
        ),
      ],
      layers: {
        CityLayer.land: CityMesh(
          // Three vertices so the attribute bytes need padding.
          positions: Float32List.fromList([0, 0, 1, 0, 1, 1]),
          attributes: Uint8List.fromList([0, 0, 1]),
          indices: Uint32List.fromList([0, 2, 1]),
        ),
        CityLayer.roads: CityMesh(
          positions: Float32List.fromList([0, 0, 1, 1, 2, 0, 3, 1]),
          attributes: Uint8List.fromList([1, 1, 1, 1]),
          indices: Uint32List.fromList([0, 1, 2, 2, 1, 3]),
        ),
      },
      trees: Float32List.fromList([0.5, 0.5, 1, 0, 1.5, 1.5, 0.8, 0.1]),
      landmarks: const [
        CityLandmark(
          kind: CityLandmarkKind.mountain,
          name: 'Monserrate',
          x: 1,
          z: 2,
        ),
      ],
    );

    final decoded = CityMapAsset.decode(asset.encode());

    expect(decoded.attribution, '© test');
    expect(decoded.projection.lat0, 4.65);
    expect(decoded.bounds, asset.bounds);
    expect(decoded.regions.map((r) => r.zoneId), ['chapinero', null]);
    expect(decoded.regions.last.rings.single, asset.regions.last.rings.single);
    expect(decoded.layers.keys, [CityLayer.land, CityLayer.roads]);
    final land = decoded.layers[CityLayer.land]!;
    expect(land.attributes, [0, 0, 1]);
    expect(land.indices, [0, 2, 1]);
    expect(decoded.layers[CityLayer.roads]!.positions, [
      0,
      0,
      1,
      1,
      2,
      0,
      3,
      1,
    ]);
    expect(decoded.treeCount, 2);
    expect(decoded.trees.last, closeTo(0.1, 1e-6));
    expect(decoded.landmarks.single.name, 'Monserrate');
  });

  test('rejects other files', () {
    expect(
      () => CityMapAsset.decode(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });

  test('projection maps degrees to kilometres around its center', () {
    final projection = CityProjection.centeredOn(4.65, -74.1);
    expect(projection.project(4.65, -74.1), (0.0, 0.0));
    final (x, z) = projection.project(4.66, -74.09);
    // About 1.1 km per hundredth of a degree near the equator.
    expect(x, closeTo(1.11, 0.01));
    expect(z, closeTo(1.11, 0.01));
  });

  test('the bundled city has a district for every zone', () {
    final city = CityMapAsset.decode(
      File('assets/map/bogota.bin').readAsBytesSync(),
    );
    final zoneIds = {for (final r in city.regions) ?r.zoneId};
    // The zone catalog of backend/internal/plans/catalog.go.
    expect(zoneIds, {
      'usaquen',
      'chapinero',
      'teusaquillo',
      'candelaria',
      'suba',
      'engativa',
      'fontibon',
      'kennedy',
    });
    expect(city.attribution, contains('OpenStreetMap'));
    for (final region in city.regions) {
      final b = city.bounds;
      expect(region.labelX, inInclusiveRange(b[0], b[2]), reason: region.name);
      expect(region.labelZ, inInclusiveRange(b[1], b[3]), reason: region.name);
    }
    // Real geography: Usaquén is north-east of Kennedy.
    final usaquen = city.regions.firstWhere((r) => r.zoneId == 'usaquen');
    final kennedy = city.regions.firstWhere((r) => r.zoneId == 'kennedy');
    expect(usaquen.labelX, greaterThan(kennedy.labelX));
    expect(usaquen.labelZ, greaterThan(kennedy.labelZ));
    expect(city.layers[CityLayer.land]!.indices, isNotEmpty);
    expect(city.layers[CityLayer.roads]!.indices, isNotEmpty);
  });
}
