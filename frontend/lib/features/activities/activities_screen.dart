import 'package:flutter/material.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';
import 'package:distance/features/plans/plans_screen.dart';
import 'package:distance/shared/activity_icon.dart';
import 'package:distance/shared/status_views.dart';

/// Home screen: the user starts by choosing what they want to do.
class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key, required this.api});

  final DistanceApi api;

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  late Future<Catalog> _catalog = _load();
  Zone? _zone;

  Future<Catalog> _load() async {
    final results = await Future.wait([
      widget.api.fetchActivities(),
      widget.api.fetchZones(),
    ]);
    return (
      activities: results[0] as List<Activity>,
      zones: results[1] as List<Zone>,
    );
  }

  Future<Zone?> _pickZone(List<Zone> zones) async {
    final zone = await showModalBottomSheet<Zone>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ZonePicker(zones: zones, selected: _zone),
    );
    if (zone != null) setState(() => _zone = zone);
    return zone;
  }

  Future<void> _openActivity(Catalog catalog, Activity activity) async {
    final zone = _zone ?? await _pickZone(catalog.zones);
    if (zone == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlansScreen(
          api: widget.api,
          catalog: catalog,
          zone: zone,
          initialActivity: activity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Distance')),
      body: FutureBuilder(
        future: _catalog,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return MessageView.error(
              error: snapshot.error!,
              onRetry: () => setState(() {
                _catalog = _load();
              }),
            );
          }
          final catalog = snapshot.data;
          if (catalog == null) return const LoadingView();
          return _buildCatalog(context, catalog);
        },
      ),
    );
  }

  Widget _buildCatalog(BuildContext context, Catalog catalog) {
    final textTheme = Theme.of(context).textTheme;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverList.list(
            children: [
              Text('¿Qué quieres hacer?', style: textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Elige una actividad y encuentra planes cerca de ti.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.place_outlined),
                  label: Text(_zone?.name ?? 'Elige tu zona'),
                  onPressed: () => _pickZone(catalog.zones),
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: catalog.activities.length,
            itemBuilder: (context, index) {
              final activity = catalog.activities[index];
              return _ActivityCard(
                activity: activity,
                onTap: () => _openActivity(catalog, activity),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.onTap});

  final Activity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card.filled(
      color: colors.secondaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                activityIcon(activity.id),
                color: colors.onSecondaryContainer,
              ),
              Text(
                activity.name,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: colors.onSecondaryContainer),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZonePicker extends StatelessWidget {
  const _ZonePicker({required this.zones, required this.selected});

  final List<Zone> zones;
  final Zone? selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '¿Dónde quieres buscar planes?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final zone in zones)
                  ListTile(
                    title: Text(zone.name),
                    trailing: zone == selected ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.of(context).pop(zone),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
