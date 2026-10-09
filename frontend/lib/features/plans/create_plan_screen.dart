import 'package:flutter/material.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';
import 'package:distance/shared/formatting.dart';

/// Limits mirrored from the API so most mistakes are caught before sending.
const maxTitleLength = 80;
const maxDescriptionLength = 500;
const maxPlaceLength = 120;
const minParticipantsLimit = 2;
const maxParticipantsLimit = 50;

String? validateRequired(String? value, String message) =>
    (value == null || value.trim().isEmpty) ? message : null;

/// The participant limit is optional; when present it must be 2–50.
String? validateMaxParticipants(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final limit = int.tryParse(text);
  if (limit == null ||
      limit < minParticipantsLimit ||
      limit > maxParticipantsLimit) {
    return 'Escribe un número entre $minParticipantsLimit y $maxParticipantsLimit.';
  }
  return null;
}

String? validateStartsAt(DateTime? startsAt, {required DateTime now}) {
  if (startsAt == null) return 'Elige la fecha y la hora.';
  if (!startsAt.isAfter(now)) return 'La fecha y hora deben ser futuras.';
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
    final formValid = _formKey.currentState!.validate();
    setState(
      () => _startsAtError = validateStartsAt(_startsAt, now: DateTime.now()),
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
      maxParticipants: limit.isEmpty ? null : int.parse(limit),
    );

    setState(() => _submitting = true);
    try {
      final plan = await widget.api.createPlan(newPlan);
      if (mounted) Navigator.of(context).pop(plan);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final details = [e.message, ...e.fields.values].join('\n');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(details)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = _time;
    final date = _date;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear plan')),
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
                decoration: const InputDecoration(labelText: 'Actividad'),
                items: [
                  for (final activity in widget.catalog.activities)
                    DropdownMenuItem(
                      value: activity,
                      child: Text(activity.name),
                    ),
                ],
                onChanged: (value) => _activity = value,
                validator: (value) =>
                    value == null ? 'Elige una actividad.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ej.: Leer en silencio en un café',
                ),
                maxLength: maxTitleLength,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) =>
                    validateRequired(value, 'El título es obligatorio.'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
                maxLength: maxDescriptionLength,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Zone>(
                initialValue: _zone,
                decoration: const InputDecoration(labelText: 'Zona'),
                items: [
                  for (final zone in widget.catalog.zones)
                    DropdownMenuItem(value: zone, child: Text(zone.name)),
                ],
                onChanged: (value) => _zone = value,
                validator: (value) => value == null ? 'Elige una zona.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _place,
                decoration: const InputDecoration(
                  labelText: 'Lugar de encuentro',
                  hintText: 'Ej.: Café de la esquina, entrada principal',
                ),
                maxLength: maxPlaceLength,
                validator: (value) => validateRequired(
                  value,
                  'El lugar de encuentro es obligatorio.',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _PickerField(
                      label: 'Fecha',
                      icon: Icons.calendar_today_outlined,
                      value: date == null ? null : formatDate(date),
                      onTap: _pickDate,
                      hasError: _startsAtError != null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PickerField(
                      label: 'Hora',
                      icon: Icons.schedule,
                      value: time == null
                          ? null
                          : formatTime(time.hour, time.minute),
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
              TextFormField(
                controller: _maxParticipants,
                decoration: const InputDecoration(
                  labelText: 'Límite de participantes (opcional)',
                  helperText: 'Incluyéndote. Déjalo vacío para no limitar.',
                ),
                keyboardType: TextInputType.number,
                validator: validateMaxParticipants,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Publicar plan'),
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
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: Icon(icon),
          enabledBorder: hasError
              ? UnderlineInputBorder(
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
