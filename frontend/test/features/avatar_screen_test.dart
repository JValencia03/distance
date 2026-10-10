import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:distance/data/distance_api.dart';
import 'package:distance/features/avatar/avatar_badge.dart';
import 'package:distance/features/avatar/avatar_screen.dart';

import '../fake_api.dart';

const savedAvatar = {
  'skin': 'basic',
  'bodyColor': 'coral',
  'skinTone': 'tone1',
  'accessory': 'none',
};

/// Serves the avatar options and the user's avatar; PUT echoes the body.
DistanceApi avatarApi({
  bool isDefault = false,
  List<http.Request>? requests,
  int saveStatus = 200,
}) => fakeApi((request) async {
  requests?.add(request);
  return switch ((request.method, request.url.path)) {
    ('GET', '/avatar-options') => jsonResponse(avatarOptionsJson),
    ('GET', '/me/avatar') => jsonResponse({
      'avatar': savedAvatar,
      'isDefault': isDefault,
    }),
    ('PUT', '/me/avatar') when saveStatus == 200 => jsonResponse({
      'avatar': jsonDecode(request.body),
      'isDefault': false,
    }),
    _ => jsonResponse({
      'error': {'code': 'internal_error', 'message': 'Algo falló.'},
    }, saveStatus),
  };
});

Finder get saveButton => find.widgetWithText(FilledButton, 'Guardar personaje');

void main() {
  testWidgets('customizes and saves the character', (tester) async {
    final requests = <http.Request>[];
    await tester.pumpWidget(
      localized(AvatarScreen(api: avatarApi(requests: requests))),
    );
    await tester.pumpAndSettle();

    // Without 3D the preview falls back to the flat badge.
    expect(find.byType(AvatarBadge), findsOneWidget);
    expect(
      find.text('La vista 3D no está disponible en este dispositivo.'),
      findsOne,
    );
    expect(find.text('Así te verán los demás en el mapa de planes.'), findsOne);
    // Nothing changed yet.
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.tap(find.bySemanticsLabel('Menta'));
    await tester.scrollUntilVisible(find.text('Gorra'), 200);
    await tester.tap(find.text('Gorra'));
    await tester.pump();
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final put = requests.singleWhere((r) => r.method == 'PUT');
    expect(jsonDecode(put.body), {
      'skin': 'basic',
      'bodyColor': 'mint',
      'skinTone': 'tone1',
      'accessory': 'cap',
    });
    expect(find.text('Personaje guardado'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
  });

  testWidgets('a default character can be kept as is', (tester) async {
    await tester.pumpWidget(
      localized(AvatarScreen(api: avatarApi(isDefault: true))),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Este es tu personaje por defecto. Personalízalo a tu gusto.'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
  });

  testWidgets('a failed save keeps the changes to retry', (tester) async {
    await tester.pumpWidget(
      localized(AvatarScreen(api: avatarApi(saveStatus: 500))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Menta'));
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Algo falló.'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
  });

  testWidgets('shows an error with retry when loading fails', (tester) async {
    await tester.pumpWidget(
      localized(AvatarScreen(api: fakeApi((_) async => jsonResponse({}, 500)))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reintentar'), findsOneWidget);
    expect(saveButton, findsNothing);
  });
}
