import 'package:flutter/material.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';
import 'package:distance/features/plans/create_plan_screen.dart';
import 'package:distance/features/plans/plan_detail_screen.dart';
import 'package:distance/features/plans/plan_widgets.dart';
import 'package:distance/shared/activity_icon.dart';
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Plan creado')));
    await _reload();
  }

  void _openPlan(Plan plan) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanDetailScreen(api: widget.api, planId: plan.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_activity?.name ?? 'Todos los planes'),
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
        icon: const Icon(Icons.add),
        label: const Text('Crear plan'),
      ),
      body: FutureBuilder(
        future: _plans,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return MessageView.error(error: snapshot.error!, onRetry: _reload);
          }
          final plans = snapshot.requireData;
          if (plans.isEmpty) {
            final what = _activity == null
                ? 'planes'
                : 'planes de ${_activity!.name.toLowerCase()}';
            return MessageView(
              icon: activityIcon(_activity?.id ?? ''),
              title: 'No hay $what cerca de ${widget.zone.name}',
              message: 'Crea uno y deja que otras personas se unan.',
              action: FilledButton(
                onPressed: _createPlan,
                child: const Text('Crear plan'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              // Leaves room so the floating button never covers the last plan.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: plans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => PlanCard(
                plan: plans[index],
                onTap: () => _openPlan(plans[index]),
              ),
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
            label: const Text('Todas'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final activity in activities) ...[
            const SizedBox(width: 8),
            ChoiceChip(
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
