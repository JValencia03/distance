import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:distance/shared/aurora_background.dart';
import 'package:distance/shared/clay.dart';
import 'package:distance/shared/illustration.dart';
import 'package:distance/shared/motion.dart';

/// Turns ambient motion on for one test; the test config turns it off.
void enableAmbientMotion() {
  AmbientMotion.enabled = true;
  addTearDown(() => AmbientMotion.enabled = false);
}

/// Lets real asynchronous work (asset loading, shader compilation) finish.
Future<void> settleRealAsync(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump();
}

void main() {
  test('generated Lottie files load without warnings', () async {
    for (final asset in [
      Illustrations.loading,
      Illustrations.empty,
      Illustrations.error,
      Illustrations.success,
    ]) {
      final composition = await LottieComposition.fromBytes(
        File(asset).readAsBytesSync(),
      );
      expect(composition.warnings, isEmpty, reason: asset);
      expect(composition.duration, greaterThan(Duration.zero), reason: asset);
    }
  });

  testWidgets('illustrations loop only with ambient motion', (tester) async {
    Lottie lottie() => tester.widget<Lottie>(find.byType(Lottie));
    const illustration = MaterialApp(
      home: LottieIllustration(Illustrations.loading),
    );

    await tester.pumpWidget(illustration);
    expect(lottie().repeat, isFalse);

    enableAmbientMotion();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(illustration);
    expect(lottie().repeat, isTrue);
  });

  testWidgets('the success burst plays once and goes away', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SuccessBurst()));
    await settleRealAsync(tester);
    expect(find.byType(Lottie), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(Lottie), findsNothing);
  });

  group('aurora background', () {
    Widget app() =>
        const MaterialApp(home: AuroraBackground(child: Text('content')));

    testWidgets('shows the static backdrop until the shader loads', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      expect(find.byType(PastelBackdrop), findsOneWidget);
      expect(find.text('content'), findsOneWidget);

      await settleRealAsync(tester);
      expect(find.byType(PastelBackdrop), findsNothing);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('keeps animating only with ambient motion', (tester) async {
      await tester.pumpWidget(app());
      await settleRealAsync(tester);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);

      enableAmbientMotion();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });
  });
}
