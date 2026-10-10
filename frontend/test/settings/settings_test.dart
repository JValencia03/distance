import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:distance/app.dart';
import 'package:distance/data/distance_api.dart';
import 'package:distance/settings/app_settings.dart';

import '../fake_api.dart';

/// Catalog API that answers in the language of the request.
DistanceApi bilingualApi(List<String?> languages) => fakeApi((request) async {
  final language = request.headers['Accept-Language'];
  languages.add(language);
  return switch (request.url.path) {
    '/activities' => jsonResponse({
      'activities': [
        {'id': 'reading', 'name': language == 'en' ? 'Reading' : 'Leer'},
      ],
    }),
    _ => jsonResponse(zonesJson),
  };
});

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

void main() {
  group('AppSettings', () {
    test('loads saved values and ignores unknown ones', () async {
      final storage = MemorySettingsStorage()
        ..values.addAll({'theme_mode': 'dark', 'language': 'en'});
      final settings = await AppSettings.load(storage);
      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.locale, const Locale('en'));

      storage.values.addAll({'theme_mode': 'sepia', 'language': 'fr'});
      final fallback = await AppSettings.load(storage);
      expect(fallback.themeMode, ThemeMode.system);
      expect(fallback.locale, isNull);
    });

    test('saves changes and notifies listeners', () async {
      final storage = MemorySettingsStorage();
      final settings = AppSettings(storage: storage);
      var notifications = 0;
      settings.addListener(() => notifications++);

      await settings.setThemeMode(ThemeMode.light);
      await settings.setLocale(const Locale('en'));
      await settings.setLocale(const Locale('en'));
      expect(storage.values, {'theme_mode': 'light', 'language': 'en'});
      expect(notifications, 2);

      await settings.setLocale(null);
      expect(storage.values.containsKey('language'), isFalse);
    });
  });

  testWidgets('switching to dark mode applies and saves it', (tester) async {
    final storage = MemorySettingsStorage();
    await tester.pumpWidget(
      DistanceApp(api: catalogApi(), settings: spanishSettings(storage)),
    );
    await tester.pumpAndSettle();

    await openSettings(tester);
    await tester.tap(find.text('Oscuro'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Ajustes').first);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(storage.values['theme_mode'], 'dark');
  });

  testWidgets('switching language translates the app and the catalog', (
    tester,
  ) async {
    final languages = <String?>[];
    final storage = MemorySettingsStorage();
    await tester.pumpWidget(
      DistanceApp(
        api: bilingualApi(languages),
        settings: spanishSettings(storage),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Leer'), findsOneWidget);

    await openSettings(tester);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(storage.values['language'], 'en');

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('What do you want to do?'), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);
    expect(languages.last, 'en');
  });
}
