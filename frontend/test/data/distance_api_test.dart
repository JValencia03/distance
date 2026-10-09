import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';

import '../fake_api.dart';

void main() {
  test('fetchPlans sends the filters and parses nullable fields', () async {
    late Uri requested;
    final api = fakeApi((request) async {
      requested = request.url;
      return jsonResponse({
        'plans': [
          planJson(maxParticipants: 4, distanceKm: 1.5),
          planJson(id: 'plan-2', description: 'Traer libro'),
        ],
      });
    });

    final plans = await api.fetchPlans(
      zoneId: 'chapinero',
      activityId: 'reading',
    );

    expect(requested.path, '/plans');
    expect(requested.queryParameters, {
      'zone': 'chapinero',
      'activity': 'reading',
    });
    expect(plans, hasLength(2));
    expect(plans[0].maxParticipants, 4);
    expect(plans[0].distanceKm, 1.5);
    expect(plans[0].description, isNull);
    expect(plans[1].maxParticipants, isNull);
    expect(plans[1].description, 'Traer libro');
    expect(plans[0].startsAt.isUtc, isTrue);
  });

  test('fetchPlans omits the activity filter when not given', () async {
    late Uri requested;
    final api = fakeApi((request) async {
      requested = request.url;
      return jsonResponse({'plans': []});
    });

    await api.fetchPlans(zoneId: 'chapinero');

    expect(requested.queryParameters, {'zone': 'chapinero'});
  });

  test('decodes UTF-8 bodies without a charset', () async {
    final api = fakeApi(
      (_) async => http.Response.bytes(
        utf8.encode('{"zones":[{"id":"usaquen","name":"Usaquén"}]}'),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );

    final zones = await api.fetchZones();

    expect(zones.single.name, 'Usaquén');
  });

  test('createPlan sends the user header and a UTC start time', () async {
    late http.Request sent;
    final api = fakeApi((request) async {
      sent = request;
      return jsonResponse(planJson(), 201);
    });
    final startsAt = DateTime(2099, 1, 1, 17, 30);

    await api.createPlan(
      NewPlan(
        activityId: 'reading',
        title: 'Leer',
        description: null,
        zoneId: 'chapinero',
        place: 'Café',
        startsAt: startsAt,
        maxParticipants: null,
      ),
    );

    expect(sent.method, 'POST');
    expect(sent.headers['X-User-Id'], 'test-user');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['startsAt'], startsAt.toUtc().toIso8601String());
    expect(body['startsAt'], endsWith('Z'));
    expect(body.containsKey('maxParticipants'), isTrue);
    expect(body['maxParticipants'], isNull);
  });

  test('turns API errors into ApiException with field problems', () async {
    final api = fakeApi(
      (_) async => jsonResponse({
        'error': {
          'code': 'validation_failed',
          'message': 'Revisa los datos del plan.',
          'fields': {'startsAt': 'La fecha y hora deben ser futuras.'},
        },
      }, 422),
    );

    await expectLater(
      api.fetchPlan('x'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 422)
            .having((e) => e.message, 'message', 'Revisa los datos del plan.')
            .having((e) => e.fields, 'fields', {
              'startsAt': 'La fecha y hora deben ser futuras.',
            }),
      ),
    );
  });

  test('reports connection failures and non-JSON responses', () async {
    final offline = fakeApi((_) async => throw http.ClientException('down'));
    await expectLater(
      offline.fetchZones(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'No se pudo conectar con el servidor.',
        ),
      ),
    );

    final broken = fakeApi((_) async => http.Response('<html>', 502));
    await expectLater(
      broken.fetchZones(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)),
    );
  });
}
