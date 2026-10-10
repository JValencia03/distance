import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';
import 'package:distance/features/plans/plan_detail_screen.dart';
import 'package:distance/shared/illustration.dart';
import 'package:distance/shared/motion.dart';

import '../fake_api.dart';

/// Fake API for the detail screen of 'plan-1': GET returns [current], and
/// POST /participants is answered by [onJoin].
DistanceApi detailApi({
  required Map<String, Object?> Function() current,
  Future<http.Response> Function()? onJoin,
  List<http.Request>? requests,
}) => fakeApi((request) async {
  requests?.add(request);
  if (request.method == 'POST' &&
      request.url.path == '/plans/plan-1/participants') {
    return onJoin!();
  }
  if (request.method == 'GET' && request.url.path == '/plans/plan-1') {
    return jsonResponse(current());
  }
  return jsonResponse({}, 404);
});

Future<void> showDetail(WidgetTester tester, DistanceApi api) async {
  await tester.pumpWidget(
    localized(
      PlanDetailScreen(
        api: api,
        planId: 'plan-1',
        zones: testZones,
        viewerZone: chapinero,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get joinButton => find.widgetWithText(FilledButton, 'Unirme');

/// Taps "Unirme" and confirms the zone sheet, picking [zone] if given. Pumps
/// a fixed time instead of settling, since a pending join shows a spinner.
Future<void> joinFrom(WidgetTester tester, {String? zone}) async {
  await tester.tap(joinButton);
  await tester.pumpAndSettle();
  if (zone != null) {
    await tester.tap(find.text(zone));
    await tester.pump();
  }
  await tester.tap(find.textContaining('Unirme desde'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

String? sentZone(List<http.Request> requests) {
  final join = requests.lastWhere((r) => r.method == 'POST');
  return (jsonDecode(join.body) as Map<String, dynamic>)['zoneId'] as String?;
}

void main() {
  testWidgets('joins a plan, showing progress and blocking repeated taps', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final requests = <http.Request>[];
    final api = detailApi(
      current: () => planJson(maxParticipants: 4),
      onJoin: () => response.future,
      requests: requests,
    );
    await showDetail(tester, api);
    expect(find.text('1/4 participantes'), findsOneWidget);
    expect(find.byType(ConfettiBurst), findsNothing);

    await joinFrom(tester);
    // Second tap while the first request is in flight.
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    expect(requests.last.headers['X-User-Id'], 'test-user');
    // The zone the user is searching from is preselected.
    expect(sentZone(requests), 'chapinero');

    response.complete(
      jsonResponse(
        planJson(participantCount: 2, maxParticipants: 4, isParticipant: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2/4 participantes'), findsOneWidget);
    expect(find.text('Ya participas en este plan'), findsOneWidget);
    expect(find.text('¡Listo! Ya participas en este plan.'), findsOneWidget);
    expect(joinButton, findsNothing);
    expect(find.byType(ConfettiBurst), findsOneWidget);
    expect(find.byType(SuccessBurst), findsOneWidget);
  });

  testWidgets('joins from the zone the user chooses', (tester) async {
    final requests = <http.Request>[];
    final api = detailApi(
      current: () => planJson(),
      onJoin: () async => jsonResponse(planJson(isParticipant: true)),
      requests: requests,
    );
    await showDetail(tester, api);

    await tester.tap(joinButton);
    await tester.pumpAndSettle();
    expect(find.text('¿Desde qué zona te unes?'), findsOneWidget);
    expect(find.textContaining('Otras personas verán esta zona'), findsOne);
    expect(find.text('Unirme desde Chapinero'), findsOneWidget);

    await tester.tap(find.text('Usaquén'));
    await tester.pump();
    expect(find.text('Unirme desde Usaquén'), findsOneWidget);
    await tester.tap(find.text('Unirme desde Usaquén'));
    await tester.pumpAndSettle();

    expect(sentZone(requests), 'usaquen');
    expect(find.text('Ya participas en este plan'), findsOneWidget);
  });

  testWidgets('dismissing the zone sheet does not join', (tester) async {
    final requests = <http.Request>[];
    final api = detailApi(current: () => planJson(), requests: requests);
    await showDetail(tester, api);

    await tester.tap(joinButton);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // The barrier above the sheet.
    await tester.pumpAndSettle();

    expect(requests.where((r) => r.method == 'POST'), isEmpty);
    expect(joinButton, findsOneWidget);
  });

  testWidgets('an ongoing plan can be joined and says so', (tester) async {
    final startedAgo = DateTime.now().toUtc().subtract(
      const Duration(minutes: 10),
    );
    await showDetail(
      tester,
      detailApi(current: () => planJson(startsAt: startedAgo)),
    );

    expect(find.text('En curso'), findsOneWidget);
    expect(find.text('1 h'), findsOneWidget);
    expect(joinButton, findsOneWidget);
  });

  testWidgets('shows that the user already participates', (tester) async {
    await showDetail(
      tester,
      detailApi(current: () => planJson(isParticipant: true)),
    );

    expect(find.text('Ya participas en este plan'), findsOneWidget);
    expect(find.text('Participas'), findsOneWidget);
    expect(joinButton, findsNothing);
  });

  testWidgets('explains why a plan cannot be joined', (tester) async {
    final cases = {
      planJson(participantCount: 2, maxParticipants: 2, isFull: true):
          'No quedan plazas disponibles',
      planJson(status: 'cancelled'): 'Este plan fue cancelado',
      planJson(startsAt: DateTime.utc(2000)): 'Este plan ya terminó',
    };
    for (final MapEntry(key: plan, value: notice) in cases.entries) {
      // Unmount first so the next case starts with a fresh State.
      await tester.pumpWidget(const SizedBox());
      await showDetail(tester, detailApi(current: () => plan));
      expect(find.text(notice), findsOneWidget);
      expect(joinButton, findsNothing);
    }
  });

  testWidgets('a conflict shows the API message and refreshes the plan', (
    tester,
  ) async {
    var plan = planJson(participantCount: 1, maxParticipants: 2);
    final api = detailApi(
      current: () => plan,
      onJoin: () async {
        // Someone else took the last spot meanwhile.
        plan = planJson(participantCount: 2, maxParticipants: 2, isFull: true);
        return jsonResponse({
          'error': {
            'code': 'plan_full',
            'message': 'El plan ya no tiene plazas disponibles.',
          },
        }, 409);
      },
    );
    await showDetail(tester, api);

    await joinFrom(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('El plan ya no tiene plazas disponibles.'),
      findsOneWidget,
    );
    expect(find.text('No quedan plazas disponibles'), findsOneWidget);
    expect(find.text('2/2 participantes'), findsOneWidget);
  });

  testWidgets('a network failure keeps the button available to retry', (
    tester,
  ) async {
    final api = detailApi(
      current: () => planJson(),
      onJoin: () async => throw http.ClientException('down'),
    );
    await showDetail(tester, api);

    await joinFrom(tester);
    await tester.pumpAndSettle();

    expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
    expect(tester.widget<FilledButton>(joinButton).onPressed, isNotNull);
  });

  group('with a preview from the list', () {
    final preview = Plan.fromJson(planJson(title: 'Club de lectura'));

    Future<void> showPreview(WidgetTester tester, DistanceApi api) =>
        tester.pumpWidget(
          localized(
            PlanDetailScreen(
              api: api,
              planId: 'plan-1',
              zones: testZones,
              viewerZone: chapinero,
              preview: preview,
            ),
          ),
        );

    testWidgets('shows it at once and enables joining once loaded', (
      tester,
    ) async {
      final response = Completer<http.Response>();
      await showPreview(tester, fakeApi((_) => response.future));
      await tester.pump();

      expect(find.text('Club de lectura'), findsOneWidget);
      // Joining waits for the latest version of the plan.
      expect(joinButton, findsNothing);

      response.complete(
        jsonResponse(planJson(title: 'Club de lectura', maxParticipants: 6)),
      );
      await tester.pumpAndSettle();
      expect(joinButton, findsOneWidget);
      expect(find.text('1/6 participantes'), findsOneWidget);
    });

    testWidgets('gives way to the error when loading fails', (tester) async {
      await showPreview(tester, fakeApi((_) async => jsonResponse({}, 500)));
      await tester.pumpAndSettle();

      expect(find.text('Club de lectura'), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
