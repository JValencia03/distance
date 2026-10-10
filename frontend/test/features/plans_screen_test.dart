import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:distance/data/models.dart';
import 'package:distance/features/plans/plans_screen.dart';

import '../fake_api.dart';

/// Opacity of the entrance animation of the card titled [title].
double cardOpacity(WidgetTester tester, String title) => tester
    .widget<FadeTransition>(
      find
          .ancestor(of: find.text(title), matching: find.byType(FadeTransition))
          .first,
    )
    .opacity
    .value;

void main() {
  testWidgets('a reload that inserts a plan does not replay the others', (
    tester,
  ) async {
    var plans = [planJson(id: 'a', title: 'Plan A')];
    final api = fakeApi((_) async => jsonResponse({'plans': plans}));
    const reading = Activity(id: 'reading', name: 'Leer');
    await tester.pumpWidget(
      localized(
        PlansScreen(
          api: api,
          catalog: (activities: const [reading], zones: const []),
          zone: const Zone(id: 'chapinero', name: 'Chapinero'),
          initialActivity: reading,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A new plan arrives first, pushing "Plan A" down one position.
    plans = [planJson(id: 'b', title: 'Plan B'), ...plans];
    await tester.tap(find.text('Todas'));
    await tester.pump();
    await tester.pump();

    expect(cardOpacity(tester, 'Plan B'), lessThan(1));
    expect(cardOpacity(tester, 'Plan A'), 1);
  });
}
