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
    required this.endsAt,
    required this.isCancelled,
    required this.participantCount,
    required this.maxParticipants,
    required this.isFull,
    required this.isParticipant,
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
    endsAt: DateTime.parse(json['endsAt'] as String),
    isCancelled: json['status'] == 'cancelled',
    participantCount: json['participantCount'] as int,
    maxParticipants: json['maxParticipants'] as int?,
    isFull: json['isFull'] as bool,
    isParticipant: json['isParticipant'] as bool,
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

  /// End time in UTC; people can join until then.
  final DateTime endsAt;
  final bool isCancelled;
  final int participantCount;
  final int? maxParticipants;
  final bool isFull;

  /// Whether the current user (the `X-User-Id` sent by the app) participates.
  final bool isParticipant;

  /// Distance between the reference zone and the plan's zone. Only present
  /// in discovery results.
  final double? distanceKm;

  Duration get duration => endsAt.difference(startsAt);

  /// Whether the plan has started but not ended at [now]. Computed here
  /// rather than read from the API's `isOngoing`, so it stays right while a
  /// screen remains open.
  bool isOngoingAt(DateTime now) =>
      !startsAt.isAfter(now) && endsAt.isAfter(now);

  /// What the current user can do with this plan at [now], checked in the
  /// same order as the API: cancelled, ended, joined, full.
  JoinAvailability joinAvailability(DateTime now) {
    if (isCancelled) return JoinAvailability.cancelled;
    if (!endsAt.isAfter(now)) return JoinAvailability.ended;
    if (isParticipant) return JoinAvailability.joined;
    if (isFull) return JoinAvailability.full;
    return JoinAvailability.available;
  }
}

enum JoinAvailability { available, joined, full, cancelled, ended }

/// Data needed to create a plan.
class NewPlan {
  const NewPlan({
    required this.activityId,
    required this.title,
    required this.description,
    required this.zoneId,
    required this.place,
    required this.startsAt,
    required this.duration,
    required this.maxParticipants,
    required this.creatorZoneId,
  });

  final String activityId;
  final String title;
  final String? description;
  final String zoneId;
  final String place;
  final DateTime startsAt;

  /// Sent in whole minutes; the API accepts 15 minutes to 12 hours.
  final Duration duration;
  final int? maxParticipants;

  /// Zone the creator shows to others, which may differ from [zoneId].
  final String creatorZoneId;

  Map<String, Object?> toJson() => {
    'activityId': activityId,
    'title': title,
    'description': description,
    'zoneId': zoneId,
    'place': place,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'durationMinutes': duration.inMinutes,
    'maxParticipants': maxParticipants,
    'creatorZoneId': creatorZoneId,
  };
}

/// The character a user is drawn as on the plans map. Every field is an id
/// from the server's avatar catalog; see `AvatarStyle` for how each one is
/// drawn.
class Avatar {
  const Avatar({
    required this.skin,
    required this.bodyColor,
    required this.skinTone,
    required this.accessory,
  });

  factory Avatar.fromJson(Map<String, dynamic> json) => Avatar(
    skin: json['skin'] as String,
    bodyColor: json['bodyColor'] as String,
    skinTone: json['skinTone'] as String,
    accessory: json['accessory'] as String,
  );

  final String skin;
  final String bodyColor;
  final String skinTone;
  final String accessory;

  Avatar copyWith({
    String? skin,
    String? bodyColor,
    String? skinTone,
    String? accessory,
  }) => Avatar(
    skin: skin ?? this.skin,
    bodyColor: bodyColor ?? this.bodyColor,
    skinTone: skinTone ?? this.skinTone,
    accessory: accessory ?? this.accessory,
  );

  Map<String, Object?> toJson() => {
    'skin': skin,
    'bodyColor': bodyColor,
    'skinTone': skinTone,
    'accessory': accessory,
  };

  @override
  bool operator ==(Object other) =>
      other is Avatar &&
      other.skin == skin &&
      other.bodyColor == bodyColor &&
      other.skinTone == skinTone &&
      other.accessory == accessory;

  @override
  int get hashCode => Object.hash(skin, bodyColor, skinTone, accessory);
}

/// The current user's avatar. [isDefault] is true until they save one.
typedef AvatarProfile = ({Avatar avatar, bool isDefault});

/// A named entry of an avatar catalog, such as a skin or an accessory.
class AvatarOption {
  const AvatarOption({required this.id, required this.name});

  factory AvatarOption.fromJson(Map<String, dynamic> json) =>
      AvatarOption(id: json['id'] as String, name: json['name'] as String);

  final String id;
  final String name;
}

/// Every value each avatar field accepts. Colors are ids without names: the
/// app shows them as swatches.
class AvatarOptions {
  const AvatarOptions({
    required this.skins,
    required this.bodyColors,
    required this.skinTones,
    required this.accessories,
  });

  factory AvatarOptions.fromJson(Map<String, dynamic> json) => AvatarOptions(
    skins: _options(json['skins']),
    bodyColors: (json['bodyColors'] as List).cast<String>(),
    skinTones: (json['skinTones'] as List).cast<String>(),
    accessories: _options(json['accessories']),
  );

  static List<AvatarOption> _options(Object? json) => (json as List)
      .map((e) => AvatarOption.fromJson(e as Map<String, dynamic>))
      .toList();

  final List<AvatarOption> skins;
  final List<String> bodyColors;
  final List<String> skinTones;
  final List<AvatarOption> accessories;
}

/// A zone placed on the map. [x] and [y] are normalized to 0..1, with x
/// growing east and y growing south.
class MapZone {
  const MapZone({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
  });

  factory MapZone.fromJson(Map<String, dynamic> json) => MapZone(
    id: json['id'] as String,
    name: json['name'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
  );

  final String id;
  final String name;
  final double x;
  final double y;
}

/// Someone taking part in a plan, as shown on the map: their avatar and the
/// zone they chose. The API never sends who they are.
class MapParticipant {
  const MapParticipant({
    required this.avatar,
    required this.zoneId,
    required this.isMe,
  });

  factory MapParticipant.fromJson(Map<String, dynamic> json) => MapParticipant(
    avatar: Avatar.fromJson(json['avatar'] as Map<String, dynamic>),
    zoneId: json['zoneId'] as String,
    isMe: json['isMe'] as bool,
  );

  final Avatar avatar;
  final String zoneId;
  final bool isMe;
}

/// A plan on the map with its participants.
typedef MapPlan = ({Plan plan, List<MapParticipant> participants});

/// What the map shows: the zone layout and the upcoming and ongoing plans.
class CityMap {
  const CityMap({required this.zones, required this.plans});

  factory CityMap.fromJson(Map<String, dynamic> json) => CityMap(
    zones: (json['zones'] as List)
        .map((e) => MapZone.fromJson(e as Map<String, dynamic>))
        .toList(),
    plans: (json['plans'] as List).map((e) {
      final plan = e as Map<String, dynamic>;
      return (
        plan: Plan.fromJson(plan),
        participants: (plan['participants'] as List)
            .map((p) => MapParticipant.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
    }).toList(),
  );

  final List<MapZone> zones;
  final List<MapPlan> plans;
}
