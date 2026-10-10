import 'package:flutter/material.dart';

/// "Clay" look for a surface of [color]: a soft highlight towards the top
/// left, a thin light rim and a tinted shadow below, so it reads like a
/// rounded, puffy piece of material instead of a flat card.
BoxDecoration clayDecoration(
  ColorScheme colors,
  Color color, {
  double radius = 28,
}) {
  final light = colors.brightness == Brightness.light;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.lerp(color, Colors.white, light ? 0.5 : 0.06)!, color],
    ),
    border: Border.all(
      color: Colors.white.withValues(alpha: light ? 0.75 : 0.06),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: light
            ? Color.lerp(color, colors.onSurface, 0.35)!.withValues(alpha: 0.28)
            : Colors.black.withValues(alpha: 0.45),
        offset: const Offset(0, 12),
        blurRadius: 24,
        spreadRadius: -8,
      ),
    ],
  );
}

/// Wraps a tappable [child] so it reacts to touch in 3D: it sinks a little
/// and tilts towards the finger, then springs back when released.
///
/// It listens to raw pointer events instead of joining the gesture arena,
/// so taps, ink splashes and scrolling keep working on [child].
class Pressable3d extends StatefulWidget {
  const Pressable3d({super.key, required this.child, this.maxTilt = 0.14});

  final Widget child;

  /// Rotation, in radians, when pressing right at an edge.
  final double maxTilt;

  @override
  State<Pressable3d> createState() => _Pressable3dState();
}

class _Pressable3dState extends State<Pressable3d> {
  /// Pointer position relative to the center, from -1 to 1 on each axis.
  Offset _tilt = Offset.zero;
  bool _pressed = false;

  void _press(Offset localPosition) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    setState(() {
      _pressed = true;
      _tilt = Offset(
        (localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (localPosition.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  void _release() {
    if (!_pressed) return;
    setState(() {
      _pressed = false;
      _tilt = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    // Fast ease in while pressing; an elastic curve on release gives the
    // springy wobble.
    final duration = Duration(milliseconds: _pressed ? 140 : 650);
    final curve = _pressed ? Curves.easeOut : Curves.elasticOut;
    return Listener(
      onPointerDown: (event) => _press(event.localPosition),
      onPointerMove: (event) => _press(event.localPosition),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(end: _tilt),
        duration: duration,
        curve: curve,
        builder: (context, tilt, child) => TweenAnimationBuilder<double>(
          tween: Tween(end: _pressed ? 0.96 : 1),
          duration: duration,
          curve: curve,
          builder: (context, scale, child) => Transform(
            alignment: Alignment.center,
            // Entry (3, 2) adds perspective: points further back (positive
            // z) shrink, so the rotations below look three-dimensional.
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateX(tilt.dy * widget.maxTilt)
              ..rotateY(tilt.dx * widget.maxTilt)
              ..scaleByDouble(scale, scale, 1, 1),
            child: child,
          ),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Static pastel glows behind a screen's content, for a warmer background
/// than a flat color.
class PastelBackdrop extends StatelessWidget {
  const PastelBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final alpha = colors.brightness == Brightness.light ? 0.55 : 0.22;
    Widget glow(Color color, double size) => IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
    return ColoredBox(
      color: colors.surface,
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: glow(colors.secondaryContainer, 360),
          ),
          Positioned(
            top: 140,
            left: -160,
            child: glow(colors.primaryContainer, 380),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
