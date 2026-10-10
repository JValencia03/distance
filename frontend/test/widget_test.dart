import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:distance/app.dart';
import 'package:distance/data/models.dart';
import 'package:distance/features/plans/create_plan_screen.dart';

import 'fake_api.dart';

void main() {
  testWidgets('shows the activity catalog', (tester) async {
    await tester.pumpWidget(
      DistanceApp(api: catalogApi(), settings: spanishSettings()),
    );
    await tester.pumpAndSettle();

    expect(find.text('¿Qué quieres hacer?'), findsOneWidget);
    expect(find.text('Leer'), findsOneWidget);
    expect(find.text('Correr'), findsOneWidget);
    expect(find.text('Elige tu zona'), findsOneWidget);
  });

  testWidgets('shows an error with retry when the catalog fails', (
    tester,
  ) async {
    var fail = true;
    final api = fakeApi((request) async {
      if (fail) throw http.ClientException('down');
      return request.url.path == '/zones'
          ? jsonResponse(zonesJson)
          : jsonResponse(activitiesJson);
    });

    await tester.pumpWidget(DistanceApp(api: api, settings: spanishSettings()));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Leer'), findsOneWidget);
  });

  testWidgets('retrying the catalog shows the loading state', (tester) async {
    var fail = true;
    final gate = Completer<void>();
    final api = fakeApi((request) async {
      if (fail) throw http.ClientException('down');
      await gate.future;
      return request.url.path == '/zones'
          ? jsonResponse(zonesJson)
          : jsonResponse(activitiesJson);
    });

    await tester.pumpWidget(DistanceApp(api: api, settings: spanishSettings()));
    await tester.pumpAndSettle();

    fail = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    // The previous error gives way to the loading state at once.
    expect(find.text('Cargando…'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Leer'), findsOneWidget);
  });

  testWidgets('asks for a zone, then shows the empty state', (tester) async {
    await tester.pumpWidget(
      DistanceApp(api: catalogApi(), settings: spanishSettings()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Leer'));
    await tester.pumpAndSettle();
    expect(find.text('¿Dónde quieres buscar planes?'), findsOneWidget);

    await tester.tap(find.text('Chapinero'));
    await tester.pumpAndSettle();

    expect(
      find.text('No hay planes de leer cerca de Chapinero'),
      findsOneWidget,
    );
    expect(find.text('Crear plan'), findsNWidgets(2));
  });

  testWidgets('lists plans with availability and opens details', (
    tester,
  ) async {
    final open = planJson(title: 'Club de lectura', maxParticipants: 5);
    final full = planJson(
      id: 'plan-2',
      title: 'Lectura completa',
      participantCount: 2,
      maxParticipants: 2,
      isFull: true,
      distanceKm: 4.2,
    );
    final api = fakeApi((request) async {
      return switch (request.url.path) {
        '/activities' => jsonResponse(activitiesJson),
        '/zones' => jsonResponse(zonesJson),
        '/plans' => jsonResponse({
          'plans': [open, full],
        }),
        '/plans/plan-1' => jsonResponse({
          ...open,
          'description': 'Trae tu libro favorito.',
        }),
        _ => jsonResponse({}, 404),
      };
    });

    await tester.pumpWidget(DistanceApp(api: api, settings: spanishSettings()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chapinero'));
    await tester.pumpAndSettle();

    expect(find.text('Club de lectura'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('Completo'), findsOneWidget);
    expect(find.text('1/5 participantes'), findsOneWidget);
    // The distance uses a no-break space between number and unit.
    final nbsp = String.fromCharCode(0xA0);
    expect(find.text('Café Libro, Chapinero · A 4,2${nbsp}km'), findsOneWidget);

    await tester.tap(find.text('Club de lectura'));
    await tester.pumpAndSettle();
    expect(find.text('Trae tu libro favorito.'), findsOneWidget);
    expect(find.text('Punto de encuentro'), findsOneWidget);
  });

  testWidgets('create form validates required fields before sending', (
    tester,
  ) async {
    var posted = false;
    final api = fakeApi((request) async {
      posted = true;
      return jsonResponse({}, 500);
    });
    const catalog = (
      activities: [Activity(id: 'reading', name: 'Leer')],
      zones: [Zone(id: 'chapinero', name: 'Chapinero')],
    );

    await tester.pumpWidget(
      localized(CreatePlanScreen(api: api, catalog: catalog)),
    );
    await tester.ensureVisible(find.text('Publicar plan'));
    await tester.tap(find.text('Publicar plan'));
    await tester.pumpAndSettle();

    expect(find.text('Elige una actividad.'), findsOneWidget);
    expect(find.text('El título es obligatorio.'), findsOneWidget);
    expect(find.text('Elige una zona.'), findsOneWidget);
    expect(find.text('El lugar de encuentro es obligatorio.'), findsOneWidget);
    expect(find.text('Elige la fecha y la hora.'), findsOneWidget);
    expect(posted, isFalse);
  });

  testWidgets('"Tu zona" follows the plan zone until chosen', (tester) async {
    const catalog = (
      activities: [Activity(id: 'reading', name: 'Leer')],
      zones: [
        Zone(id: 'chapinero', name: 'Chapinero'),
        Zone(id: 'usaquen', name: 'Usaquén'),
      ],
    );
    await tester.pumpWidget(
      localized(
        CreatePlanScreen(
          api: catalogApi(),
          catalog: catalog,
          initialZone: catalog.zones.first,
        ),
      ),
    );

    Future<void> choose(String field, String zone) async {
      final dropdown = find.ancestor(
        of: find.text(field),
        matching: find.byType(DropdownButtonFormField<Zone>),
      );
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(zone).last);
      await tester.pumpAndSettle();
    }

    Finder zoneField(String label, String value) => find.ancestor(
      of: find.text(value),
      matching: find.ancestor(
        of: find.text(label),
        matching: find.byType(DropdownButtonFormField<Zone>),
      ),
    );

    expect(find.text('1 h'), findsOneWidget);
    expect(
      find.text('Otras personas verán esta zona en el mapa del plan.'),
      findsOne,
    );
    expect(zoneField('Tu zona', 'Chapinero'), findsOneWidget);

    await choose('Zona', 'Usaquén');
    expect(zoneField('Tu zona', 'Usaquén'), findsOneWidget);

    await choose('Tu zona', 'Chapinero');
    await choose('Zona', 'Chapinero');
    await choose('Zona', 'Usaquén');
    expect(zoneField('Tu zona', 'Chapinero'), findsOneWidget);
  });
}
