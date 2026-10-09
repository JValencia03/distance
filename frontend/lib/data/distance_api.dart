import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:distance/data/models.dart';

/// Base URL of the Go API. Override it with
/// `--dart-define=API_BASE_URL=http://<host>:8080`, e.g. with the LAN IP of
/// the computer running the API when using a physical device.
String defaultApiBaseUrl() {
  const fromEnvironment = String.fromEnvironment('API_BASE_URL');
  if (fromEnvironment.isNotEmpty) return fromEnvironment;
  // The Android emulator reaches the host machine through 10.0.2.2.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://localhost:8080';
}

/// Development-only identity sent as `X-User-Id` until authentication exists.
const devUserId = String.fromEnvironment(
  'DEV_USER_ID',
  defaultValue: 'demo-user',
);

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.fields = const {}});

  /// Builds an exception from the API error format:
  /// `{"error": {"code": ..., "message": ..., "fields": {...}}}`.
  factory ApiException.fromBody(int statusCode, Object? body) {
    final error = body is Map<String, dynamic> ? body['error'] : null;
    if (error is Map<String, dynamic> && error['message'] is String) {
      final fields = error['fields'];
      return ApiException(
        error['message'] as String,
        statusCode: statusCode,
        fields: fields is Map<String, dynamic>
            ? fields.map((k, v) => MapEntry(k, '$v'))
            : const {},
      );
    }
    return ApiException(
      'Error inesperado del servidor ($statusCode).',
      statusCode: statusCode,
    );
  }

  final String message;
  final int? statusCode;

  /// Validation problems keyed by JSON field name.
  final Map<String, String> fields;

  @override
  String toString() => message;
}

class DistanceApi {
  DistanceApi({
    required String baseUrl,
    required this.userId,
    http.Client? client,
  }) : _baseUrl = Uri.parse(baseUrl),
       _client = client ?? http.Client();

  static const _timeout = Duration(seconds: 10);

  final Uri _baseUrl;

  /// Sent as `X-User-Id` when creating plans.
  final String userId;
  final http.Client _client;

  Future<List<Activity>> fetchActivities() async {
    final json = await _send(() => _client.get(_uri('/activities')));
    return _list(json['activities'], Activity.fromJson);
  }

  Future<List<Zone>> fetchZones() async {
    final json = await _send(() => _client.get(_uri('/zones')));
    return _list(json['zones'], Zone.fromJson);
  }

  /// Future plans ordered by availability, distance to [zoneId] and date.
  Future<List<Plan>> fetchPlans({
    required String zoneId,
    String? activityId,
  }) async {
    final query = {'zone': zoneId, 'activity': ?activityId};
    final json = await _send(() => _client.get(_uri('/plans', query)));
    return _list(json['plans'], Plan.fromJson);
  }

  Future<Plan> fetchPlan(String id) async {
    final json = await _send(
      () => _client.get(_uri('/plans/${Uri.encodeComponent(id)}')),
    );
    return Plan.fromJson(json);
  }

  Future<Plan> createPlan(NewPlan plan) async {
    final json = await _send(
      () => _client.post(
        _uri('/plans'),
        headers: {'Content-Type': 'application/json', 'X-User-Id': userId},
        body: jsonEncode(plan.toJson()),
      ),
    );
    return Plan.fromJson(json);
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      _baseUrl.replace(path: path, queryParameters: query);

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('El servidor tardó demasiado en responder.');
    } on http.ClientException {
      throw const ApiException('No se pudo conectar con el servidor.');
    }

    final Object? body;
    try {
      // Decode bytes as UTF-8 explicitly: `response.body` falls back to
      // Latin-1 when the Content-Type has no charset, garbling "café".
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        'Respuesta inesperada del servidor.',
        statusCode: response.statusCode,
      );
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok && body is Map<String, dynamic>) return body;
    throw ApiException.fromBody(response.statusCode, body);
  }

  List<T> _list<T>(
    Object? value,
    T Function(Map<String, dynamic> json) fromJson,
  ) => [
    for (final item in value as List<dynamic>)
      fromJson(item as Map<String, dynamic>),
  ];
}
