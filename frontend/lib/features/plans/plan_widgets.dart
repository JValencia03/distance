import 'package:flutter/material.dart';

import 'package:distance/data/models.dart';
import 'package:distance/shared/activity_icon.dart';
import 'package:distance/shared/formatting.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.onTap});

  final Plan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(activityIcon(plan.activity.id), size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(plan.activity.name, style: muted)),
                  AvailabilityChip(isFull: plan.isFull),
                ],
              ),
              const SizedBox(height: 8),
              Text(plan.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                formatPlanDate(plan.startsAt.toLocal(), now: DateTime.now()),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  '${plan.place}, ${plan.zone.name}',
                  if (plan.distanceKm != null) formatDistance(plan.distanceKm!),
                ].join(' · '),
                style: muted,
              ),
              const SizedBox(height: 4),
              Text(formatParticipants(plan), style: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class AvailabilityChip extends StatelessWidget {
  const AvailabilityChip({super.key, required this.isFull});

  final bool isFull;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isFull
            ? colors.surfaceContainerHighest
            : colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isFull ? 'Completo' : 'Disponible',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isFull ? colors.onSurfaceVariant : colors.onPrimaryContainer,
        ),
      ),
    );
  }
}
