import 'package:flutter/material.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';
import 'package:distance/features/avatar/avatar_badge.dart';
import 'package:distance/features/avatar/avatar_screen.dart';
import 'package:distance/features/map/city_map.dart';
import 'package:distance/features/map/map_layout.dart';
import 'package:distance/features/map/map_view.dart';
import 'package:distance/features/plans/plan_detail_screen.dart';
import 'package:distance/features/plans/plan_widgets.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/shared/activity_style.dart';
import 'package:distance/shared/formatting.dart';
import 'package:distance/shared/status_views.dart';

/// The plans map: who is doing what, and from which zone, for upcoming and
/// ongoing plans. Tapping a group shows its plan, which can be joined.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.api,
    required this.catalog,
    required this.zone,
    this.initialActivity,
    this.loadCity = loadCityMap,
  });

  final DistanceApi api;
  final Catalog catalog;

  /// The zone the user is searching from, preselected when joining.
  final Zone zone;
  final Activity? initialActivity;

  /// Loads the city drawn under the plans; the bundled one by default.
  final Future<CityMapAsset> Function() loadCity;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Activity? _activity = widget.initialActivity;
  CityMapAsset? _city;
  MapLayout? _layout;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (city, map) = await (
        widget.loadCity(),
        widget.api.fetchMap(activityId: _activity?.id),
      ).wait;
      if (!mounted) return;
      setState(() {
        _city = city;
        _layout = MapLayout.of(map, place: city.placeOf);
      });
    } catch (error) {
      if (mounted) setState(() => _error = unwrapWaitError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectActivity(Activity? activity) {
    if (activity == _activity) return;
    _activity = activity;
    _load();
  }

  Future<void> _showCluster(MapCluster cluster) async {
    final open = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (_) =>
          _PlanSheet(plan: cluster.plan, zones: widget.catalog.zones),
    );
    if (open != true || !mounted) return;
    final plan = cluster.plan.plan;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanDetailScreen(
          api: widget.api,
          planId: plan.id,
          zones: widget.catalog.zones,
          viewerZone: widget.zone,
          preview: plan,
        ),
      ),
    );
    // The user may have joined: their character now stands on the map.
    if (mounted) await _load();
  }

  Future<void> _editCharacter() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AvatarScreen(api: widget.api)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final layout = _layout;
    final city = _city;
    final Widget body;
    if (layout != null && city != null) {
      body = Stack(
        children: [
          Positioned.fill(
            child: MapView(
              city: city,
              layout: layout,
              focusZoneId: widget.zone.id,
              onClusterTap: _showCluster,
            ),
          ),
          if (_loading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: layout.clusters.isEmpty
                  ? _EmptyCard(
                      title: l10n.mapEmptyTitle,
                      message: l10n.mapEmptyMessage,
                    )
                  : _Legend(hint: l10n.mapHint),
            ),
          ),
        ],
      );
    } else if (_error != null) {
      body = ErrorView(error: _error!, onRetry: _load);
    } else {
      body = const LoadingView();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapTitle),
        actions: [
          IconButton(
            tooltip: l10n.mapEditCharacter,
            icon: const Icon(Icons.face_retouching_natural_rounded),
            onPressed: _editCharacter,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              children: [
                _FilterChip(
                  label: l10n.filterAll,
                  selected: _activity == null,
                  onSelected: () => _selectActivity(null),
                ),
                for (final activity in widget.catalog.activities)
                  _FilterChip(
                    label: activity.name,
                    selected: _activity == activity,
                    onSelected: () => _selectActivity(activity),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: body,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 10, color: liveColor),
                const SizedBox(width: 4),
                Text(l10n.mapLegendOngoing, style: theme.textTheme.labelMedium),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded, size: 14),
                const SizedBox(width: 4),
                Text(
                  l10n.mapLegendUpcoming,
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            Text(
              hint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary of a plan shown when its group is tapped. Pops with true to open
/// the plan.
class _PlanSheet extends StatelessWidget {
  const _PlanSheet({required this.plan, required this.zones});

  final MapPlan plan;
  final List<Zone> zones;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final details = plan.plan;
    final style = ActivityStyle.of(details.activity.id);
    final zoneNames = {for (final z in zones) z.id: z.name};
    final from = {
      for (final p in plan.participants) zoneNames[p.zoneId] ?? p.zoneId,
    }.join(', ');
    // The user first, as on the map.
    final people = [
      ...plan.participants.where((p) => p.isMe),
      ...plan.participants.where((p) => !p.isMe),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                EmojiBadge(
                  emoji: style.emoji,
                  color: style.tint(theme.colorScheme),
                  size: 52,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(details.title, style: theme.textTheme.titleLarge),
                      Text(
                        formatPlanSchedule(
                          details,
                          now: DateTime.now(),
                          l10n: l10n,
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                AvailabilityChip(plan: details),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${formatParticipants(details, l10n)} · ${l10n.mapFromZones(from)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: people.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, i) => Column(
                  children: [
                    AvatarBadge(avatar: people[i].avatar, size: 40),
                    if (people[i].isMe)
                      Text(l10n.mapYou, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.mapOpenPlan),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
