import 'package:flutter/material.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/features/avatar/avatar_screen.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/settings/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings, required this.api});

  final AppSettings settings;
  final DistanceApi api;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.face_retouching_natural_rounded),
                title: Text(l10n.settingsCharacter),
                subtitle: Text(l10n.settingsCharacterSubtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AvatarScreen(api: api),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(l10n.settingsTheme, style: textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_outlined),
                  label: Text(l10n.themeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined),
                  label: Text(l10n.themeLight),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined),
                  label: Text(l10n.themeDark),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) =>
                  settings.setThemeMode(selection.single),
            ),
            const SizedBox(height: 24),
            Text(l10n.settingsLanguage, style: textTheme.titleSmall),
            const SizedBox(height: 8),
            // Language names are written in their own language so they are
            // recognizable whatever the current language is.
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: '', label: Text(l10n.languageSystem)),
                const ButtonSegment(value: 'es', label: Text('Español')),
                const ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {settings.locale?.languageCode ?? ''},
              onSelectionChanged: (selection) {
                final code = selection.single;
                settings.setLocale(code.isEmpty ? null : Locale(code));
              },
            ),
          ],
        ),
      ),
    );
  }
}
