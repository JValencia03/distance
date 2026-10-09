import 'package:flutter/material.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';
import 'package:distance/features/plans/plan_widgets.dart';
import 'package:distance/shared/activity_icon.dart';
import 'package:distance/shared/formatting.dart';
import 'package:distance/shared/status_views.dart';

/// Shows the latest details of a plan, fetched by id.
class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({super.key, required this.api, required this.planId});

  final DistanceApi api;
  final String planId;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  late Future<Plan> _plan = widget.api.fetchPlan(widget.planId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan')),
      body: FutureBuilder(
        future: _plan,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return MessageView.error(
              error: snapshot.error!,
              onRetry: () => setState(() {
                _plan = widget.api.fetchPlan(widget.planId);
              }),
            );
          }
          return _PlanDetails(plan: snapshot.requireData);
        },
      ),
    );
  }
}

class _PlanDetails extends StatelessWidget {
  const _PlanDetails({required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = plan.description;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(plan.title, style: theme.textTheme.headlineSmall),
            ),
            const SizedBox(width: 8),
            AvailabilityChip(isFull: plan.isFull),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 12),
          Text(description, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: 16),
        _DetailRow(
          icon: activityIcon(plan.activity.id),
          label: 'Actividad',
          value: plan.activity.name,
        ),
        _DetailRow(
          icon: Icons.schedule,
          label: 'Cuándo',
          value: formatPlanDate(plan.startsAt.toLocal(), now: DateTime.now()),
        ),
        _DetailRow(
          icon: Icons.place_outlined,
          label: 'Punto de encuentro',
          value: '${plan.place}, ${plan.zone.name}',
        ),
        _DetailRow(
          icon: Icons.group_outlined,
          label: 'Participantes',
          value: formatParticipants(plan),
        ),
      ],
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(value),
      subtitle: Text(label),
    );
  }
}
