import 'package:flutter/material.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';
import 'package:distance/features/plans/plans_screen.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/settings/app_settings.dart';
import 'package:distance/settings/settings_screen.dart';
import 'package:distance/shared/activity_style.dart';
import 'package:distance/shared/aurora_background.dart';
import 'package:distance/shared/clay.dart';
import 'package:distance/shared/emoji.dart';
import 'package:distance/shared/motion.dart';
import 'package:distance/shared/status_views.dart';

/// Home screen: the user starts by choosing what they want to do.
class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({
    super.key,
    required this.api,
    required this.settings,
  });

  final DistanceApi api;
  final AppSettings settings;

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  Future<Catalog>? _catalog;
  String? _language;
  Zone? _zone;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Activity names come translated from the API: load the catalog again
    // whenever the app language changes.
    final language = Localizations.localeOf(context).languageCode;
    if (language != _language) {
      _language = language;
      _catalog = _load();
    }
  }

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

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SettingsScreen(settings: widget.settings, api: widget.api),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The background sits behind a transparent scaffold so its glows also
    // show under the app bar.
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.appTitle),
          actions: [
            IconButton(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.settingsTitle,
            ),
          ],
        ),
        body: FutureBuilder(
          future: _catalog,
          builder: (context, snapshot) {
            // While a retry is in flight the snapshot still carries the old
            // error: only show it once the request has finished.
            final loading = snapshot.connectionState != ConnectionState.done;
            if (!loading && snapshot.hasError) {
              return ErrorView(
                error: snapshot.error!,
                onRetry: () => setState(() {
                  _catalog = _load();
                }),
              );
            }
            final catalog = snapshot.data;
            if (catalog == null) return const AnimatedLoadingView();
            return _buildCatalog(context, catalog);
          },
        ),
      ),
    );
  }

  Widget _buildCatalog(BuildContext context, Catalog catalog) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          sliver: SliverList.list(
            children: [
              Entrance(
                child: Text(l10n.homeTitle, style: textTheme.headlineLarge),
              ),
              const SizedBox(height: 6),
              Entrance(
                index: 1,
                child: Text(
                  l10n.homeSubtitle,
                  style: textTheme.bodyLarge?.copyWith(color: muted),
                ),
              ),
              const SizedBox(height: 20),
              Entrance(
                index: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _ZoneButton(
                    label: _zone?.name ?? l10n.chooseZone,
                    onPressed: () => _pickZone(catalog.zones),
                  ),
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.05,
            ),
            itemCount: catalog.activities.length,
            itemBuilder: (context, index) {
              final activity = catalog.activities[index];
              // Starts after the header so the grid arrives last.
              return Entrance(
                index: index + 3,
                child: Pressable3d(
                  child: _ActivityCard(
                    activity: activity,
                    onTap: () => _openActivity(catalog, activity),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Pill showing the selected zone; tapping it opens the zone picker.
class _ZoneButton extends StatelessWidget {
  const _ZoneButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const shape = StadiumBorder();
    return Semantics(
      button: true,
      child: DecoratedBox(
        decoration: clayDecoration(
          colors,
          colors.surfaceContainerLowest,
          radius: 100,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: shape,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Emoji3d(Emojis.pin, size: 26),
                  const SizedBox(width: 8),
                  Text(label, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
    final style = ActivityStyle.of(activity.id);
    final radius = BorderRadius.circular(28);
    return DecoratedBox(
      decoration: clayDecoration(colors, style.tint(colors)),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Emoji3d(
                  style.emoji,
                  size: 64,
                  heroTag: activityHeroTag(activity.id),
                ),
                Text(
                  activity.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              AppLocalizations.of(context).zonePickerTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final zone in zones)
                  ListTile(
                    title: Text(zone.name),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    trailing: zone == selected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
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
