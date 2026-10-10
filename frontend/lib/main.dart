import 'package:flutter/material.dart';

import 'package:distance/app.dart';
import 'package:distance/data/distance_api.dart';
import 'package:distance/settings/app_settings.dart';

Future<void> main() async {
  // Plugins (shared_preferences) need the binding before runApp.
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load(SharedPreferencesStorage());
  final api = DistanceApi(baseUrl: defaultApiBaseUrl(), userId: devUserId);
  runApp(DistanceApp(api: api, settings: settings));
}
