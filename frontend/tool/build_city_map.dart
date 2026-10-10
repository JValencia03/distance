// Builds the city drawn on the plans map (assets/map/bogota.bin) from
// OpenStreetMap data.
//
// Run from frontend/:  dart run tool/build_city_map.dart [--refresh]
//
// The heavy work happens here, once, instead of on the phone: download,
// simplification, clipping and triangulation. The app only loads the
// resulting arrays into GPU buffers. Overpass answers are cached in
// .dart_tool/city_map_cache; pass --refresh to download them again.
//
// Data © OpenStreetMap contributors, available under the Open Database
// License (ODbL); the app shows that attribution on the map.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:distance/features/map/city_map_asset.dart';

import 'city_map/geometry.dart';
import 'city_map/osm.dart';

// The urban area of Bogotá, including the eastern hills.
const _south = 4.47, _west = -74.23, _north = 4.84, _east = -73.99;
const _bbox = '$_south,$_west,$_north,$_east';

/// OSM district names mapped to the zone ids of the server catalog
/// (backend/internal/plans/catalog.go). Other districts are drawn as
/// neutral land.
const _zoneIds = {
  'Usaquén': 'usaquen',
  'Chapinero': 'chapinero',
  'Teusaquillo': 'teusaquillo',
  'La Candelaria': 'candelaria',
  'Suba': 'suba',
  'Engativá': 'engativa',
  'Fontibón': 'fontibon',
  'Kennedy': 'kennedy',
};

/// Recognizable places: OSM name pattern, kind, and the name shown.
const _landmarks = [
  ('^Monserrate\$', CityLandmarkKind.mountain, 'Monserrate'),
  ('^Plaza de Bolívar\$', CityLandmarkKind.plaza, 'Plaza de Bolívar'),
  ('^Torre Colpatria\$', CityLandmarkKind.tower, 'Torre Colpatria'),
  ('Campín', CityLandmarkKind.stadium, 'El Campín'),
  (
    '^Universidad Nacional de Colombia\$',
    CityLandmarkKind.campus,
    'Universidad Nacional',
  ),
  ('^Museo del Oro\$', CityLandmarkKind.museum, 'Museo del Oro'),
  ('^Movistar Arena\$', CityLandmarkKind.arena, 'Movistar Arena'),
  ('^Maloka\$', CityLandmarkKind.dome, 'Maloka'),
  (
    '^Parque (Metropolitano )?Simón Bolívar',
    CityLandmarkKind.park,
    'Parque Simón Bolívar',
  ),
  ('^Jardín Botánico', CityLandmarkKind.park, 'Jardín Botánico'),
  ('^Parque de la 93\$', CityLandmarkKind.park, 'Parque de la 93'),
  (
    '^Aeropuerto Internacional El Dorado',
    CityLandmarkKind.airport,
    'El Dorado',
  ),
];

/// Ribbon widths in kilometres, wider than real life so they read at city
/// scale.
const _roadWidths = {
  CityRoadClass.major: 0.06,
  CityRoadClass.primary: 0.038,
  CityRoadClass.secondary: 0.022,
  CityRoadClass.runway: 0.07,
  CityRoadClass.river: 0.045,
};

/// Height of the ground in wooded areas, where their trees stand. The woods
/// are flat for now; relief can raise them later.
const forestHeight = 0.0;

Future<void> main(List<String> args) async {
  final overpass = Overpass(refresh: args.contains('--refresh'));
  final projection = CityProjection.centeredOn(
    (_south + _north) / 2,
    (_west + _east) / 2,
  );
  final (minX, minZ) = projection.project(_south, _west);
  final (maxX, maxZ) = projection.project(_north, _east);
  final box = (minX: minX, minZ: minZ, maxX: maxX, maxZ: maxZ);
  final osm = OsmShapes(projection, box);

  Future<List<Map<String, dynamic>>> query(String name, String filters) =>
      overpass.query(name, '[out:json][timeout:170][bbox:$_bbox];$filters');

  // Zones gather around the centers the server uses for distances, which
  // sit in each district's urban part; a district's geometric middle can
  // fall in its rural hills.
  final zoneCenters = _zoneCenters(projection);

  // Districts.
  final regions = <CityRegion>[];
  final land = MeshBuilder();
  final districts = await query(
    'districts',
    'rel["boundary"="administrative"]["admin_level"="8"]["name"~"^Localidad "];out geom;',
  );
  districts.sort((a, b) => _name(a).compareTo(_name(b)));
  for (final element in districts) {
    final name = _name(element).replaceFirst('Localidad ', '');
    final polygons = osm.polygons(element, 0.02);
    if (polygons.isEmpty) continue;
    final index = regions.length;
    for (final polygon in polygons) {
      land.addPolygon(polygon, index);
    }
    final zoneId = _zoneIds[name];
    final largest = polygons.reduce((a, b) => a.area >= b.area ? a : b);
    var label = zoneCenters[zoneId] ?? largest.labelPoint();
    if (!polygons.any((p) => p.contains(label))) {
      stderr.writeln(
        '$name: zone center outside the district, using its middle',
      );
      label = largest.labelPoint();
    }
    regions.add(
      CityRegion(
        name: name,
        zoneId: zoneId,
        labelX: label.x,
        labelZ: label.z,
        rings: [
          for (final polygon in polygons)
            for (final ring in [polygon.outer, ...polygon.holes]) _floats(ring),
        ],
      ),
    );
  }
  // Thin lines along every district outline. Neighbouring districts share
  // their boundary, so each line is drawn twice on top of itself; the
  // second copy is identical and costs only a few triangles.
  final borders = MeshBuilder();
  for (final region in regions) {
    for (final ring in region.rings) {
      final points = [
        for (var i = 0; i < ring.length; i += 2) (x: ring[i], z: ring[i + 1]),
      ];
      borders.addRibbon([...points, points.first], 0.018, 0);
    }
  }

  final missing = _zoneIds.values.toSet().difference({
    for (final r in regions) ?r.zoneId,
  });
  if (missing.isNotEmpty) {
    throw StateError('Zones without a district shape: $missing');
  }

  // Green and blue areas.
  List<Polygon> areas(List<Map<String, dynamic>> elements, double minKm2) => [
    for (final element in elements)
      for (final polygon in osm.polygons(element, 0.015))
        if (polygon.area >= minKm2) polygon,
  ];
  final forests = areas(
    await query(
      'forest',
      '(nwr["natural"="wood"];nwr["landuse"="forest"];);out geom;',
    ),
    0.15,
  );
  final parkElements = await query(
    'parks',
    'nwr["leisure"~"^(park|golf_course)\$"];out geom;',
  );
  final parks = <(Polygon, int)>[
    for (final element in parkElements)
      for (final polygon in osm.polygons(element, 0.015))
        if (polygon.area >= 0.03)
          (polygon, _tags(element)['leisure'] == 'golf_course' ? 1 : 0),
  ];
  final water = areas(
    await query('water', 'nwr["natural"="water"];out geom;'),
    0.008,
  );
  final airports = areas(
    await query('airports', 'nwr["aeroway"="aerodrome"];out geom;'),
    0.1,
  );

  final forestMesh = MeshBuilder();
  for (final polygon in forests) {
    forestMesh.addPolygon(polygon, 0);
  }
  final parkMesh = MeshBuilder();
  for (final (polygon, kind) in parks) {
    parkMesh.addPolygon(polygon, kind);
  }
  final waterMesh = MeshBuilder();
  for (final polygon in water) {
    waterMesh.addPolygon(polygon, 0);
  }
  final airportMesh = MeshBuilder();
  for (final polygon in airports) {
    airportMesh.addPolygon(polygon, 0);
  }

  // Roads, runways and rivers.
  final roads = MeshBuilder();
  void addLines(
    List<Map<String, dynamic>> elements,
    CityRoadClass Function(Map<String, String>) classOf,
  ) {
    for (final element in elements) {
      final roadClass = classOf(_tags(element));
      for (final line in osm.lines(element, 0.01)) {
        roads.addRibbon(line, _roadWidths[roadClass]!, roadClass.index);
      }
    }
  }

  addLines(
    await query('rivers', 'way["waterway"="river"];out geom;'),
    (_) => CityRoadClass.river,
  );
  addLines(
    await query(
      'roads',
      'way["highway"~"^(motorway|trunk|primary|secondary)\$"];out geom;',
    ),
    (tags) => switch (tags['highway']) {
      'motorway' || 'trunk' => CityRoadClass.major,
      'primary' => CityRoadClass.primary,
      _ => CityRoadClass.secondary,
    },
  );
  addLines(
    await query('runways', 'way["aeroway"="runway"];out geom;'),
    (_) => CityRoadClass.runway,
  );

  // Trees in parks and on the raised woods, avoiding lakes.
  final random = math.Random(2026);
  final trees = <double>[];
  void plant(Polygon polygon, double spacing, double ground) {
    final b = polygon.box;
    for (var x = b.minX; x <= b.maxX; x += spacing) {
      for (var z = b.minZ; z <= b.maxZ; z += spacing) {
        final p = (
          x: x + (random.nextDouble() - 0.5) * spacing * 0.8,
          z: z + (random.nextDouble() - 0.5) * spacing * 0.8,
        );
        if (!polygon.contains(p) || water.any((w) => w.contains(p))) continue;
        trees.addAll([p.x, p.z, 0.75 + random.nextDouble() * 0.5, ground]);
      }
    }
  }

  for (final (polygon, kind) in parks) {
    if (kind == 0 && polygon.area >= 0.05) plant(polygon, 0.12, 0);
  }
  for (final polygon in forests) {
    plant(polygon, 0.34, forestHeight);
  }
  const maxTrees = 4000;
  if (trees.length ~/ 4 > maxTrees) {
    // Thin evenly instead of dropping whole areas.
    final keep = maxTrees / (trees.length ~/ 4);
    final thinned = <double>[];
    for (var i = 0; i < trees.length; i += 4) {
      if (random.nextDouble() < keep) thinned.addAll(trees.sublist(i, i + 4));
    }
    trees
      ..clear()
      ..addAll(thinned);
  }

  // Landmarks.
  final places = await query(
    'landmarks',
    '(${[for (final (pattern, _, _) in _landmarks) 'nwr["name"~"$pattern"];'].join()});out center tags;',
  );
  final landmarks = <CityLandmark>[];
  for (final (pattern, kind, label) in _landmarks) {
    final regex = RegExp(pattern);
    final match = places
        .where((e) => regex.hasMatch(_name(e)))
        .map(osm.position)
        .nonNulls
        .firstOrNull;
    if (match == null) {
      stderr.writeln('landmark not found: $label');
      continue;
    }
    landmarks.add(
      CityLandmark(kind: kind, name: label, x: match.x, z: match.z),
    );
  }

  final asset = CityMapAsset(
    attribution: '© OpenStreetMap contributors',
    projection: projection,
    bounds: Float32List.fromList([box.minX, box.minZ, box.maxX, box.maxZ]),
    regions: regions,
    layers: {
      CityLayer.land: _mesh(land),
      CityLayer.forest: _mesh(forestMesh),
      CityLayer.park: _mesh(parkMesh),
      CityLayer.water: _mesh(waterMesh),
      CityLayer.airport: _mesh(airportMesh),
      CityLayer.borders: _mesh(borders),
      CityLayer.roads: _mesh(roads),
    },
    trees: Float32List.fromList(trees),
    landmarks: landmarks,
  );
  final bytes = asset.encode();
  final file = File('assets/map/bogota.bin')..createSync(recursive: true);
  file.writeAsBytesSync(bytes);

  stdout.writeln(
    'wrote ${file.path}: ${(bytes.length / 1024).toStringAsFixed(0)} KB',
  );
  for (final MapEntry(key: kind, value: mesh) in asset.layers.entries) {
    stdout.writeln(
      '  ${kind.name}: ${mesh.vertexCount} vertices, '
      '${mesh.indices.length ~/ 3} triangles',
    );
  }
  stdout.writeln(
    '  ${regions.length} districts, ${asset.treeCount} trees, '
    '${landmarks.length}/${_landmarks.length} landmarks',
  );
}

String _name(Map<String, dynamic> element) => _tags(element)['name'] ?? '';

Map<String, String> _tags(Map<String, dynamic> element) =>
    ((element['tags'] as Map?) ?? const {}).cast<String, String>();

Float32List _floats(List<Pt> ring) => Float32List.fromList([
  for (final p in ring) ...[p.x, p.z],
]);

CityMesh _mesh(MeshBuilder builder) => CityMesh(
  positions: Float32List.fromList(builder.positions),
  attributes: Uint8List.fromList(builder.attributes),
  indices: Uint32List.fromList(builder.indices),
);

/// Reads the zone centers from the server's catalog, the single source of
/// truth, so the map and the API's distances agree.
Map<String, Pt> _zoneCenters(CityProjection projection) {
  final catalog = File('../backend/internal/plans/catalog.go')
      .readAsStringSync();
  final entry = RegExp(
    r'ID: "(\w+)", Name: "[^"]*", Lat: (-?[\d.]+), Lng: (-?[\d.]+)',
  );
  final centers = <String, Pt>{
    for (final m in entry.allMatches(catalog))
      m[1]!: () {
        final (x, z) = projection.project(
          double.parse(m[2]!),
          double.parse(m[3]!),
        );
        return (x: x, z: z);
      }(),
  };
  final unknown = _zoneIds.values.toSet().difference(centers.keys.toSet());
  if (unknown.isNotEmpty) {
    throw StateError('Zones missing from catalog.go: $unknown');
  }
  return centers;
}
