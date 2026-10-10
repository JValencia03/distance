import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// The city drawn on the plans map, prepared offline by
/// `tool/build_city_map.dart` from OpenStreetMap data and bundled as an
/// asset, so the app needs no network or map service to show it.
///
/// Coordinates are kilometres on a flat projection centered on the city:
/// x grows east and z grows north. Geometry is already simplified and
/// triangulated; the app only turns these arrays into GPU buffers.
///
/// This file is plain Dart (no Flutter imports) so the tool can share it.
class CityMapAsset {
  const CityMapAsset({
    required this.attribution,
    required this.projection,
    required this.bounds,
    required this.regions,
    required this.layers,
    required this.trees,
    required this.landmarks,
  });

  /// Text the data license requires to be shown with the map.
  final String attribution;
  final CityProjection projection;

  /// Extent of the drawn city: minX, minZ, maxX, maxZ.
  final Float32List bounds;

  /// City districts, the shapes zones are drawn with.
  final List<CityRegion> regions;
  final Map<CityLayer, CityMesh> layers;

  /// Trees: x, z, a size factor and the height of the ground they stand on,
  /// four floats per tree.
  final Float32List trees;
  final List<CityLandmark> landmarks;

  int get treeCount => trees.length ~/ 4;

  static const _magic = 0x50414d44; // "DMAP" little-endian.
  static const version = 1;

  /// Serializes the asset. Layout (little-endian): magic, version, metadata
  /// length, UTF-8 JSON metadata padded to 4 bytes, then the arrays in the
  /// order the metadata lists them.
  Uint8List encode() {
    final meta = utf8.encode(
      jsonEncode({
        'attribution': attribution,
        'projection': projection.toJson(),
        'bounds': bounds.toList(),
        'regions': [
          for (final r in regions)
            {
              'name': r.name,
              'zoneId': r.zoneId,
              'label': [r.labelX, r.labelZ],
              'rings': [for (final ring in r.rings) ring.length ~/ 2],
            },
        ],
        'layers': [
          for (final MapEntry(key: kind, value: mesh) in layers.entries)
            {
              'kind': kind.name,
              'vertexCount': mesh.vertexCount,
              'indexCount': mesh.indices.length,
            },
        ],
        'treeCount': treeCount,
        'landmarks': [for (final l in landmarks) l.toJson()],
      }),
    );
    final out = BytesBuilder(copy: false);
    final header = ByteData(12)
      ..setUint32(0, _magic, Endian.little)
      ..setUint32(4, version, Endian.little)
      ..setUint32(8, meta.length, Endian.little);
    out.add(header.buffer.asUint8List());
    out.add(meta);
    _pad(out);
    for (final mesh in layers.values) {
      out.add(_bytes(mesh.positions));
      out.add(mesh.attributes);
      _pad(out);
      out.add(_bytes(mesh.indices));
    }
    for (final region in regions) {
      for (final ring in region.rings) {
        out.add(_bytes(ring));
      }
    }
    out.add(_bytes(trees));
    return out.takeBytes();
  }

  factory CityMapAsset.decode(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    if (bytes.length < 12 || data.getUint32(0, Endian.little) != _magic) {
      throw const FormatException('Not a city map asset');
    }
    if (data.getUint32(4, Endian.little) != version) {
      throw const FormatException('Unsupported city map version');
    }
    final metaLength = data.getUint32(8, Endian.little);
    final meta = jsonDecode(
      utf8.decode(bytes.sublist(12, 12 + metaLength)),
    ) as Map<String, dynamic>;
    var offset = _aligned(12 + metaLength);

    // Copies keep every typed list aligned regardless of the source buffer.
    Float32List floats(int count) {
      final list = Float32List(count);
      list.buffer.asUint8List().setAll(
        0,
        bytes.sublist(offset, offset + count * 4),
      );
      offset += count * 4;
      return list;
    }

    Uint32List uints(int count) {
      final list = Uint32List(count);
      list.buffer.asUint8List().setAll(
        0,
        bytes.sublist(offset, offset + count * 4),
      );
      offset += count * 4;
      return list;
    }

    final layers = <CityLayer, CityMesh>{};
    for (final layer in meta['layers'] as List) {
      final info = layer as Map<String, dynamic>;
      final vertexCount = info['vertexCount'] as int;
      final positions = floats(vertexCount * 2);
      final attributes = Uint8List.fromList(
        bytes.sublist(offset, offset + vertexCount),
      );
      offset = _aligned(offset + vertexCount);
      final indices = uints(info['indexCount'] as int);
      layers[CityLayer.values.byName(info['kind'] as String)] = CityMesh(
        positions: positions,
        attributes: attributes,
        indices: indices,
      );
    }

    final regions = <CityRegion>[];
    for (final region in meta['regions'] as List) {
      final info = region as Map<String, dynamic>;
      final label = (info['label'] as List).cast<num>();
      regions.add(
        CityRegion(
          name: info['name'] as String,
          zoneId: info['zoneId'] as String?,
          labelX: label[0].toDouble(),
          labelZ: label[1].toDouble(),
          rings: [
            for (final count in (info['rings'] as List).cast<int>())
              floats(count * 2),
          ],
        ),
      );
    }
    final trees = floats((meta['treeCount'] as int) * 4);

    return CityMapAsset(
      attribution: meta['attribution'] as String,
      projection: CityProjection.fromJson(
        meta['projection'] as Map<String, dynamic>,
      ),
      bounds: Float32List.fromList([
        for (final v in (meta['bounds'] as List).cast<num>()) v.toDouble(),
      ]),
      regions: regions,
      layers: layers,
      trees: trees,
      landmarks: [
        for (final l in meta['landmarks'] as List)
          CityLandmark.fromJson(l as Map<String, dynamic>),
      ],
    );
  }

  static int _aligned(int offset) => (offset + 3) & ~3;

  static void _pad(BytesBuilder out) {
    while (out.length % 4 != 0) {
      out.addByte(0);
    }
  }

  static Uint8List _bytes(TypedData list) =>
      list.buffer.asUint8List(list.offsetInBytes, list.lengthInBytes);
}

/// The layers of the city, drawn bottom to top.
enum CityLayer {
  /// District shapes; each vertex's attribute is its region index.
  land,

  /// Wooded areas, such as the eastern hills.
  forest,
  park,
  water,
  airport,

  /// Lines between districts.
  borders,

  /// Roads and runways as ribbons; the attribute is a [CityRoadClass]
  /// index.
  roads,
}

enum CityRoadClass { major, primary, secondary, runway, river }

/// Triangles in the xz plane, wound to face up (+y).
class CityMesh {
  const CityMesh({
    required this.positions,
    required this.attributes,
    required this.indices,
  });

  /// x, z per vertex.
  final Float32List positions;

  /// One byte per vertex whose meaning depends on the layer.
  final Uint8List attributes;
  final Uint32List indices;

  int get vertexCount => positions.length ~/ 2;
}

class CityRegion {
  const CityRegion({
    required this.name,
    required this.zoneId,
    required this.labelX,
    required this.labelZ,
    required this.rings,
  });

  /// District name, as people call it ("Chapinero").
  final String name;

  /// The app zone this district is, or null for districts the zone catalog
  /// does not include.
  final String? zoneId;

  /// A point well inside the district, where its name and people go.
  final double labelX;
  final double labelZ;

  /// Outlines as x, z pairs; the first is the outer boundary.
  final List<Float32List> rings;
}

/// A recognizable place drawn with a small model and its name.
class CityLandmark {
  const CityLandmark({
    required this.kind,
    required this.name,
    required this.x,
    required this.z,
  });

  factory CityLandmark.fromJson(Map<String, dynamic> json) => CityLandmark(
    kind: CityLandmarkKind.values.byName(json['kind'] as String),
    name: json['name'] as String,
    x: (json['x'] as num).toDouble(),
    z: (json['z'] as num).toDouble(),
  );

  final CityLandmarkKind kind;
  final String name;
  final double x;
  final double z;

  Map<String, Object> toJson() => {
    'kind': kind.name,
    'name': name,
    'x': x,
    'z': z,
  };
}

enum CityLandmarkKind {
  mountain,
  plaza,
  tower,
  stadium,
  campus,
  museum,
  arena,
  dome,
  park,
  airport,
}

/// Equirectangular projection around [lat0], [lng0], accurate to a few
/// metres across a city.
class CityProjection {
  const CityProjection({
    required this.lat0,
    required this.lng0,
    required this.kmPerDegreeLat,
    required this.kmPerDegreeLng,
  });

  factory CityProjection.centeredOn(double lat0, double lng0) {
    const earthRadiusKm = 6371.0088;
    const kmPerDegree = earthRadiusKm * math.pi / 180;
    return CityProjection(
      lat0: lat0,
      lng0: lng0,
      kmPerDegreeLat: kmPerDegree,
      kmPerDegreeLng: kmPerDegree * math.cos(lat0 * math.pi / 180),
    );
  }

  factory CityProjection.fromJson(Map<String, dynamic> json) => CityProjection(
    lat0: (json['lat0'] as num).toDouble(),
    lng0: (json['lng0'] as num).toDouble(),
    kmPerDegreeLat: (json['kmPerDegreeLat'] as num).toDouble(),
    kmPerDegreeLng: (json['kmPerDegreeLng'] as num).toDouble(),
  );

  final double lat0;
  final double lng0;
  final double kmPerDegreeLat;
  final double kmPerDegreeLng;

  /// Returns x (east) and z (north) in kilometres.
  (double, double) project(double lat, double lng) =>
      ((lng - lng0) * kmPerDegreeLng, (lat - lat0) * kmPerDegreeLat);

  Map<String, double> toJson() => {
    'lat0': lat0,
    'lng0': lng0,
    'kmPerDegreeLat': kmPerDegreeLat,
    'kmPerDegreeLng': kmPerDegreeLng,
  };
}
