import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:distance/features/map/city_map.dart';
import 'package:distance/shared/scene3d.dart';

/// Depth of the land slab: the city looks like a clay model standing on a
/// board.
const _slab = 0.3;

/// Builds the static city from the bundled asset.
///
/// Each layer is one merged mesh colored per vertex, so the whole city is
/// about a dozen draw calls; trees are two instanced meshes. Coplanar
/// layers are ordered with `depthLayer` rather than by lifting them, which
/// holds at every camera distance.
Node buildCityScene(CityMapAsset city) {
  final root = Node(name: 'city');
  final b = city.bounds;
  final center = vm.Vector3((b[0] + b[2]) / 2, 0, (b[1] + b[3]) / 2);

  root.add(
    meshNode(
      CuboidGeometry(vm.Vector3(b[2] - b[0] + 6, 0.1, b[3] - b[1] + 6)),
      clayMaterial(CityPalette.ground, roughness: 0.95),
      position: center + vm.Vector3(0, -_slab - 0.05, 0),
    ),
  );

  final regionColors = [
    for (final (i, region) in city.regions.indexed)
      CityPalette.region(region, i),
  ];
  final regionLinear = [for (final c in regionColors) linearColor(c)];
  final roadLinear = [
    for (final roadClass in CityRoadClass.values)
      linearColor(CityPalette.road(roadClass)),
  ];
  vm.Vector4 constant(Color color) => linearColor(color);

  void layer(
    CityLayer kind,
    vm.Vector4 Function(int attribute) color, {
    required int depthLayer,
    double roughness = 0.9,
  }) {
    final mesh = city.layers[kind];
    if (mesh == null || mesh.indices.isEmpty) return;
    root.add(
      Node(
        name: kind.name,
        mesh: Mesh(
          _flatGeometry(mesh, color),
          clayMaterial(const Color(0xFFFFFFFF), roughness: roughness)
            ..depthLayer = depthLayer,
        ),
      ),
    );
  }

  layer(CityLayer.land, (a) => regionLinear[a], depthLayer: 0);
  root.add(_sides(city, regionColors));
  final forest = constant(CityPalette.forest);
  layer(CityLayer.forest, (_) => forest, depthLayer: 2);
  final airport = constant(CityPalette.airport);
  layer(CityLayer.airport, (_) => airport, depthLayer: 1);
  final park = constant(CityPalette.park), golf = constant(CityPalette.golf);
  layer(CityLayer.park, (a) => a == 1 ? golf : park, depthLayer: 3);
  final water = constant(CityPalette.water);
  layer(CityLayer.water, (_) => water, depthLayer: 4, roughness: 0.35);
  final border = constant(CityPalette.border);
  layer(CityLayer.borders, (_) => border, depthLayer: 5);
  layer(CityLayer.roads, (a) => roadLinear[a], depthLayer: 6, roughness: 0.8);

  root.add(_trees(city));
  // Flat ground has nothing to cast shadows with, and thousands of trees
  // would be drawn again in every shadow cascade; only landmarks (and the
  // characters) cast them.
  _withoutShadows(root);
  for (final landmark in city.landmarks) {
    final prop = _landmark(landmark.kind);
    if (prop == null) continue;
    prop.position = vm.Vector3(landmark.x, 0, landmark.z);
    root.add(prop);
  }
  return root;
}

/// The flag is per node, not inherited, so set it on the whole subtree.
void _withoutShadows(Node node) {
  node.shadowCastingMode = ShadowCastingMode.off;
  for (final child in node.children) {
    _withoutShadows(child);
  }
}

/// Turns a flat layer into a mesh on the ground (y = 0) facing up.
MeshGeometry _flatGeometry(
  CityMesh mesh,
  vm.Vector4 Function(int attribute) color,
) {
  final n = mesh.vertexCount;
  final positions = Float32List(n * 3);
  final normals = Float32List(n * 3);
  final colors = Float32List(n * 4);
  for (var i = 0; i < n; i++) {
    positions[i * 3] = mesh.positions[i * 2];
    positions[i * 3 + 2] = mesh.positions[i * 2 + 1];
    normals[i * 3 + 1] = 1;
    final c = color(mesh.attributes[i]);
    colors
      ..[i * 4] = c.x
      ..[i * 4 + 1] = c.y
      ..[i * 4 + 2] = c.z
      ..[i * 4 + 3] = 1;
  }
  return MeshGeometry.fromArrays(
    positions: positions,
    normals: normals,
    colors: colors,
    indices: mesh.indices,
  );
}

/// The vertical sides of the land slab, one quad per outline edge, in a
/// darker tone of each district. Edges shared by two districts end up
/// hidden under the land; they cost a few triangles and keep this simple.
Node _sides(CityMapAsset city, List<Color> regionColors) {
  final positions = <double>[], normals = <double>[], colors = <double>[];
  final indices = <int>[];
  for (final (r, region) in city.regions.indexed) {
    final side = linearColor(CityPalette.side(regionColors[r]));
    for (final ring in region.rings) {
      final count = ring.length ~/ 2;
      // Outward is to the right of the edge for counterclockwise rings.
      var area = 0.0;
      for (var i = 0, j = count - 1; i < count; j = i++) {
        area +=
            (ring[j * 2] - ring[i * 2]) * (ring[j * 2 + 1] + ring[i * 2 + 1]);
      }
      final outward = area > 0 ? 1.0 : -1.0;
      for (var i = 0; i < count; i++) {
        final j = (i + 1) % count;
        final ax = ring[i * 2], az = ring[i * 2 + 1];
        final bx = ring[j * 2], bz = ring[j * 2 + 1];
        final dx = bx - ax, dz = bz - az;
        final length = math.sqrt(dx * dx + dz * dz);
        if (length == 0) continue;
        final nx = dz / length * outward, nz = -dx / length * outward;
        final base = positions.length ~/ 3;
        positions.addAll([
          ax,
          0,
          az,
          bx,
          0,
          bz,
          bx,
          -_slab,
          bz,
          ax,
          -_slab,
          az,
        ]);
        for (var k = 0; k < 4; k++) {
          normals.addAll([nx, 0, nz]);
          colors.addAll([side.x, side.y, side.z, 1]);
        }
        indices.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
      }
    }
  }
  final material = clayMaterial(const Color(0xFFFFFFFF), roughness: 0.9)
    // Winding depends on each ring's direction; drawing both faces avoids
    // tracking it.
    ..doubleSided = true;
  return Node(
    name: 'sides',
    mesh: Mesh(
      MeshGeometry.fromArrays(
        positions: Float32List.fromList(positions),
        normals: Float32List.fromList(normals),
        colors: Float32List.fromList(colors),
        indices: indices,
      ),
      material,
    ),
  );
}

/// Every tree of the city as two instanced meshes, crowns and trunks.
Node _trees(CityMapAsset city) {
  final crowns = InstancedMesh(
    geometry: CylinderGeometry(
      bottomRadius: 0.042,
      topRadius: 0,
      height: 0.1,
      radialSegments: 8,
    ),
    material: clayMaterial(CityPalette.treeCrown, roughness: 0.85),
  );
  final trunks = InstancedMesh(
    geometry: CylinderGeometry(
      bottomRadius: 0.012,
      topRadius: 0.01,
      height: 0.04,
      radialSegments: 6,
    ),
    material: clayMaterial(CityPalette.treeTrunk),
  );
  final t = city.trees;
  final identity = vm.Quaternion.identity();
  for (var i = 0; i < city.treeCount; i++) {
    final x = t[i * 4], z = t[i * 4 + 1], size = t[i * 4 + 2], y = t[i * 4 + 3];
    final scale = vm.Vector3.all(size);
    trunks.addInstance(
      vm.Matrix4.compose(vm.Vector3(x, y + 0.02 * size, z), identity, scale),
    );
    // Slightly different greens so woods do not look tiled.
    final shade = 0.85 + 0.15 * ((i * 37) % 11) / 10;
    crowns.addInstance(
      vm.Matrix4.compose(vm.Vector3(x, y + 0.09 * size, z), identity, scale),
      color: vm.Vector4(shade, shade, shade, 1),
    );
  }
  return Node(name: 'trees')
    ..add(Node()..addComponent(InstancedMeshComponent(trunks)))
    ..add(Node()..addComponent(InstancedMeshComponent(crowns)));
}

/// A small model for a landmark, about a few hundred metres across so it
/// reads at city scale. Parks and the airport have no model: their shapes
/// on the map already show them.
Node? _landmark(CityLandmarkKind kind) {
  final node = Node(name: 'landmark:${kind.name}');
  Node part(
    Geometry geometry,
    Color color,
    double x,
    double y,
    double z, {
    vm.Vector3? scale,
    double roughness = 0.7,
  }) => meshNode(
    geometry,
    clayMaterial(color, roughness: roughness),
    position: vm.Vector3(x, y, z),
    scale: scale,
  );

  const stone = Color(0xFFF2EBE3), roof = Color(0xFFE07A5F);
  switch (kind) {
    case CityLandmarkKind.mountain:
      node
        ..add(
          part(
            CylinderGeometry(bottomRadius: 0.6, topRadius: 0.06, height: 0.55),
            const Color(0xFF8FBF86),
            0,
            0.275,
            0,
          ),
        )
        ..add(part(CuboidGeometry(vm.Vector3.all(0.07)), stone, 0, 0.585, 0))
        ..add(
          part(
            CylinderGeometry(
              bottomRadius: 0.06,
              topRadius: 0,
              height: 0.06,
              radialSegments: 4,
            ),
            roof,
            0,
            0.65,
            0,
          ),
        );
    case CityLandmarkKind.plaza:
      node
        ..add(
          part(
            CuboidGeometry(vm.Vector3(0.26, 0.012, 0.26)),
            stone,
            0,
            0.006,
            0,
          ),
        )
        ..add(
          part(
            CuboidGeometry(vm.Vector3(0.14, 0.09, 0.07)),
            stone,
            0,
            0.055,
            0.12,
          ),
        )
        ..add(
          part(
            CylinderGeometry(
              bottomRadius: 0.025,
              topRadius: 0.02,
              height: 0.16,
            ),
            stone,
            -0.055,
            0.09,
            0.12,
          ),
        )
        ..add(
          part(
            CylinderGeometry(
              bottomRadius: 0.025,
              topRadius: 0.02,
              height: 0.16,
            ),
            stone,
            0.055,
            0.09,
            0.12,
          ),
        );
    case CityLandmarkKind.tower:
      node
        ..add(
          part(
            CuboidGeometry(vm.Vector3(0.07, 0.4, 0.07)),
            const Color(0xFFBFD9F2),
            0,
            0.2,
            0,
            roughness: 0.3,
          ),
        )
        ..add(
          meshNode(
            CuboidGeometry(vm.Vector3(0.072, 0.03, 0.072)),
            glowMaterial(const Color(0xFFFF6F91)),
            position: vm.Vector3(0, 0.41, 0),
          ),
        );
    case CityLandmarkKind.stadium:
      node
        ..add(
          part(
            TorusGeometry(radius: 0.13, tubeRadius: 0.045, tubularSegments: 10),
            const Color(0xFFFFFFFF),
            0,
            0.04,
            0,
            scale: vm.Vector3(1.25, 1, 1),
          ),
        )
        ..add(
          part(
            CylinderGeometry(bottomRadius: 0.12, topRadius: 0.12, height: 0.01),
            const Color(0xFF7CC67A),
            0,
            0.005,
            0,
            scale: vm.Vector3(1.25, 1, 1),
          ),
        );
    case CityLandmarkKind.campus:
      for (final (x, z, h) in const [
        (-0.09, 0.0, 0.08),
        (0.06, 0.07, 0.12),
        (0.05, -0.08, 0.06),
      ]) {
        node.add(
          part(
            CuboidGeometry(vm.Vector3(0.09, h, 0.07)),
            const Color(0xFFFFEBD2),
            x,
            h / 2,
            z,
          ),
        );
      }
    case CityLandmarkKind.museum:
      node.add(
        meshNode(
          CuboidGeometry(vm.Vector3(0.12, 0.07, 0.12)),
          PhysicallyBasedMaterial()
            ..baseColorFactor = linearColor(const Color(0xFFF2C14E))
            ..metallicFactor = 0.8
            ..roughnessFactor = 0.35,
          position: vm.Vector3(0, 0.035, 0),
        ),
      );
    case CityLandmarkKind.arena || CityLandmarkKind.dome:
      node.add(
        part(
          SphereGeometry(radius: 0.13, segments: 24, rings: 12),
          kind == CityLandmarkKind.arena
              ? const Color(0xFFF7F4FF)
              : const Color(0xFFCFE3FF),
          0,
          0,
          0,
          scale: vm.Vector3(1, 0.6, 1),
          roughness: 0.4,
        ),
      );
    case CityLandmarkKind.park || CityLandmarkKind.airport:
      return null;
  }
  return node;
}
