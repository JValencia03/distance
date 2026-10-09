/// An entry of the predefined activity catalog.
class Activity {
  const Activity({required this.id, required this.name});

  factory Activity.fromJson(Map<String, dynamic> json) =>
      Activity(id: json['id'] as String, name: json['name'] as String);

  final String id;
  final String name;

  // Equality by id lets catalog entries from different responses match, e.g.
  // as the selected value of a dropdown.
  @override
  bool operator ==(Object other) => other is Activity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A predefined area used as a coarse reference location. The server keeps
/// its coordinates; the app only knows its id and name.
class Zone {
  const Zone({required this.id, required this.name});

  factory Zone.fromJson(Map<String, dynamic> json) =>
      Zone(id: json['id'] as String, name: json['name'] as String);

  final String id;
  final String name;

  @override
  bool operator ==(Object other) => other is Zone && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Activity and zone catalogs, loaded once and shared between screens.
typedef Catalog = ({List<Activity> activities, List<Zone> zones});

class Plan {
  const Plan({
    required this.id,
    required this.activity,
    required this.title,
    required this.description,
    required this.zone,
    required this.place,
    required this.startsAt,
    required this.participantCount,
    required this.maxParticipants,
    required this.isFull,
    required this.distanceKm,
  });

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
    id: json['id'] as String,
    activity: Activity.fromJson(json['activity'] as Map<String, dynamic>),
    title: json['title'] as String,
    description: json['description'] as String?,
    zone: Zone.fromJson(json['zone'] as Map<String, dynamic>),
    place: json['place'] as String,
    startsAt: DateTime.parse(json['startsAt'] as String),
    participantCount: json['participantCount'] as int,
    maxParticipants: json['maxParticipants'] as int?,
    isFull: json['isFull'] as bool,
    distanceKm: (json['distanceKm'] as num?)?.toDouble(),
  );

  final String id;
  final Activity activity;
  final String title;
  final String? description;
  final Zone zone;
  final String place;

  /// Start time in UTC, as sent by the server. Use [DateTime.toLocal] to
  /// display it.
  final DateTime startsAt;
  final int participantCount;
  final int? maxParticipants;
  final bool isFull;

  /// Distance between the reference zone and the plan's zone. Only present
  /// in discovery results.
  final double? distanceKm;
}

/// Data needed to create a plan.
class NewPlan {
  const NewPlan({
    required this.activityId,
    required this.title,
    required this.description,
    required this.zoneId,
    required this.place,
    required this.startsAt,
    required this.maxParticipants,
  });

  final String activityId;
  final String title;
  final String? description;
  final String zoneId;
  final String place;
  final DateTime startsAt;
  final int? maxParticipants;

  Map<String, Object?> toJson() => {
    'activityId': activityId,
    'title': title,
    'description': description,
    'zoneId': zoneId,
    'place': place,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'maxParticipants': maxParticipants,
  };
}
