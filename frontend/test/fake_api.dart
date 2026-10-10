import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter/material.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/settings/app_settings.dart';

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
  Duration duration = const Duration(hours: 1),
  int participantCount = 1,
  int? maxParticipants,
  bool isFull = false,
  bool isParticipant = false,
  String status = 'active',
  double? distanceKm = 0,
}) {
  final start = (startsAt ?? DateTime.utc(2099, 1, 1, 17)).toUtc();
  return {
    'id': id,
    'activity': {'id': 'reading', 'name': 'Leer'},
    'title': title,
    'description': description,
    'zone': {'id': 'chapinero', 'name': 'Chapinero'},
    'place': 'Café Libro',
    'startsAt': start.toIso8601String(),
    'durationMinutes': duration.inMinutes,
    'endsAt': start.add(duration).toIso8601String(),
    'isOngoing': false,
    'status': status,
    'participantCount': participantCount,
    'maxParticipants': maxParticipants,
    'isFull': isFull,
    'isParticipant': isParticipant,
    'distanceKm': ?distanceKm,
  };
}

const avatarOptionsJson = {
  'skins': [
    {'id': 'basic', 'name': 'Básico'},
  ],
  'bodyColors': ['coral', 'mint'],
  'skinTones': ['tone1', 'tone2'],
  'accessories': [
    {'id': 'none', 'name': 'Ninguno'},
    {'id': 'cap', 'name': 'Gorra'},
  ],
};

/// The zones of [zonesJson], for screens that receive the catalog.
const chapinero = Zone(id: 'chapinero', name: 'Chapinero');
const usaquen = Zone(id: 'usaquen', name: 'Usaquén');
const testZones = [chapinero, usaquen];

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

/// In-memory [SettingsStorage] for tests.
class MemorySettingsStorage implements SettingsStorage {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

/// Settings fixed to Spanish so tests do not depend on the test locale.
AppSettings spanishSettings([SettingsStorage? storage]) => AppSettings(
  storage: storage ?? MemorySettingsStorage(),
  locale: const Locale('es'),
);

/// Wraps a screen in a MaterialApp with the app localizations.
Widget localized(Widget home, {Locale locale = const Locale('es')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
