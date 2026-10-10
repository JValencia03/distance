import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where [AppSettings] keeps its values. Separated from shared_preferences so
/// tests can use an in-memory implementation.
abstract interface class SettingsStorage {
  Future<String?> read(String key);

  /// Removes the key when [value] is null.
  Future<void> write(String key, String? value);
}

class SharedPreferencesStorage implements SettingsStorage {
  final _prefs = SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);
}

/// User preferences for theme and language. `null` locale and
/// [ThemeMode.system] follow the device settings.
class AppSettings extends ChangeNotifier {
  AppSettings({
    required this._storage,
    this._themeMode = ThemeMode.system,
    this._locale,
  });

  static const supportedLanguages = ['es', 'en'];
  static const _themeKey = 'theme_mode';
  static const _languageKey = 'language';

  /// Loads saved preferences, ignoring values this version does not know.
  static Future<AppSettings> load(SettingsStorage storage) async {
    final theme = await storage.read(_themeKey);
    final language = await storage.read(_languageKey);
    return AppSettings(
      storage: storage,
      themeMode: ThemeMode.values.asNameMap()[theme] ?? ThemeMode.system,
      locale: supportedLanguages.contains(language) ? Locale(language!) : null,
    );
  }

  final SettingsStorage _storage;
  ThemeMode _themeMode;
  Locale? _locale;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _storage.write(_themeKey, mode.name);
  }

  /// Sets the app language; null follows the device.
  Future<void> setLocale(Locale? locale) async {
    if (locale == _locale) return;
    _locale = locale;
    notifyListeners();
    await _storage.write(_languageKey, locale?.languageCode);
  }
}
