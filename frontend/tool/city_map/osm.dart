// Downloads OpenStreetMap data through the Overpass API and turns its
// elements into projected polygons and lines.
import 'dart:convert';
import 'dart:io';

import 'package:distance/features/map/city_map_asset.dart';

import 'geometry.dart';

/// Runs Overpass queries, caching each answer under .dart_tool so the map
/// can be rebuilt offline and the public server is asked only once.
class Overpass {
  Overpass({required this.refresh});

  /// Ignore the cache and download again.
  final bool refresh;

  static final _endpoint = Uri.parse('https://overpass-api.de/api/interpreter');
  static final _cache = Directory('.dart_tool/city_map_cache');

  Future<List<Map<String, dynamic>>> query(String name, String body) async {
    final file = File('${_cache.path}/$name.json');
    if (refresh || !file.existsSync()) {
      _cache.createSync(recursive: true);
      file.writeAsStringSync(await _download(name, body));
    }
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return (json['elements'] as List).cast<Map<String, dynamic>>();
  }

  /// Downloads politely: one query at a time, waiting longer after each
  /// "too many requests" or "busy" answer, as the server's policy asks.
  Future<String> _download(String name, String body) async {
    for (var attempt = 1; ; attempt++) {
      stdout.writeln('downloading $name (attempt $attempt)…');
      final client = HttpClient()
        // Overpass asks clients to identify themselves.
        ..userAgent = 'distance-city-map-builder/1 (offline development tool)';
      try {
        final request = await client.postUrl(_endpoint);
        request.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        request.write('data=${Uri.encodeQueryComponent(body)}');
        final response = await request.close();
        final text = await response.transform(utf8.decoder).join();
        if (response.statusCode == 200) return text;
        final retryable =
            response.statusCode == 429 || response.statusCode == 504;
        if (!retryable || attempt == 6) {
          throw HttpException('Overpass ${response.statusCode} for $name');
        }
      } finally {
        client.close();
      }
      await Future<void>.delayed(Duration(seconds: 20 * attempt));
    }
  }
}

/// Projects OSM geometry and simplifies it with [tolerance] kilometres.
class OsmShapes {
  OsmShapes(this.projection, this.box);

  final CityProjection projection;
  final Box box;

  List<Pt> _line(List geometry, double tolerance) {
    final points = <Pt>[
      for (final node in geometry.cast<Map<String, dynamic>>()) _project(node),
    ];
    return simplify(points, tolerance);
  }

  Pt _project(Map<String, dynamic> node) {
    final (x, z) = projection.project(
      (node['lat'] as num).toDouble(),
      (node['lon'] as num).toDouble(),
    );
    return (x: x, z: z);
  }

  /// Polygons of a closed way or a multipolygon relation, clipped to the
  /// city box.
  List<Polygon> polygons(Map<String, dynamic> element, double tolerance) {
    final outers = <List<Pt>>[];
    final inners = <List<Pt>>[];
    switch (element['type']) {
      case 'way':
        final geometry = element['geometry'] as List?;
        if (geometry != null) outers.add(_line(geometry, tolerance));
      case 'relation':
        for (final member
            in (element['members'] as List).cast<Map<String, dynamic>>()) {
          final geometry = member['geometry'] as List?;
          if (member['type'] != 'way' || geometry == null) continue;
          final line = _line(geometry, tolerance);
          (member['role'] == 'inner' ? inners : outers).add(line);
        }
    }
    List<List<Pt>> clipped(List<List<Pt>> lines) => [
      for (final ring in assembleRings(lines))
        if (clipRing(ring, box) case final r when r.isNotEmpty) r,
    ];
    return groupRings(clipped(outers), clipped(inners));
  }

  /// Parts of a way inside the city box, as polylines.
  List<List<Pt>> lines(Map<String, dynamic> element, double tolerance) {
    final geometry = element['geometry'] as List?;
    if (geometry == null) return const [];
    final result = <List<Pt>>[];
    var run = <Pt>[];
    for (final p in _line(geometry, tolerance)) {
      if (_inside(p)) {
        run.add(p);
      } else {
        if (run.length >= 2) result.add(run);
        run = [];
      }
    }
    if (run.length >= 2) result.add(run);
    return result;
  }

  bool _inside(Pt p) =>
      p.x >= box.minX && p.x <= box.maxX && p.z >= box.minZ && p.z <= box.maxZ;

  /// Where a node, or the center Overpass computed for a way or relation,
  /// is.
  Pt? position(Map<String, dynamic> element) {
    final at = element['center'] ?? (element['lat'] != null ? element : null);
    return at == null ? null : _project(at as Map<String, dynamic>);
  }
}
