import 'package:flutter/material.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';
import 'package:distance/features/map/map_screen.dart';
import 'package:distance/features/plans/create_plan_screen.dart';
import 'package:distance/features/plans/plan_detail_screen.dart';
import 'package:distance/features/plans/plan_widgets.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/shared/activity_style.dart';
import 'package:distance/shared/clay.dart';
import 'package:distance/shared/emoji.dart';
import 'package:distance/shared/illustration.dart';
import 'package:distance/shared/motion.dart';
import 'package:distance/shared/status_views.dart';

/// Discovers upcoming plans near [zone], optionally filtered by activity.
class PlansScreen extends StatefulWidget {
  const PlansScreen({
    super.key,
    required this.api,
    required this.catalog,
    required this.zone,
    this.initialActivity,
  });

  final DistanceApi api;
  final Catalog catalog;
  final Zone zone;
  final Activity? initialActivity;

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late Activity? _activity = widget.initialActivity;
  late Future<List<Plan>> _plans = _load();

  Future<List<Plan>> _load() =>
      widget.api.fetchPlans(zoneId: widget.zone.id, activityId: _activity?.id);

  Future<void> _reload() {
    final plans = _load();
    setState(() {
      _plans = plans;
    });
    return plans;
  }

  void _selectActivity(Activity? activity) {
    if (activity == _activity) return;
    _activity = activity;
    _reload();
  }

  Future<void> _createPlan() async {
    final created = await Navigator.of(context).push<Plan>(
      MaterialPageRoute(
        builder: (_) => CreatePlanScreen(
          api: widget.api,
          catalog: widget.catalog,
          initialActivity: _activity,
          initialZone: widget.zone,
        ),
      ),
    );
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).planCreated)),
    );
    await _reload();
  }

  Future<void> _openMap() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapScreen(
          api: widget.api,
          catalog: widget.catalog,
          zone: widget.zone,
          initialActivity: _activity,
        ),
      ),
    );
    // Plans may have been joined from the map.
    if (mounted) await _reload();
  }

  Future<void> _openPlan(Plan plan) async {
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
    // The user may have joined, or the plan may have changed meanwhile.
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _Title(activity: _activity, fallback: l10n.allPlans),
        actions: [
          IconButton(
            tooltip: l10n.openMap,
            icon: const Icon(Icons.map_rounded),
            onPressed: _openMap,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _ActivityFilter(
            activities: widget.catalog.activities,
            selected: _activity,
            onSelected: _selectActivity,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createPlan,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.createPlan),
      ),
      body: FutureBuilder(
        future: _plans,
        builder: (context, snapshot) {
          final reloading = snapshot.connectionState != ConnectionState.done;
          // While reloading, the snapshot keeps the previous data: show it
          // with a progress bar instead of blanking the list.
          if (!reloading && snapshot.hasError) {
            return ErrorView(error: snapshot.error!, onRetry: _reload);
          }
          final plans = snapshot.data;
          if (plans == null) return const LoadingView();
          // Always a Stack, so the list keeps its place in the tree (and its
          // scroll position and animations) when the progress bar comes and
          // goes.
          return Stack(
            children: [
              _buildPlans(plans),
              if (reloading) const LinearProgressIndicator(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlans(List<Plan> plans) {
    if (plans.isEmpty) {
      final l10n = AppLocalizations.of(context);
      final activity = _activity;
      return MessageView(
        illustration: const LottieIllustration(Illustrations.empty),
        title: activity == null
            ? l10n.noPlansTitle(widget.zone.name)
            : l10n.noActivityPlansTitle(
                activity.name.toLowerCase(),
                widget.zone.name,
              ),
        message: l10n.noPlansMessage,
        action: FilledButton(
          onPressed: _createPlan,
          child: Text(l10n.createPlan),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        // Leaves room so the floating button never covers the last plan.
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        itemCount: plans.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        // Plans are keyed by id. When a reload moves a plan to another
        // position, this lets the list find it and keep its state, instead
        // of replaying the entrance animation of every plan that moved.
        findItemIndexCallback: (key) {
          final index = plans.indexWhere((plan) => ValueKey(plan.id) == key);
          return index < 0 ? null : index;
        },
        itemBuilder: (context, index) {
          final plan = plans[index];
          return Entrance(
            key: ValueKey(plan.id),
            index: index,
            child: Pressable3d(
              maxTilt: 0.06,
              child: PlanCard(plan: plan, onTap: () => _openPlan(plan)),
            ),
          );
        },
      ),
    );
  }
}

class _ActivityFilter extends StatelessWidget {
  const _ActivityFilter({
    required this.activities,
    required this.selected,
    required this.onSelected,
  });

  final List<Activity> activities;
  final Activity? selected;
  final ValueChanged<Activity?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          ChoiceChip(
            avatar: const Emoji3d(Emojis.sparkles, size: 20),
            label: Text(AppLocalizations.of(context).filterAll),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final activity in activities) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: Emoji3d(ActivityStyle.of(activity.id).emoji, size: 20),
              label: Text(activity.name),
              selected: activity == selected,
              onSelected: (_) => onSelected(activity),
            ),
          ],
        ],
      ),
    );
  }
}

/// App bar title: the activity's emoji, which flies in from the home grid,
/// next to its name.
class _Title extends StatelessWidget {
  const _Title({required this.activity, required this.fallback});

  final Activity? activity;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final activity = this.activity;
    return Row(
      children: [
        if (activity == null)
          const Emoji3d(Emojis.sparkles, size: 34)
        else
          Emoji3d(
            ActivityStyle.of(activity.id).emoji,
            size: 34,
            heroTag: activityHeroTag(activity.id),
          ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            activity?.name ?? fallback,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
