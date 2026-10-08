import 'package:flutter_test/flutter_test.dart';

import 'package:distance/app.dart';

void main() {
  testWidgets('DistanceApp shows the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DistanceApp());

    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Encuentra un plan cerca de ti'), findsOneWidget);
  });
}
