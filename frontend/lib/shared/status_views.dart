import 'dart:async';

import 'package:flutter/material.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/shared/illustration.dart';
import 'package:distance/shared/motion.dart';

/// Loading placeholder: shimmering blocks shaped like a list of cards, so
/// the layout does not jump when the content arrives.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = Column(
      children: [
        for (var i = 0; i < 4; i++) ...[
          Container(
            height: 136,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
    return Semantics(
      label: AppLocalizations.of(context).loading,
      child: ExcludeSemantics(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Shimmer(child: content),
        ),
      ),
    );
  }
}

/// Sweeps a soft highlight across [child] while content loads.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = colors.surfaceContainerHigh;
    final highlight = colors.surfaceContainerLowest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        // srcATop keeps the blocks' shapes and only recolors them.
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-1 + _controller.value * 4 - 1.5, -0.3),
          end: Alignment(_controller.value * 4 - 1.5, 0.3),
          colors: [base, highlight, base],
          stops: const [0.25, 0.5, 0.75],
        ).createShader(bounds),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Centered message with an illustration and an optional action, used for
/// error and empty states.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.illustration,
    required this.title,
    this.message,
    this.action,
  });

  /// Animation or picture shown above the title.
  final Widget illustration;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopIn(child: illustration),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 28), action!],
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MessageView(
      illustration: const LottieIllustration(Illustrations.error),
      title: l10n.errorTitle,
      message: describeError(error, l10n),
      action: FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
    );
  }
}

/// User-facing description of [error]. Server messages already arrive in the
/// app language; errors detected by the app are translated here.
String describeError(Object error, AppLocalizations l10n) => switch (error) {
  ApiException(message: final String message) => message,
  ApiException(kind: ApiErrorKind.connection) => l10n.errorConnection,
  ApiException(kind: ApiErrorKind.timeout) => l10n.errorTimeout,
  _ => l10n.errorUnexpectedResponse,
};

/// The failure behind [error]: `.wait` on a record of futures throws a
/// [ParallelWaitError] wrapping each failure in an [AsyncError]; this
/// returns the first underlying one, or [error] itself.
Object unwrapWaitError(Object error) {
  if (error is! ParallelWaitError) return error;
  final failures = switch (error.errors) {
    (final AsyncError? a, final AsyncError? b) => [a, b],
    (final AsyncError? a, final AsyncError? b, final AsyncError? c) => [
      a,
      b,
      c,
    ],
    _ => const <AsyncError?>[],
  };
  return failures.nonNulls.firstOrNull?.error ?? error;
}

/// Full-screen loading state with an animated illustration, for the first
/// load of the app, when there is no layout yet to sketch with skeletons.
class AnimatedLoadingView extends StatelessWidget {
  const AnimatedLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LottieIllustration(Illustrations.loading, size: 140),
          Text(
            AppLocalizations.of(context).loading,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
