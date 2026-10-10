import 'package:flutter/material.dart';

import 'package:distance/data/models.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/shared/activity_style.dart';
import 'package:distance/shared/clay.dart';
import 'package:distance/shared/emoji.dart';
import 'package:distance/shared/formatting.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.onTap});

  final Plan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = ActivityStyle.of(plan.activity.id);
    return DecoratedBox(
      decoration: clayDecoration(colors, colors.surfaceContainerLowest),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EmojiBadge(
                  emoji: style.emoji,
                  color: style.tint(colors),
                  heroTag: planHeroTag(plan.id),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.activity.name,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          AvailabilityChip(plan: plan),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 19,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _InfoLine(
                        icon: Icons.schedule_rounded,
                        text: formatPlanSchedule(
                          plan,
                          now: DateTime.now(),
                          l10n: l10n,
                        ),
                        strong: true,
                      ),
                      _InfoLine(
                        icon: Icons.place_outlined,
                        text: [
                          '${plan.place}, ${plan.zone.name}',
                          if (plan.distanceKm != null)
                            formatDistance(plan.distanceKm!, l10n),
                        ].join(' · '),
                      ),
                      _InfoLine(
                        icon: Icons.group_outlined,
                        text: formatParticipants(plan, l10n),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 3D emoji sitting on a rounded pastel tile.
class EmojiBadge extends StatelessWidget {
  const EmojiBadge({
    super.key,
    required this.emoji,
    required this.color,
    this.size = 64,
    this.heroTag,
  });

  final String emoji;
  final Color color;
  final double size;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: clayDecoration(
        Theme.of(context).colorScheme,
        color,
        radius: size * 0.32,
      ),
      child: Emoji3d(emoji, size: size * 0.7, heroTag: heroTag),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    this.strong = false,
  });

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = strong
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: strong ? FontWeight.w700 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Short label of the plan's state for the current user.
class AvailabilityChip extends StatelessWidget {
  const AvailabilityChip({super.key, required this.plan});

  final Plan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    // Mint invites to join, coral says it is happening right now, lavender
    // confirms the user is in; the rest are neutral.
    final (label, background, foreground) = switch (plan.joinAvailability(
      now,
    )) {
      JoinAvailability.available when plan.isOngoingAt(now) => (
        l10n.chipOngoing,
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      JoinAvailability.available => (
        l10n.chipAvailable,
        colors.tertiaryContainer,
        colors.onTertiaryContainer,
      ),
      JoinAvailability.joined => (
        l10n.chipJoined,
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      JoinAvailability.full => (
        l10n.chipFull,
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
      JoinAvailability.cancelled => (
        l10n.chipCancelled,
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
      JoinAvailability.ended => (
        l10n.chipEnded,
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: foreground),
      ),
    );
  }
}
