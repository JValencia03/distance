import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:distance/app.dart';
import 'package:distance/shared/activity_style.dart';
import 'package:distance/shared/emoji.dart';

import '../fake_api.dart';

/// Pumps frames until the catalog has loaded, without letting animations
/// run to completion.
Future<void> pumpUntilCatalog(WidgetTester tester) async {
  for (var i = 0; i < 10 && find.text('Leer').evaluate().isEmpty; i++) {
    await tester.pump();
  }
}

/// Opacity of the entrance animation wrapping the "Leer" activity card.
double cardOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Leer'),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  testWidgets('activity cards fade in when the catalog arrives', (
    tester,
  ) async {
    await tester.pumpWidget(
      DistanceApp(api: catalogApi(), settings: spanishSettings()),
    );
    await pumpUntilCatalog(tester);
    expect(cardOpacity(tester), lessThan(1));

    await tester.pumpAndSettle();
    expect(cardOpacity(tester), 1);
  });

  testWidgets('reduced motion shows the cards without animating', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      DistanceApp(api: catalogApi(), settings: spanishSettings()),
    );
    await pumpUntilCatalog(tester);
    expect(cardOpacity(tester), 1);
  });

  test('unknown activities fall back to a neutral style', () {
    expect(ActivityStyle.of('knitting').emoji, Emojis.calendar);
  });

  test('every activity of the server catalog has its own emoji asset', () {
    // Ids from backend/internal/plans/catalog.go.
    const ids = [
      'reading',
      'walking',
      'running',
      'coffee',
      'studying',
      'gym',
      'gaming',
      'photography',
      'eating',
      'exploring',
    ];
    final emojis = {for (final id in ids) ActivityStyle.of(id).emoji};
    expect(emojis, hasLength(ids.length));
    expect(emojis, isNot(contains(Emojis.calendar)));
    for (final asset in emojis) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });
}
