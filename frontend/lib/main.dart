import 'package:flutter/material.dart';

import 'package:distance/app.dart';
import 'package:distance/data/distance_api.dart';

void main() {
  final api = DistanceApi(baseUrl: defaultApiBaseUrl(), userId: devUserId);
  runApp(DistanceApp(api: api));
}
