import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';
import 'package:distance/features/plans/plan_widgets.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/shared/activity_style.dart';
import 'package:distance/shared/clay.dart';
import 'package:distance/shared/emoji.dart';
import 'package:distance/shared/formatting.dart';
import 'package:distance/shared/illustration.dart';
import 'package:distance/shared/motion.dart';
import 'package:distance/shared/status_views.dart';

/// Shows the latest details of a plan, fetched by id, and lets the user join.
class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({
    super.key,
    required this.api,
    required this.planId,
    required this.zones,
    required this.viewerZone,
    this.preview,
  });

  final DistanceApi api;
  final String planId;

  /// Zones the user can choose to show when joining.
  final List<Zone> zones;

  /// The zone the user is searching from, preselected when joining.
  final Zone viewerZone;

  /// The plan as the previous screen knew it. It is shown while the latest
  /// version loads, so the screen (and its hero animation) never starts
  /// blank; joining waits for the fresh copy.
  final Plan? preview;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  // Explicit state instead of a FutureBuilder: after joining, the plan is
  // replaced in place without going back to a loading state.
  Plan? _plan;
  Object? _loadError;
  bool _joining = false;

  /// Successful joins so far; each one plays a new confetti burst.
  int _celebrations = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final plan = await widget.api.fetchPlan(widget.planId);
      if (mounted) setState(() => _plan = plan);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  Future<void> _join() async {
    // The button is disabled while joining; this also guards against taps
    // delivered before the rebuild.
    if (_joining) return;
    // The zone is visible to others, so the user confirms it every time.
    final zone = await showModalBottomSheet<Zone>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          _JoinZoneSheet(zones: widget.zones, initial: widget.viewerZone),
    );
    if (zone == null || !mounted || _joining) return;
    setState(() => _joining = true);
    try {
      final plan = await widget.api.joinPlan(widget.planId, zoneId: zone.id);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _celebrations++;
      });
      HapticFeedback.mediumImpact();
      _showMessage(AppLocalizations.of(context).joinSuccess);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(describeError(error, AppLocalizations.of(context)));
      // A conflict means our copy is stale (full, cancelled, ended or
      // already joined): refresh it so the screen shows the real state.
      if (error.statusCode == 409) await _refreshQuietly();
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  /// Refreshes the plan while keeping the current one on screen if it fails.
  Future<void> _refreshQuietly() async {
    try {
      final plan = await widget.api.fetchPlan(widget.planId);
      if (mounted) setState(() => _plan = plan);
    } on ApiException {
      // Keep showing the plan we have; the error was already reported.
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Only the freshly loaded plan allows joining; the preview is for show.
    final fresh = _plan;
    final plan = fresh ?? (_loadError == null ? widget.preview : null);
    final Widget body;
    if (plan != null) {
      body = _PlanDetails(plan: plan);
    } else if (_loadError != null) {
      body = ErrorView(error: _loadError!, onRetry: _load);
    } else {
      body = const LoadingView();
    }
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).planScreenTitle)),
      body: Stack(
        children: [
          Positioned.fill(child: body),
          if (_celebrations > 0)
            Positioned.fill(
              child: ConfettiBurst(
                key: ValueKey(_celebrations),
                colors: [
                  colors.primary,
                  colors.secondary,
                  colors.tertiary,
                  colors.primaryContainer,
                  colors.secondaryContainer,
                  colors.tertiaryContainer,
                ],
              ),
            ),
          if (_celebrations > 0)
            Align(
              alignment: const Alignment(0, 0.35),
              child: SuccessBurst(key: ValueKey(_celebrations)),
            ),
        ],
      ),
      bottomNavigationBar: fresh == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _JoinAction(
                  availability: fresh.joinAvailability(DateTime.now()),
                  joining: _joining,
                  onJoin: _join,
                ),
              ),
            ),
    );
  }
}

class _PlanDetails extends StatelessWidget {
  const _PlanDetails({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = ActivityStyle.of(plan.activity.id);
    final description = plan.description;
    final limit = plan.maxParticipants;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: clayDecoration(colors, style.tint(colors), radius: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Emoji3d(style.emoji, size: 88, heroTag: planHeroTag(plan.id)),
                  const Spacer(),
                  AvailabilityChip(plan: plan),
                ],
              ),
              const SizedBox(height: 16),
              Text(plan.title, style: theme.textTheme.headlineMedium),
              if (description != null) ...[
                const SizedBox(height: 10),
                Text(description, style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Entrance(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: clayDecoration(colors, colors.surfaceContainerLowest),
            child: Column(
              children: [
                _DetailRow(
                  icon: style.icon,
                  label: l10n.detailActivity,
                  value: plan.activity.name,
                ),
                _DetailRow(
                  icon: Icons.schedule_rounded,
                  label: l10n.detailWhen,
                  value: formatPlanSchedule(
                    plan,
                    now: DateTime.now(),
                    l10n: l10n,
                  ),
                ),
                _DetailRow(
                  icon: Icons.hourglass_bottom_rounded,
                  label: l10n.fieldDuration,
                  value: formatDuration(plan.duration, l10n),
                ),
                _DetailRow(
                  icon: Icons.place_outlined,
                  label: l10n.detailMeetingPoint,
                  value: '${plan.place}, ${plan.zone.name}',
                ),
                _DetailRow(
                  icon: Icons.group_outlined,
                  label: l10n.detailParticipants,
                  value: formatParticipants(plan, l10n),
                ),
                // Small limits are also drawn as seats; the text above
                // already says the same for screen readers.
                if (limit != null && limit <= _Seats.maxSeats)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(56, 0, 0, 12),
                    child: _Seats(taken: plan.participantCount, total: limit),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One circle per seat of the plan; taken seats fill in with a bounce.
class _Seats extends StatelessWidget {
  const _Seats({required this.taken, required this.total});

  static const maxSeats = 20;

  final int taken;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var seat = 0; seat < total; seat++)
              AnimatedContainer(
                // Seats fill one after another.
                duration: Duration(milliseconds: 350 + seat * 60),
                curve: Curves.easeOutBack,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: seat < taken
                      ? colors.primary
                      : colors.surfaceContainerHighest,
                ),
                child: seat < taken
                    ? Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: colors.onPrimary,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// Main action of the detail screen: a join button when joining is possible,
/// otherwise a notice explaining why not. Switching between them morphs with
/// a springy scale.
class _JoinAction extends StatelessWidget {
  const _JoinAction({
    required this.availability,
    required this.joining,
    required this.onJoin,
  });

  final JoinAvailability availability;
  final bool joining;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Widget action = switch (availability) {
      JoinAvailability.available => SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: joining ? null : onJoin,
          child: joining
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.join),
        ),
      ),
      JoinAvailability.joined => _Notice(
        icon: Icons.check_circle_rounded,
        text: l10n.noticeJoined,
        highlighted: true,
      ),
      JoinAvailability.full => _Notice(
        icon: Icons.block,
        text: l10n.noticeFull,
      ),
      JoinAvailability.cancelled => _Notice(
        icon: Icons.event_busy_outlined,
        text: l10n.noticeCancelled,
      ),
      JoinAvailability.ended => _Notice(
        icon: Icons.history,
        text: l10n.noticeEnded,
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.elasticOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: KeyedSubtree(key: ValueKey(availability), child: action),
    );
  }
}

/// Asks which zone to show to the plan's other participants. Pops with the
/// chosen [Zone], or null if dismissed.
class _JoinZoneSheet extends StatefulWidget {
  const _JoinZoneSheet({required this.zones, required this.initial});

  final List<Zone> zones;
  final Zone initial;

  @override
  State<_JoinZoneSheet> createState() => _JoinZoneSheetState();
}

class _JoinZoneSheetState extends State<_JoinZoneSheet> {
  late Zone _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                l10n.joinZoneTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.joinZoneNotice,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: RadioGroup<Zone>(
                groupValue: _selected,
                onChanged: (zone) {
                  if (zone != null) setState(() => _selected = zone);
                },
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final zone in widget.zones)
                      RadioListTile<Zone>(value: zone, title: Text(zone.name)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_selected),
                child: Text(l10n.joinFromZone(_selected.name)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    this.highlighted = false,
  });

  final IconData icon;
  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = highlighted
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 22, color: colors.onSecondaryContainer),
      ),
      title: Text(value, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(label),
    );
  }
}
