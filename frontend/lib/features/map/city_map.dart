import 'package:flutter/services.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'package:distance/data/models.dart';
import 'package:distance/features/map/city_map_asset.dart';

export 'package:distance/features/map/city_map_asset.dart';

Future<CityMapAsset>? _bogota;

/// The bundled city, decoded once and kept for the rest of the session.
Future<CityMapAsset> loadCityMap() => _bogota ??= rootBundle
    .load('assets/map/bogota.bin')
    .then(
      (data) => CityMapAsset.decode(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      ),
    );

extension CityPlaces on CityMapAsset {
  /// Where people of [zone] gather: the middle of its district, or, for a
  /// zone the asset does not draw, its position from the API mapped onto
  /// the city's extent.
  vm.Vector3 placeOf(MapZone zone) {
    for (final region in regions) {
      if (region.zoneId == zone.id) {
        return vm.Vector3(region.labelX, 0, region.labelZ);
      }
    }
    return vm.Vector3(
      bounds[0] + zone.x * (bounds[2] - bounds[0]),
      0,
      bounds[3] - zone.y * (bounds[3] - bounds[1]),
    );
  }

  /// Index of the district of [zoneId], or -1.
  int regionOf(String zoneId) => regions.indexWhere((r) => r.zoneId == zoneId);
}

/// Colors of the city, shared by the 3D scene and the flat map. Pastel
/// like the rest of the app; districts that are app zones get their own
/// tint, the others a soft neutral.
abstract final class CityPalette {
  static const _zones = {
    'usaquen': Color(0xFFFFD7A8),
    'chapinero': Color(0xFFD2C4FF),
    'teusaquillo': Color(0xFFBDE5D0),
    'candelaria': Color(0xFFFFC9D5),
    'suba': Color(0xFFC4DFFF),
    'engativa': Color(0xFFFFE9A6),
    'fontibon': Color(0xFFD9EDB8),
    'kennedy': Color(0xFFFFCDB6),
  };

  static Color region(CityRegion region, int index) =>
      _zones[region.zoneId] ??
      (index.isEven ? const Color(0xFFE9E2DA) : const Color(0xFFE3DCD4));

  /// Darker tone of a district color for the sides of the land.
  static Color side(Color top) =>
      Color.lerp(top, const Color(0xFF8E7FA3), 0.35)!;

  static const ground = Color(0xFFE3EEDF);
  static const forest = Color(0xFFB4D8A6);
  static const park = Color(0xFF9DD49B);
  static const golf = Color(0xFFC2E6A8);
  static const water = Color(0xFF9DD3F3);
  static const airport = Color(0xFFE4E1EE);
  static const border = Color(0xFFFFFFFF);
  static const treeCrown = Color(0xFF6DBB72);
  static const treeTrunk = Color(0xFFA0715A);

  static Color road(CityRoadClass roadClass) => switch (roadClass) {
    CityRoadClass.major => const Color(0xFFFFD27A),
    CityRoadClass.primary => const Color(0xFFFFFFFF),
    CityRoadClass.secondary => const Color(0xFFFFFCF8),
    CityRoadClass.runway => const Color(0xFFB7B2C9),
    CityRoadClass.river => water,
  };
}
