import 'package:flutter/material.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/shared/activity_style.dart';
import 'package:distance/shared/emoji.dart';
import 'package:distance/shared/formatting.dart';
import 'package:distance/shared/status_views.dart';

/// Limits mirrored from the API so most mistakes are caught before sending.
const maxTitleLength = 80;
const maxDescriptionLength = 500;
const maxPlaceLength = 120;
const minParticipantsLimit = 2;
const maxParticipantsLimit = 50;

/// Durations offered when creating a plan, within the API's 15 min–12 h.
const planDurations = [
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(minutes: 45),
  Duration(hours: 1),
  Duration(hours: 1, minutes: 30),
  Duration(hours: 2),
  Duration(hours: 3),
  Duration(hours: 4),
  Duration(hours: 6),
  Duration(hours: 8),
  Duration(hours: 12),
];
const defaultPlanDuration = Duration(hours: 1);

String? validateRequired(String? value, String message) =>
    (value == null || value.trim().isEmpty) ? message : null;

/// The participant limit is optional; when present it must be 2–50.
String? validateMaxParticipants(String? value, AppLocalizations l10n) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final limit = int.tryParse(text);
  if (limit == null ||
      limit < minParticipantsLimit ||
      limit > maxParticipantsLimit) {
    return l10n.errorLimitRange(minParticipantsLimit, maxParticipantsLimit);
  }
  return null;
}

String? validateStartsAt(
  DateTime? startsAt, {
  required DateTime now,
  required AppLocalizations l10n,
}) {
  if (startsAt == null) return l10n.errorStartsAtRequired;
  if (!startsAt.isAfter(now)) return l10n.errorStartsAtPast;
  return null;
}

/// Form to create a plan. Pops with the created [Plan] on success.
class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({
    super.key,
    required this.api,
    required this.catalog,
    this.initialActivity,
    this.initialZone,
  });

  final DistanceApi api;
  final Catalog catalog;
  final Activity? initialActivity;
  final Zone? initialZone;

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _place = TextEditingController();
  final _maxParticipants = TextEditingController();
  late Activity? _activity = widget.initialActivity;
  late Zone? _zone = widget.initialZone;

  /// Zone the creator shows to others. Null means "same as the plan's zone",
  /// so it follows [_zone] until the user picks one explicitly.
  Zone? _creatorZone;
  Duration _duration = defaultPlanDuration;
  DateTime? _date;
  TimeOfDay? _time;
  String? _startsAtError;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _place.dispose();
    _maxParticipants.dispose();
    super.dispose();
  }

  DateTime? get _startsAt {
    final date = _date;
    final time = _time;
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (time != null) setState(() => _time = time);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final formValid = _formKey.currentState!.validate();
    setState(
      () => _startsAtError = validateStartsAt(
        _startsAt,
        now: DateTime.now(),
        l10n: l10n,
      ),
    );
    if (!formValid || _startsAtError != null) return;

    final description = _description.text.trim();
    final limit = _maxParticipants.text.trim();
    final newPlan = NewPlan(
      activityId: _activity!.id,
      title: _title.text.trim(),
      description: description.isEmpty ? null : description,
      zoneId: _zone!.id,
      place: _place.text.trim(),
      startsAt: _startsAt!,
      duration: _duration,
      maxParticipants: limit.isEmpty ? null : int.parse(limit),
      creatorZoneId: (_creatorZone ?? _zone!).id,
    );

    setState(() => _submitting = true);
    try {
      final plan = await widget.api.createPlan(newPlan);
      if (mounted) Navigator.of(context).pop(plan);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final details = [describeError(e, l10n), ...e.fields.values].join('\n');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(details)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final time = _time;
    final date = _date;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createPlan)),
      body: Form(
        key: _formKey,
        // A Column (not a lazy ListView) keeps every field built, so
        // validate() also checks fields scrolled out of view.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<Activity>(
                initialValue: _activity,
                decoration: InputDecoration(labelText: l10n.fieldActivity),
                items: [
                  for (final activity in widget.catalog.activities)
                    DropdownMenuItem(
                      value: activity,
                      child: Row(
                        children: [
                          Emoji3d(
                            ActivityStyle.of(activity.id).emoji,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(activity.name),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) => _activity = value,
                validator: (value) =>
                    value == null ? l10n.errorChooseActivity : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: l10n.fieldTitle,
                  hintText: l10n.fieldTitleHint,
                ),
                maxLength: maxTitleLength,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) =>
                    validateRequired(value, l10n.errorTitleRequired),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(labelText: l10n.fieldDescription),
                maxLength: maxDescriptionLength,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Zone>(
                initialValue: _zone,
                decoration: InputDecoration(labelText: l10n.fieldZone),
                items: [
                  for (final zone in widget.catalog.zones)
                    DropdownMenuItem(value: zone, child: Text(zone.name)),
                ],
                // Rebuild so "Your zone" follows it when not chosen yet.
                onChanged: (value) => setState(() => _zone = value),
                validator: (value) =>
                    value == null ? l10n.errorChooseZone : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _place,
                decoration: InputDecoration(
                  labelText: l10n.fieldPlace,
                  hintText: l10n.fieldPlaceHint,
                ),
                maxLength: maxPlaceLength,
                validator: (value) =>
                    validateRequired(value, l10n.errorPlaceRequired),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PickerField(
                      label: l10n.fieldDate,
                      icon: Icons.calendar_today_outlined,
                      value: date == null
                          ? null
                          : formatDate(date, l10n.localeName),
                      onTap: _pickDate,
                      hasError: _startsAtError != null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PickerField(
                      label: l10n.fieldTime,
                      icon: Icons.schedule,
                      value: time == null
                          ? null
                          : MaterialLocalizations.of(context)
                                .formatTimeOfDay(time),
                      onTap: _pickTime,
                      hasError: _startsAtError != null,
                    ),
                  ),
                ],
              ),
              if (_startsAtError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Text(
                    _startsAtError!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Duration>(
                initialValue: _duration,
                decoration: InputDecoration(labelText: l10n.fieldDuration),
                items: [
                  for (final duration in planDurations)
                    DropdownMenuItem(
                      value: duration,
                      child: Text(formatDuration(duration, l10n)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) _duration = value;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Zone>(
                // initialValue is only read once; the key rebuilds the field
                // when it follows a new plan zone.
                key: ValueKey(_creatorZone ?? _zone),
                initialValue: _creatorZone ?? _zone,
                decoration: InputDecoration(
                  labelText: l10n.fieldCreatorZone,
                  helperText: l10n.fieldCreatorZoneHelper,
                  helperMaxLines: 2,
                ),
                items: [
                  for (final zone in widget.catalog.zones)
                    DropdownMenuItem(value: zone, child: Text(zone.name)),
                ],
                onChanged: (value) => setState(() => _creatorZone = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxParticipants,
                decoration: InputDecoration(
                  labelText: l10n.fieldLimit,
                  helperText: l10n.fieldLimitHelper,
                ),
                keyboardType: TextInputType.number,
                validator: (value) => validateMaxParticipants(value, l10n),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.publishPlan),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only field that opens a picker when tapped.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
    required this.hasError,
  });

  final String label;
  final IconData icon;
  final String? value;
  final VoidCallback onTap;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Icon(icon),
          enabledBorder: hasError
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: colors.error),
                )
              : null,
        ),
        isEmpty: value == null,
        child: Text(value ?? ''),
      ),
    );
  }
}
