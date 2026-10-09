import 'package:distance/data/models.dart';

const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Formats a local date and time, e.g. "Hoy · 17:00" or "sáb 10 oct · 17:00".
String formatPlanDate(DateTime local, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final time = formatTime(local.hour, local.minute);
  final days = day.difference(today).inDays;
  if (days == 0) return 'Hoy · $time';
  if (days == 1) return 'Mañana · $time';
  return '${formatDate(local)} · $time';
}

/// Formats a date, e.g. "sáb 10 oct".
String formatDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';

String formatTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// "3 participantes" or "3/5 participantes".
String formatParticipants(Plan plan) {
  final count = plan.maxParticipants == null
      ? '${plan.participantCount}'
      : '${plan.participantCount}/${plan.maxParticipants}';
  final noun = plan.participantCount == 1 && plan.maxParticipants == null
      ? 'participante'
      : 'participantes';
  return '$count $noun';
}

/// "En tu zona" or "A 1.2 km". Distances are between zone centers.
String formatDistance(double km) =>
    km == 0 ? 'En tu zona' : 'A ${km.toStringAsFixed(1)} km';
