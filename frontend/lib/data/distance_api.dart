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

enum ApiErrorKind {
  /// The server could not be reached.
  connection,

  /// The server did not answer in time.
  timeout,

  /// The server answered something the app cannot read.
  badResponse,

  /// The server rejected the request; see [ApiException.message].
  server,
}

class ApiException implements Exception {
  const ApiException(
    this.kind, {
    this.message,
    this.statusCode,
    this.code,
    this.fields = const {},
  });

  /// Builds an exception from the API error format:
  /// `{"error": {"code": ..., "message": ..., "fields": {...}}}`.
  factory ApiException.fromBody(int statusCode, Object? body) {
    final error = body is Map<String, dynamic> ? body['error'] : null;
    if (error is Map<String, dynamic> && error['message'] is String) {
      final fields = error['fields'];
      return ApiException(
        ApiErrorKind.server,
        message: error['message'] as String,
        statusCode: statusCode,
        code: error['code'] as String?,
        fields: fields is Map<String, dynamic>
            ? fields.map((k, v) => MapEntry(k, '$v'))
            : const {},
      );
    }
    return ApiException(ApiErrorKind.badResponse, statusCode: statusCode);
  }

  final ApiErrorKind kind;

  /// Message from the server, already in the requested language. Null for
  /// errors detected by the app, which the UI describes from [kind].
  final String? message;
  final int? statusCode;

  /// Machine-readable error code from the API, e.g. `plan_full`.
  final String? code;

  /// Validation problems keyed by JSON field name.
  final Map<String, String> fields;

  @override
  String toString() => message ?? 'ApiException(${kind.name}, $statusCode)';
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

  /// Development identity sent as `X-User-Id` on plan requests, so the API
  /// can tell whether this user participates in a plan.
  final String userId;

  /// Language sent as `Accept-Language`, so activity names and error
  /// messages come back translated. The app keeps it in sync with its locale.
  String languageCode = 'es';

  final http.Client _client;

  Future<List<Activity>> fetchActivities() async {
    final json = await _send(
      () => _client.get(_uri('/activities'), headers: _languageHeader),
    );
    return _list(json['activities'], Activity.fromJson);
  }

  Future<List<Zone>> fetchZones() async {
    final json = await _send(
      () => _client.get(_uri('/zones'), headers: _languageHeader),
    );
    return _list(json['zones'], Zone.fromJson);
  }

  /// Future plans ordered by availability, distance to [zoneId] and date.
  Future<List<Plan>> fetchPlans({
    required String zoneId,
    String? activityId,
  }) async {
    final query = {'zone': zoneId, 'activity': ?activityId};
    final json = await _send(
      () => _client.get(_uri('/plans', query), headers: _userHeaders),
    );
    return _list(json['plans'], Plan.fromJson);
  }

  Future<Plan> fetchPlan(String id) async {
    final json = await _send(
      () => _client.get(_planUri(id), headers: _userHeaders),
    );
    return Plan.fromJson(json);
  }

  Future<Plan> createPlan(NewPlan plan) async {
    final json = await _send(
      () => _client.post(
        _uri('/plans'),
        headers: {..._userHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode(plan.toJson()),
      ),
    );
    return Plan.fromJson(json);
  }

  /// Adds the current user to the plan, showing [zoneId] to others, and
  /// returns the updated plan. Fails with an [ApiException] whose
  /// [ApiException.code] is `already_joined`, `plan_full`, `plan_cancelled`
  /// or `plan_ended` when joining is not possible.
  Future<Plan> joinPlan(String id, {required String zoneId}) async {
    final json = await _send(
      () => _client.post(
        _planUri(id, '/participants'),
        headers: {..._userHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode({'zoneId': zoneId}),
      ),
    );
    return Plan.fromJson(json);
  }

  Future<AvatarOptions> fetchAvatarOptions() async {
    final json = await _send(
      () => _client.get(_uri('/avatar-options'), headers: _languageHeader),
    );
    return AvatarOptions.fromJson(json);
  }

  /// The current user's avatar, or the default one derived from their id if
  /// they never saved one.
  Future<AvatarProfile> fetchMyAvatar() async {
    final json = await _send(
      () => _client.get(_uri('/me/avatar'), headers: _userHeaders),
    );
    return _avatarProfile(json);
  }

  Future<AvatarProfile> saveMyAvatar(Avatar avatar) async {
    final json = await _send(
      () => _client.put(
        _uri('/me/avatar'),
        headers: {..._userHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode(avatar.toJson()),
      ),
    );
    return _avatarProfile(json);
  }

  /// Zone layout plus upcoming and ongoing plans with their participants'
  /// avatars, soonest first.
  Future<CityMap> fetchMap({String? activityId}) async {
    final query = {'activity': ?activityId};
    final json = await _send(
      () => _client.get(_uri('/map', query), headers: _userHeaders),
    );
    return CityMap.fromJson(json);
  }

  AvatarProfile _avatarProfile(Map<String, dynamic> json) => (
    avatar: Avatar.fromJson(json['avatar'] as Map<String, dynamic>),
    isDefault: json['isDefault'] as bool,
  );

  Map<String, String> get _languageHeader => {'Accept-Language': languageCode};

  Map<String, String> get _userHeaders => {
    ..._languageHeader,
    'X-User-Id': userId,
  };

  Uri _planUri(String id, [String suffix = '']) =>
      _uri('/plans/${Uri.encodeComponent(id)}$suffix');

  // An empty query map would still add a trailing "?".
  Uri _uri(String path, [Map<String, String>? query]) => _baseUrl.replace(
    path: path,
    queryParameters: query == null || query.isEmpty ? null : query,
  );

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(ApiErrorKind.timeout);
    } on http.ClientException {
      throw const ApiException(ApiErrorKind.connection);
    }

    final Object? body;
    try {
      // Decode bytes as UTF-8 explicitly: `response.body` falls back to
      // Latin-1 when the Content-Type has no charset, garbling "café".
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw ApiException(
        ApiErrorKind.badResponse,
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
