import 'package:intl/intl.dart';

import 'package:distance/data/models.dart';
import 'package:distance/l10n/app_localizations.dart';

/// Formats a local date and time in the app language, e.g. "Hoy · 17:00",
/// "Tomorrow · 5:00 PM" or "sáb, 17 oct · 9:30".
String formatPlanDate(
  DateTime local, {
  required DateTime now,
  required AppLocalizations l10n,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final label = switch (day.difference(today).inDays) {
    0 => l10n.today,
    1 => l10n.tomorrow,
    _ => formatDate(local, l10n.localeName),
  };
  return '$label · ${formatTime(local, l10n.localeName)}';
}

/// Start date and time plus end time, e.g. "Hoy · 17:00 – 18:30". Plans
/// last at most 12 hours, so the end is shown as a time only.
String formatPlanSchedule(
  Plan plan, {
  required DateTime now,
  required AppLocalizations l10n,
}) {
  final start = formatPlanDate(plan.startsAt.toLocal(), now: now, l10n: l10n);
  return '$start – ${formatTime(plan.endsAt.toLocal(), l10n.localeName)}';
}

/// "45 min", "2 h" or "1 h 30 min".
String formatDuration(Duration duration, AppLocalizations l10n) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) return l10n.durationMinutes(minutes);
  if (minutes == 0) return l10n.durationHours(hours);
  return l10n.durationHoursMinutes(hours, minutes);
}

/// Short date with weekday, ordered as the locale expects.
String formatDate(DateTime date, String locale) =>
    DateFormat.MMMEd(locale).format(date);

/// Time with the locale's clock convention (24 h or AM/PM).
String formatTime(DateTime time, String locale) =>
    DateFormat.jm(locale).format(time);

/// "3 participantes" or "3/5 participants".
String formatParticipants(Plan plan, AppLocalizations l10n) {
  final max = plan.maxParticipants;
  return max == null
      ? l10n.participants(plan.participantCount)
      : l10n.participantsWithLimit(plan.participantCount, max);
}

/// "En tu zona" or "A 1,2 km" / "1.2 km away". Distances are between zone
/// centers.
String formatDistance(double km, AppLocalizations l10n) => km == 0
    ? l10n.distanceSameZone
    : l10n.distanceAway(NumberFormat('0.0', l10n.localeName).format(km));
