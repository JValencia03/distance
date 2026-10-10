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
        duration: const Duration(hours: 1, minutes: 30),
        maxParticipants: null,
        creatorZoneId: 'usaquen',
      ),
    );

    expect(sent.method, 'POST');
    expect(sent.headers['X-User-Id'], 'test-user');
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    expect(body['startsAt'], startsAt.toUtc().toIso8601String());
    expect(body['startsAt'], endsWith('Z'));
    expect(body.containsKey('maxParticipants'), isTrue);
    expect(body['maxParticipants'], isNull);
    expect(body['durationMinutes'], 90);
    expect(body['creatorZoneId'], 'usaquen');
  });

  test('parses the end of the plan', () async {
    final api = fakeApi(
      (_) async => jsonResponse(
        planJson(
          startsAt: DateTime.utc(2099, 1, 1, 17),
          duration: const Duration(minutes: 45),
        ),
      ),
    );

    final plan = await api.fetchPlan('plan-1');

    expect(plan.endsAt, DateTime.utc(2099, 1, 1, 17, 45));
    expect(plan.duration, const Duration(minutes: 45));
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
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.connection)
            .having((e) => e.message, 'message', isNull),
      ),
    );

    final broken = fakeApi((_) async => http.Response('<html>', 502));
    await expectLater(
      broken.fetchZones(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.badResponse)
            .having((e) => e.statusCode, 'status', 502),
      ),
    );
  });

  test('every request asks for the current app language', () async {
    final languages = <String?>[];
    final api = fakeApi((request) async {
      languages.add(request.headers['Accept-Language']);
      return switch (request.url.path) {
        '/activities' => jsonResponse(activitiesJson),
        '/plans' => jsonResponse({'plans': []}),
        _ => jsonResponse(planJson()),
      };
    });

    await api.fetchActivities();
    api.languageCode = 'en';
    await api.fetchActivities();
    await api.fetchPlans(zoneId: 'chapinero');
    await api.joinPlan('plan-1', zoneId: 'chapinero');

    expect(languages, ['es', 'en', 'en', 'en']);
  });

  test(
    'joinPlan posts to the participants route as the current user',
    () async {
      late http.Request sent;
      final api = fakeApi((request) async {
        sent = request;
        return jsonResponse(planJson(participantCount: 2, isParticipant: true));
      });

      final plan = await api.joinPlan('plan 1', zoneId: 'usaquen');

      expect(sent.method, 'POST');
      expect(sent.url.path, '/plans/plan%201/participants');
      expect(sent.headers['X-User-Id'], 'test-user');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {'zoneId': 'usaquen'});
      expect(plan.participantCount, 2);
      expect(plan.isParticipant, isTrue);
    },
  );

  test('plan reads identify the user but catalogs do not', () async {
    final headers = <String, Map<String, String>>{};
    final api = fakeApi((request) async {
      headers[request.url.path] = request.headers;
      return switch (request.url.path) {
        '/zones' => jsonResponse(zonesJson),
        '/plans' => jsonResponse({'plans': []}),
        _ => jsonResponse(planJson()),
      };
    });

    await api.fetchZones();
    await api.fetchPlans(zoneId: 'chapinero');
    await api.fetchPlan('plan-1');

    expect(headers['/zones']!.containsKey('X-User-Id'), isFalse);
    expect(headers['/plans']!['X-User-Id'], 'test-user');
    expect(headers['/plans/plan-1']!['X-User-Id'], 'test-user');
  });

  test('exposes the API error code', () async {
    final api = fakeApi(
      (_) async => jsonResponse({
        'error': {'code': 'already_joined', 'message': 'Ya participas.'},
      }, 409),
    );

    await expectLater(
      api.joinPlan('plan-1', zoneId: 'chapinero'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'already_joined')
            .having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
  });

  group('Plan.joinAvailability', () {
    final now = DateTime.utc(2099, 1, 1, 12);
    JoinAvailability availability(Map<String, Object?> json) =>
        Plan.fromJson(json).joinAvailability(now);

    test('follows the API order: cancelled, ended, joined, full', () {
      expect(availability(planJson()), JoinAvailability.available);
      expect(
        availability(planJson(isFull: true, isParticipant: true)),
        JoinAvailability.joined,
      );
      expect(availability(planJson(isFull: true)), JoinAvailability.full);
      expect(
        availability(
          planJson(
            startsAt: now.subtract(const Duration(hours: 1)),
            isParticipant: true,
          ),
        ),
        JoinAvailability.ended,
      );
      expect(
        availability(
          planJson(status: 'cancelled', startsAt: DateTime.utc(2000)),
        ),
        JoinAvailability.cancelled,
      );
    });

    test('ongoing plans can still be joined', () {
      final ongoing = Plan.fromJson(
        planJson(startsAt: now.subtract(const Duration(minutes: 59))),
      );
      expect(ongoing.joinAvailability(now), JoinAvailability.available);
      expect(ongoing.isOngoingAt(now), isTrue);

      final startingNow = Plan.fromJson(planJson(startsAt: now));
      expect(startingNow.isOngoingAt(now), isTrue);

      final upcoming = Plan.fromJson(planJson());
      expect(upcoming.isOngoingAt(now), isFalse);
    });
  });

  group('avatars', () {
    const avatar = Avatar(
      skin: 'basic',
      bodyColor: 'mint',
      skinTone: 'tone3',
      accessory: 'cap',
    );

    test('reads the options in the app language', () async {
      late http.Request sent;
      final api = fakeApi((request) async {
        sent = request;
        return jsonResponse(avatarOptionsJson);
      })..languageCode = 'en';

      final options = await api.fetchAvatarOptions();

      expect(sent.url.path, '/avatar-options');
      expect(sent.headers['Accept-Language'], 'en');
      expect(options.skins.single.name, 'Básico');
      expect(options.bodyColors, ['coral', 'mint']);
      expect(options.accessories.map((a) => a.id), ['none', 'cap']);
    });

    test('reads and saves the current user avatar', () async {
      final requests = <http.Request>[];
      final api = fakeApi((request) async {
        requests.add(request);
        return jsonResponse({
          'avatar': avatar.toJson(),
          'isDefault': request.method == 'GET',
        });
      });

      final current = await api.fetchMyAvatar();
      final saved = await api.saveMyAvatar(avatar);

      expect(current.avatar, avatar);
      expect(current.isDefault, isTrue);
      expect(saved.isDefault, isFalse);
      final put = requests.last;
      expect(put.method, 'PUT');
      expect(put.url.path, '/me/avatar');
      expect(put.headers['X-User-Id'], 'test-user');
      expect(jsonDecode(put.body), avatar.toJson());
    });
  });

  test(
    'fetchMap parses zones and participants, filtering by activity',
    () async {
      final urls = <Uri>[];
      final api = fakeApi((request) async {
        urls.add(request.url);
        return jsonResponse({
          'zones': [
            {'id': 'chapinero', 'name': 'Chapinero', 'x': 0.6, 'y': 0.4},
          ],
          'plans': [
            {
              ...planJson(),
              'participants': [
                {
                  'avatar': {
                    'skin': 'basic',
                    'bodyColor': 'sky',
                    'skinTone': 'tone1',
                    'accessory': 'none',
                  },
                  'zoneId': 'chapinero',
                  'isMe': true,
                },
              ],
            },
          ],
        });
      });

      final map = await api.fetchMap();
      await api.fetchMap(activityId: 'reading');

      expect(urls.first.toString(), 'http://api.test/map');
      expect(urls.last.queryParameters, {'activity': 'reading'});
      expect(map.zones.single.x, 0.6);
      expect(map.plans.single.plan.id, 'plan-1');
      final me = map.plans.single.participants.single;
      expect(me.isMe, isTrue);
      expect(me.avatar.bodyColor, 'sky');
    },
  );
}
