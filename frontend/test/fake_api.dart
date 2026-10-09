import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:distance/data/distance_api.dart';

const activitiesJson = {
  'activities': [
    {'id': 'reading', 'name': 'Leer'},
    {'id': 'running', 'name': 'Correr'},
  ],
};

const zonesJson = {
  'zones': [
    {'id': 'chapinero', 'name': 'Chapinero'},
    {'id': 'usaquen', 'name': 'Usaquén'},
  ],
};

Map<String, Object?> planJson({
  String id = 'plan-1',
  String title = 'Leer en el café',
  String? description,
  DateTime? startsAt,
  int participantCount = 1,
  int? maxParticipants,
  bool isFull = false,
  double? distanceKm = 0,
}) => {
  'id': id,
  'activity': {'id': 'reading', 'name': 'Leer'},
  'title': title,
  'description': description,
  'zone': {'id': 'chapinero', 'name': 'Chapinero'},
  'place': 'Café Libro',
  'startsAt': (startsAt ?? DateTime.utc(2099, 1, 1, 17))
      .toUtc()
      .toIso8601String(),
  'participantCount': participantCount,
  'maxParticipants': maxParticipants,
  'isFull': isFull,
  'distanceKm': ?distanceKm,
};

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// Builds an API backed by [handler], which receives every request.
DistanceApi fakeApi(Future<http.Response> Function(http.Request) handler) =>
    DistanceApi(
      baseUrl: 'http://api.test',
      userId: 'test-user',
      client: MockClient(handler),
    );

/// Serves the catalogs and answers `GET /plans` with [plans].
DistanceApi catalogApi({List<Map<String, Object?>> plans = const []}) =>
    fakeApi((request) async {
      return switch (request.url.path) {
        '/activities' => jsonResponse(activitiesJson),
        '/zones' => jsonResponse(zonesJson),
        '/plans' => jsonResponse({'plans': plans}),
        _ => jsonResponse({
          'error': {'code': 'not_found', 'message': 'No existe.'},
        }, 404),
      };
    });
