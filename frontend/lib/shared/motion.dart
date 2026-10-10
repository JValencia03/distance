import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Switch for ambient animations: the ones that loop for as long as they
/// are on screen, such as the home background or the illustrations of empty
/// states. When off, they show a still frame or play once.
///
/// Tests turn it off (see `test/flutter_test_config.dart`): an animation
/// that never ends never lets `pumpAndSettle` settle.
abstract final class AmbientMotion {
  static bool enabled = true;
}

/// Fades and slides [child] in when it first appears. Items of a list pass
/// their [index] so they arrive one after another.
///
/// Animations are skipped when the device asks to reduce motion.
class Entrance extends StatefulWidget {
  const Entrance({super.key, this.index = 0, required this.child});

  final int index;
  final Widget child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  static const _step = Duration(milliseconds: 60);
  static const _travel = Duration(milliseconds: 450);

  late final AnimationController _controller;
  late final Animation<double> _progress;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // The delay is part of the animation (an Interval) rather than a timer,
    // so nothing is left pending if the widget goes away early. Capped so
    // items far down the list do not wait too long.
    final delay = _step * math.min(widget.index, 8);
    final total = delay + _travel;
    _controller = AnimationController(vsync: this, duration: total);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _progress,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(_progress),
        child: widget.child,
      ),
    );
  }
}

/// Scales [child] up with a springy overshoot when it first appears, for
/// illustrations and celebrations.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0.4, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

/// A one-shot burst of pastel confetti rising from the bottom center of the
/// area it fills. Give it a new key to play it again. It ignores pointers,
/// so it can be stacked over interactive content.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, required this.colors});

  final List<Color> colors;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    // Fixed seed: the same pleasant spread every time, and deterministic in
    // tests.
    final random = math.Random(7);
    _particles = List.generate(56, (i) {
      // Mostly upwards, within ±60° of vertical.
      final angle = -math.pi / 2 + (random.nextDouble() - 0.5) * 2.1;
      final speed = 520 + random.nextDouble() * 620;
      return _Particle(
        velocity: Offset(math.cos(angle), math.sin(angle)) * speed,
        color: widget.colors[i % widget.colors.length],
        size: 7 + random.nextDouble() * 7,
        spin: (random.nextDouble() - 0.5) * 14,
        round: random.nextBool(),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controller.isAnimating && _controller.value == 0) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ConfettiPainter(_controller, _particles),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.velocity,
    required this.color,
    required this.size,
    required this.spin,
    required this.round,
  });

  /// Initial velocity in logical pixels per second.
  final Offset velocity;
  final Color color;
  final double size;

  /// Rotation speed in radians per second.
  final double spin;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  // Passing the animation as `repaint` repaints on every tick without
  // rebuilding any widget.
  _ConfettiPainter(this.animation, this.particles) : super(repaint: animation);

  final Animation<double> animation;
  final List<_Particle> particles;

  static const _gravity = 1500.0;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    if (progress == 0 || progress == 1) return;
    final seconds = progress * 1.6;
    // Fully visible for the first half, then fades out.
    final opacity = (1 - (progress - 0.5) * 2).clamp(0.0, 1.0);
    final origin = Offset(size.width / 2, size.height);
    final paint = Paint();
    for (final particle in particles) {
      final position =
          origin +
          particle.velocity * seconds +
          Offset(0, 0.5 * _gravity * seconds * seconds);
      paint.color = particle.color.withValues(alpha: opacity);
      canvas
        ..save()
        ..translate(position.dx, position.dy)
        ..rotate(particle.spin * seconds);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: particle.size,
        height: particle.round ? particle.size : particle.size * 0.55,
      );
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(particle.size / 2)),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.particles != particles;
}
