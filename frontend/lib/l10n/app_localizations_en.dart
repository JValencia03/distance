// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Distance';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get homeTitle => 'What do you want to do?';

  @override
  String get homeSubtitle => 'Pick an activity and find plans near you.';

  @override
  String get chooseZone => 'Choose your zone';

  @override
  String get zonePickerTitle => 'Where do you want to look for plans?';

  @override
  String get allPlans => 'All plans';

  @override
  String get filterAll => 'All';

  @override
  String get createPlan => 'Create plan';

  @override
  String get planCreated => 'Plan created';

  @override
  String noPlansTitle(String zone) {
    return 'No plans near $zone';
  }

  @override
  String noActivityPlansTitle(String activity, String zone) {
    return 'No $activity plans near $zone';
  }

  @override
  String get noPlansMessage => 'Create one and let other people join.';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading…';

  @override
  String get errorConnection => 'Couldn\'t connect to the server.';

  @override
  String get errorTimeout => 'The server took too long to respond.';

  @override
  String get errorUnexpectedResponse => 'Unexpected response from the server.';

  @override
  String get planScreenTitle => 'Plan';

  @override
  String get detailActivity => 'Activity';

  @override
  String get detailWhen => 'When';

  @override
  String get detailMeetingPoint => 'Meeting point';

  @override
  String get detailParticipants => 'Participants';

  @override
  String get join => 'Join';

  @override
  String get joinZoneTitle => 'Which zone are you joining from?';

  @override
  String get joinZoneNotice =>
      'Others will see this zone on the plan\'s map. It is approximate: we never share your exact location.';

  @override
  String joinFromZone(String zone) {
    return 'Join from $zone';
  }

  @override
  String get joinSuccess => 'You\'re in! You now participate in this plan.';

  @override
  String get noticeJoined => 'You participate in this plan';

  @override
  String get noticeFull => 'No spots left';

  @override
  String get noticeCancelled => 'This plan was cancelled';

  @override
  String get noticeEnded => 'This plan has already ended';

  @override
  String get chipAvailable => 'Open';

  @override
  String get chipJoined => 'Joined';

  @override
  String get chipFull => 'Full';

  @override
  String get chipCancelled => 'Cancelled';

  @override
  String get chipOngoing => 'Happening now';

  @override
  String get chipEnded => 'Ended';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    return '$hours h';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String participants(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0';
  }

  @override
  String participantsWithLimit(int count, int max) {
    return '$count/$max participants';
  }

  @override
  String get distanceSameZone => 'In your zone';

  @override
  String distanceAway(String km) {
    return '$km km away';
  }

  @override
  String get fieldActivity => 'Activity';

  @override
  String get fieldTitle => 'Title';

  @override
  String get fieldTitleHint => 'E.g. Quiet reading at a café';

  @override
  String get fieldDescription => 'Description (optional)';

  @override
  String get fieldZone => 'Zone';

  @override
  String get fieldPlace => 'Meeting point';

  @override
  String get fieldPlaceHint => 'E.g. Corner café, main entrance';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldTime => 'Time';

  @override
  String get fieldDuration => 'Duration';

  @override
  String get fieldCreatorZone => 'Your zone';

  @override
  String get fieldCreatorZoneHelper =>
      'Others will see this zone on the plan\'s map.';

  @override
  String get fieldLimit => 'Participant limit (optional)';

  @override
  String get fieldLimitHelper => 'Including you. Leave empty for no limit.';

  @override
  String get publishPlan => 'Publish plan';

  @override
  String get errorChooseActivity => 'Choose an activity.';

  @override
  String get errorTitleRequired => 'Title is required.';

  @override
  String get errorChooseZone => 'Choose a zone.';

  @override
  String get errorPlaceRequired => 'Meeting point is required.';

  @override
  String errorLimitRange(int min, int max) {
    return 'Enter a number between $min and $max.';
  }

  @override
  String get errorStartsAtRequired => 'Choose the date and time.';

  @override
  String get errorStartsAtPast => 'The date and time must be in the future.';

  @override
  String get settingsCharacter => 'Your character';

  @override
  String get settingsCharacterSubtitle => 'How others see you on the map';

  @override
  String get avatarTitle => 'Your character';

  @override
  String get avatarSubtitle =>
      'This is how others will see you on the plans map.';

  @override
  String get avatarDefaultHint =>
      'This is your default character. Make it your own.';

  @override
  String get avatarSkin => 'Look';

  @override
  String get avatarBodyColor => 'Color';

  @override
  String get avatarSkinTone => 'Skin tone';

  @override
  String get avatarAccessory => 'Accessory';

  @override
  String get avatarSave => 'Save character';

  @override
  String get avatarSaved => 'Character saved';

  @override
  String get preview3dUnavailable =>
      'The 3D view isn\'t available on this device.';

  @override
  String get colorCoral => 'Coral';

  @override
  String get colorMint => 'Mint';

  @override
  String get colorLavender => 'Lavender';

  @override
  String get colorSky => 'Sky';

  @override
  String get colorSunflower => 'Sunflower';

  @override
  String get colorPeach => 'Peach';

  @override
  String get colorForest => 'Forest';

  @override
  String get colorCharcoal => 'Charcoal';

  @override
  String skinToneName(int number) {
    return 'Tone $number';
  }

  @override
  String get openMap => 'Open map';

  @override
  String get mapTitle => 'Plans map';

  @override
  String get mapHint => 'Drag to move · pinch to zoom or turn';

  @override
  String get mapEmptyTitle => 'No plans on the map yet';

  @override
  String get mapEmptyMessage =>
      'When someone creates or joins a plan, it shows up here.';

  @override
  String get mapLegendOngoing => 'Happening now';

  @override
  String get mapLegendUpcoming => 'Upcoming';

  @override
  String get mapYou => 'You';

  @override
  String get mapNow => 'Now';

  @override
  String mapPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String mapFromZones(String zones) {
    return 'From $zones';
  }

  @override
  String get mapOpenPlan => 'View plan';

  @override
  String get mapEditCharacter => 'Edit character';

  @override
  String mapGroupLabel(
    String activity,
    String title,
    String people,
    String zone,
  ) {
    return '$activity: $title, $people in $zone';
  }
}
