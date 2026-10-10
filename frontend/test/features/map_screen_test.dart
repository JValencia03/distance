import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';
import 'package:distance/features/avatar/avatar_badge.dart';
import 'package:distance/features/map/map_screen.dart';
import 'package:distance/features/map/map_view.dart';
import 'package:distance/features/plans/plan_detail_screen.dart';

import '../fake_api.dart';
import 'map_layout_test.dart' show mapPlanJson, mapZonesJson, participantJson;

const catalog = (
  activities: [
    Activity(id: 'reading', name: 'Leer'),
    Activity(id: 'running', name: 'Correr'),
  ],
  zones: testZones,
);

/// Serves the map with [plans] and the detail of plan-1.
DistanceApi mapApi(
  List<Map<String, Object?>> plans, {
  List<http.Request>? requests,
}) => fakeApi((request) async {
  requests?.add(request);
  return switch (request.url.path) {
    '/map' => jsonResponse({'zones': mapZonesJson, 'plans': plans}),
    '/plans/plan-1' => jsonResponse(planJson()),
    _ => jsonResponse({}, 404),
  };
});

Future<void> showMap(WidgetTester tester, DistanceApi api) async {
  await tester.pumpWidget(
    localized(MapScreen(api: api, catalog: catalog, zone: chapinero)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows each group of participants in the zone they chose', (
    tester,
  ) async {
    await showMap(
      tester,
      mapApi([
        mapPlanJson('plan-1', [
          participantJson(),
          participantJson(zoneId: 'usaquen', isMe: true),
          participantJson(zoneId: 'usaquen', bodyColor: 'coral'),
        ]),
      ]),
    );

    expect(find.byType(ClusterBubble), findsNWidgets(2));
    expect(find.byType(AvatarBadge), findsNWidgets(3));
    expect(find.text('Chapinero'), findsWidgets);
    expect(find.text('Usaquén'), findsWidgets);
    expect(find.text('Tú'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Leer: Leer en el café, 2 personas en Usaquén'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a group shows its plan and opens it', (tester) async {
    await showMap(
      tester,
      mapApi([
        mapPlanJson('plan-1', [
          participantJson(),
          participantJson(zoneId: 'usaquen', isMe: true),
        ]),
      ]),
    );

    await tester.tap(find.byType(ClusterBubble).first);
    await tester.pumpAndSettle();
    expect(find.text('Leer en el café'), findsWidgets);
    expect(find.textContaining('Desde Chapinero, Usaquén'), findsOneWidget);

    await tester.tap(find.text('Ver plan'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanDetailScreen), findsOneWidget);
  });

  testWidgets('filters by activity', (tester) async {
    final requests = <http.Request>[];
    await showMap(tester, mapApi([], requests: requests));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Correr'));
    await tester.pumpAndSettle();

    expect(requests.last.url.queryParameters, {'activity': 'running'});
  });

  testWidgets('explains an empty map', (tester) async {
    await showMap(tester, mapApi([]));

    expect(find.text('Todavía no hay planes en el mapa'), findsOneWidget);
    expect(find.byType(ClusterBubble), findsNothing);
  });

  testWidgets('shows an error with retry', (tester) async {
    await showMap(tester, fakeApi((_) async => jsonResponse({}, 500)));

    expect(find.text('Reintentar'), findsOneWidget);
  });
}
