// Plane geometry for building the city map offline. Points are kilometres:
// x grows east, z grows north.
import 'dart:math' as math;

import 'earcut.dart';

typedef Pt = ({double x, double z});

/// Axis-aligned rectangle used to clip the city.
typedef Box = ({double minX, double minZ, double maxX, double maxZ});

/// Douglas–Peucker simplification. Keeps both endpoints, so lines that
/// share an endpoint still meet after simplifying each one on its own.
List<Pt> simplify(List<Pt> points, double tolerance) {
  if (points.length <= 2) return points;
  final keep = List<bool>.filled(points.length, false)
    ..[0] = true
    ..[points.length - 1] = true;
  final stack = <(int, int)>[(0, points.length - 1)];
  while (stack.isNotEmpty) {
    final (first, last) = stack.removeLast();
    var maxDistance = 0.0;
    var index = -1;
    for (var i = first + 1; i < last; i++) {
      final d = distanceToSegment(points[i], points[first], points[last]);
      if (d > maxDistance) {
        maxDistance = d;
        index = i;
      }
    }
    if (index != -1 && maxDistance > tolerance) {
      keep[index] = true;
      stack
        ..add((first, index))
        ..add((index, last));
    }
  }
  return [
    for (var i = 0; i < points.length; i++)
      if (keep[i]) points[i],
  ];
}

double distanceToSegment(Pt p, Pt a, Pt b) {
  final dx = b.x - a.x, dz = b.z - a.z;
  final lengthSquared = dx * dx + dz * dz;
  var t = lengthSquared == 0
      ? 0.0
      : ((p.x - a.x) * dx + (p.z - a.z) * dz) / lengthSquared;
  t = t.clamp(0.0, 1.0);
  final x = a.x + t * dx - p.x, z = a.z + t * dz - p.z;
  return math.sqrt(x * x + z * z);
}

/// Joins open lines into closed rings by matching endpoints, as OSM
/// multipolygon members require. Lines that never close are dropped.
List<List<Pt>> assembleRings(List<List<Pt>> lines) {
  final pending = [
    for (final line in lines)
      if (line.length >= 2) [...line],
  ];
  final rings = <List<Pt>>[];
  while (pending.isNotEmpty) {
    final ring = pending.removeLast();
    var progress = true;
    while (!_same(ring.first, ring.last) && progress) {
      progress = false;
      for (var i = 0; i < pending.length; i++) {
        final line = pending[i];
        if (_same(line.first, ring.last)) {
          ring.addAll(line.skip(1));
        } else if (_same(line.last, ring.last)) {
          ring.addAll(line.reversed.skip(1));
        } else if (_same(line.last, ring.first)) {
          ring.insertAll(0, line.take(line.length - 1));
        } else if (_same(line.first, ring.first)) {
          ring.insertAll(0, line.reversed.take(line.length - 1));
        } else {
          continue;
        }
        pending.removeAt(i);
        progress = true;
        break;
      }
    }
    if (_same(ring.first, ring.last) && ring.length >= 4) {
      rings.add(ring..removeLast());
    }
  }
  return rings;
}

bool _same(Pt a, Pt b) => a.x == b.x && a.z == b.z;

/// Clips a closed ring to [box] (Sutherland–Hodgman). Returns an empty
/// list when the ring is entirely outside.
List<Pt> clipRing(List<Pt> ring, Box box) {
  var output = ring;
  for (final edge in _ClipEdge.values) {
    if (output.isEmpty) break;
    final input = output;
    output = [];
    for (var i = 0; i < input.length; i++) {
      final current = input[i];
      final previous = input[(i + input.length - 1) % input.length];
      final currentIn = edge.inside(current, box);
      final previousIn = edge.inside(previous, box);
      if (currentIn) {
        if (!previousIn) output.add(edge.intersect(previous, current, box));
        output.add(current);
      } else if (previousIn) {
        output.add(edge.intersect(previous, current, box));
      }
    }
  }
  return output.length >= 3 ? output : const [];
}

enum _ClipEdge {
  west,
  east,
  south,
  north;

  bool inside(Pt p, Box b) => switch (this) {
    west => p.x >= b.minX,
    east => p.x <= b.maxX,
    south => p.z >= b.minZ,
    north => p.z <= b.maxZ,
  };

  Pt intersect(Pt a, Pt c, Box b) {
    double lerp(double from, double to, double t) => from + (to - from) * t;
    switch (this) {
      case west || east:
        final x = this == west ? b.minX : b.maxX;
        final t = (x - a.x) / (c.x - a.x);
        return (x: x, z: lerp(a.z, c.z, t));
      case south || north:
        final z = this == south ? b.minZ : b.maxZ;
        final t = (z - a.z) / (c.z - a.z);
        return (x: lerp(a.x, c.x, t), z: z);
    }
  }
}

/// Shoelace area, positive for counterclockwise rings (x right, z up).
double signedArea(List<Pt> ring) {
  var sum = 0.0;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    sum += (ring[j].x - ring[i].x) * (ring[j].z + ring[i].z);
  }
  return sum / 2;
}

bool pointInRing(Pt p, List<Pt> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final a = ring[i], b = ring[j];
    if ((a.z > p.z) != (b.z > p.z) &&
        p.x < (b.x - a.x) * (p.z - a.z) / (b.z - a.z) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

/// An outer ring with the holes cut out of it.
class Polygon {
  Polygon(this.outer, [List<List<Pt>>? holes]) : holes = holes ?? [];

  final List<Pt> outer;
  final List<List<Pt>> holes;

  double get area =>
      signedArea(outer).abs() -
      holes.fold(0.0, (sum, h) => sum + signedArea(h).abs());

  late final Box box = boxOf(outer);

  bool contains(Pt p) =>
      p.x >= box.minX &&
      p.x <= box.maxX &&
      p.z >= box.minZ &&
      p.z <= box.maxZ &&
      pointInRing(p, outer) &&
      !holes.any((h) => pointInRing(p, h));

  /// A point well inside the polygon, far from its edges, for labels.
  /// Searches a grid, which is plenty offline.
  Pt labelPoint() {
    const steps = 48;
    Pt? best;
    var bestDistance = -1.0;
    for (var i = 0; i <= steps; i++) {
      for (var j = 0; j <= steps; j++) {
        final p = (
          x: box.minX + (box.maxX - box.minX) * i / steps,
          z: box.minZ + (box.maxZ - box.minZ) * j / steps,
        );
        if (!contains(p)) continue;
        final d = [
          outer,
          ...holes,
        ].map((ring) => _distanceToRing(p, ring)).reduce(math.min);
        if (d > bestDistance) {
          bestDistance = d;
          best = p;
        }
      }
    }
    return best ?? outer.first;
  }
}

double _distanceToRing(Pt p, List<Pt> ring) {
  var best = double.infinity;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    best = math.min(best, distanceToSegment(p, ring[j], ring[i]));
  }
  return best;
}

Box boxOf(Iterable<Pt> points) {
  var minX = double.infinity, minZ = double.infinity;
  var maxX = double.negativeInfinity, maxZ = double.negativeInfinity;
  for (final p in points) {
    minX = math.min(minX, p.x);
    maxX = math.max(maxX, p.x);
    minZ = math.min(minZ, p.z);
    maxZ = math.max(maxZ, p.z);
  }
  return (minX: minX, minZ: minZ, maxX: maxX, maxZ: maxZ);
}

/// Groups rings into polygons: each inner ring goes to the outer ring that
/// contains it.
List<Polygon> groupRings(List<List<Pt>> outers, List<List<Pt>> inners) {
  final polygons = [for (final o in outers) Polygon(o)];
  for (final inner in inners) {
    for (final polygon in polygons) {
      if (pointInRing(inner.first, polygon.outer)) {
        polygon.holes.add(inner);
        break;
      }
    }
  }
  return polygons;
}

/// Growing triangle mesh in the xz plane with one attribute byte per
/// vertex.
class MeshBuilder {
  final positions = <double>[];
  final attributes = <int>[];
  final indices = <int>[];

  int get vertexCount => attributes.length;

  int addVertex(Pt p, int attribute) {
    positions
      ..add(p.x)
      ..add(p.z);
    attributes.add(attribute);
    return attributes.length - 1;
  }

  /// Adds a triangle wound so it faces up (+y). Looking down with x east
  /// and z north, an up-facing triangle is clockwise.
  void addTriangle(int a, int b, int c) {
    final ax = positions[a * 2], az = positions[a * 2 + 1];
    final bx = positions[b * 2], bz = positions[b * 2 + 1];
    final cx = positions[c * 2], cz = positions[c * 2 + 1];
    final cross = (bx - ax) * (cz - az) - (bz - az) * (cx - ax);
    if (cross == 0) return; // Degenerate.
    if (cross < 0) {
      indices.addAll([a, b, c]);
    } else {
      indices.addAll([a, c, b]);
    }
  }

  /// Triangulates [polygon] and adds it with [attribute].
  void addPolygon(Polygon polygon, int attribute) {
    final flat = <double>[];
    final holeStarts = <int>[];
    final points = <Pt>[];
    for (final ring in [polygon.outer, ...polygon.holes]) {
      if (ring != polygon.outer) holeStarts.add(points.length);
      for (final p in ring) {
        flat
          ..add(p.x)
          ..add(p.z);
        points.add(p);
      }
    }
    final base = vertexCount;
    for (final p in points) {
      addVertex(p, attribute);
    }
    final triangles = earcut(flat, holeStarts);
    for (var i = 0; i < triangles.length; i += 3) {
      addTriangle(
        base + triangles[i],
        base + triangles[i + 1],
        base + triangles[i + 2],
      );
    }
  }

  /// Adds a ribbon of [width] along [line], with mitred joins so the strip
  /// stays continuous around bends.
  void addRibbon(List<Pt> line, double width, int attribute) {
    if (line.length < 2) return;
    final half = width / 2;
    int? previousLeft, previousRight;
    for (var i = 0; i < line.length; i++) {
      final p = line[i];
      final before = line[math.max(i - 1, 0)];
      final after = line[math.min(i + 1, line.length - 1)];
      final (nx1, nz1) = _normal(before, i == 0 ? after : p);
      final (nx2, nz2) = _normal(i == line.length - 1 ? before : p, after);
      var mx = nx1 + nx2, mz = nz1 + nz2;
      final length = math.sqrt(mx * mx + mz * mz);
      if (length < 1e-9) {
        (mx, mz) = (nx1, nz1);
      } else {
        mx /= length;
        mz /= length;
      }
      // Mitre length, capped so sharp turns do not spike.
      final cos = mx * nx1 + mz * nz1;
      final scale = half / math.max(cos, 0.5);
      final left = addVertex((
        x: p.x + mx * scale,
        z: p.z + mz * scale,
      ), attribute);
      final right = addVertex((
        x: p.x - mx * scale,
        z: p.z - mz * scale,
      ), attribute);
      if (previousLeft != null) {
        addTriangle(previousLeft, previousRight!, right);
        addTriangle(previousLeft, right, left);
      }
      previousLeft = left;
      previousRight = right;
    }
  }

  static (double, double) _normal(Pt a, Pt b) {
    final dx = b.x - a.x, dz = b.z - a.z;
    final length = math.sqrt(dx * dx + dz * dz);
    if (length == 0) return (0, 0);
    return (-dz / length, dx / length);
  }
}
