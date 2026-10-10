import 'package:flutter_test/flutter_test.dart';

import '../../tool/city_map/earcut.dart';
import '../../tool/city_map/geometry.dart';

/// Area covered by triangles over flat x, y data.
double trianglesArea(List<double> data, List<int> triangles) {
  var sum = 0.0;
  for (var i = 0; i < triangles.length; i += 3) {
    final a = triangles[i] * 2,
        b = triangles[i + 1] * 2,
        c = triangles[i + 2] * 2;
    sum +=
        ((data[b] - data[a]) * (data[c + 1] - data[a + 1]) -
                (data[b + 1] - data[a + 1]) * (data[c] - data[a]))
            .abs() /
        2;
  }
  return sum;
}

List<Pt> square(double size, {double x = 0, double z = 0}) => [
  (x: x, z: z),
  (x: x + size, z: z),
  (x: x + size, z: z + size),
  (x: x, z: z + size),
];

void main() {
  group('earcut', () {
    test('covers a concave polygon exactly', () {
      // An L shape of area 3.
      final data = <double>[0, 0, 2, 0, 2, 1, 1, 1, 1, 2, 0, 2];
      final triangles = earcut(data);
      expect(triangles, hasLength(4 * 3));
      expect(trianglesArea(data, triangles), closeTo(3, 1e-9));
    });

    test('leaves holes uncovered', () {
      final data = <double>[
        ...<double>[0, 0, 4, 0, 4, 4, 0, 4], // Outer 4×4.
        ...<double>[1, 1, 1, 3, 3, 3, 3, 1], // Hole 2×2.
      ];
      final triangles = earcut(data, [4]);
      expect(trianglesArea(data, triangles), closeTo(12, 1e-9));
    });

    test('survives duplicate points and degenerate rings', () {
      expect(earcut(<double>[0, 0, 1, 0, 1, 0, 1, 1, 0, 1]), isNotEmpty);
      expect(earcut(<double>[0, 0, 1, 1]), isEmpty);
    });
  });

  test('simplify keeps endpoints and drops near-collinear points', () {
    final line = [
      for (var i = 0; i <= 10; i++) (x: i.toDouble(), z: i == 5 ? 0.001 : 0.0),
    ];
    expect(simplify(line, 0.01), [line.first, line.last]);
    final bent = [...line, (x: 10.0, z: 5.0)];
    expect(simplify(bent, 0.01), [line.first, line.last, bent.last]);
  });

  test('assembleRings joins lines in any direction into closed rings', () {
    final rings = assembleRings([
      [(x: 0.0, z: 0.0), (x: 1.0, z: 0.0)],
      // Reversed piece.
      [(x: 1.0, z: 1.0), (x: 1.0, z: 0.0)],
      [(x: 1.0, z: 1.0), (x: 0.0, z: 1.0), (x: 0.0, z: 0.0)],
      // Never closes.
      [(x: 5.0, z: 5.0), (x: 6.0, z: 5.0)],
    ]);
    expect(rings, hasLength(1));
    expect(rings.single, hasLength(4));
    expect(signedArea(rings.single).abs(), closeTo(1, 1e-9));
  });

  test('clipRing cuts a polygon to the box', () {
    const box = (minX: 0.0, minZ: 0.0, maxX: 2.0, maxZ: 2.0);
    final clipped = clipRing(square(2, x: 1, z: 1), box);
    expect(signedArea(clipped).abs(), closeTo(1, 1e-9));
    expect(clipRing(square(1, x: 5, z: 5), box), isEmpty);
  });

  test('Polygon.labelPoint stays inside concave shapes', () {
    // A U shape whose bounding-box center is in the gap.
    final u = Polygon([
      (x: 0, z: 0),
      (x: 3, z: 0),
      (x: 3, z: 3),
      (x: 2, z: 3),
      (x: 2, z: 1),
      (x: 1, z: 1),
      (x: 1, z: 3),
      (x: 0, z: 3),
    ]);
    expect(u.contains(u.labelPoint()), isTrue);
  });

  group('MeshBuilder', () {
    /// Every triangle must face up: clockwise seen from above, with x east
    /// and z north.
    void expectFacingUp(MeshBuilder mesh) {
      final p = mesh.positions;
      for (var i = 0; i < mesh.indices.length; i += 3) {
        final a = mesh.indices[i] * 2,
            b = mesh.indices[i + 1] * 2,
            c = mesh.indices[i + 2] * 2;
        final cross =
            (p[b] - p[a]) * (p[c + 1] - p[a + 1]) -
            (p[b + 1] - p[a + 1]) * (p[c] - p[a]);
        expect(cross, lessThan(0), reason: 'triangle ${i ~/ 3}');
      }
    }

    test('polygons face up whatever their ring direction', () {
      final mesh = MeshBuilder()
        ..addPolygon(Polygon(square(1)), 3)
        ..addPolygon(Polygon(square(1, x: 2).reversed.toList()), 4);
      expect(mesh.indices, hasLength(4 * 3));
      expect(mesh.attributes.toSet(), {3, 4});
      expectFacingUp(mesh);
    });

    test('ribbons follow the line with the given width', () {
      final mesh = MeshBuilder()
        ..addRibbon([(x: 0, z: 0), (x: 1, z: 0), (x: 1, z: 1)], 0.2, 1);
      expect(mesh.vertexCount, 6);
      expect(mesh.indices, hasLength(4 * 3));
      expectFacingUp(mesh);
      // The first two vertices sit 0.1 either side of the start.
      expect(mesh.positions.sublist(0, 4), [0, 0.1, 0, -0.1]);
    });
  });
}
