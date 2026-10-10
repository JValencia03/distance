import 'package:flutter/material.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/features/activities/activities_screen.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/settings/app_settings.dart';
import 'package:distance/shared/theme.dart';

class DistanceApp extends StatelessWidget {
  const DistanceApp({super.key, required this.api, required this.settings});

  final DistanceApi api;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: settings.themeMode,
        // Null follows the device language, falling back to Spanish.
        locale: settings.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          // Runs below Localizations whenever the resolved locale changes,
          // so API requests always ask for the language on screen.
          api.languageCode = Localizations.localeOf(context).languageCode;
          return child!;
        },
        home: ActivitiesScreen(api: api, settings: settings),
      ),
    );
  }
}
