import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:distance/shared/clay.dart';
import 'package:distance/shared/motion.dart';

/// Animated background: pastel glows drifting slowly behind [child], drawn
/// by the `shaders/aurora.frag` fragment shader on the GPU.
///
/// Until the shader loads (or if it cannot), it shows the static
/// [PastelBackdrop]. The animation pauses whenever its route is covered by
/// another one, and stays still when the device asks to reduce motion.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});

  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  /// Compiled once and shared by every instance.
  static final Future<ui.FragmentProgram> _program =
      ui.FragmentProgram.fromAsset('shaders/aurora.frag');

  ui.FragmentShader? _shader;

  /// Seconds since the animation started; repaints the shader on change.
  final _time = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _time.value = elapsed.inMicroseconds / 1e6,
  );

  @override
  void initState() {
    super.initState();
    _program.then(
      (program) {
        if (mounted) setState(() => _shader = program.fragmentShader());
      },
      onError: (Object error) {
        // Keep the static backdrop; the screen works the same without it.
        debugPrint('Aurora shader unavailable: $error');
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        AmbientMotion.enabled && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) return PastelBackdrop(child: widget.child);
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _AuroraPainter(
                shader: shader,
                time: _time,
                base: colors.surface,
                glowA: colors.secondaryContainer,
                glowB: colors.primaryContainer,
                glowC: colors.tertiaryContainer,
                strength: colors.brightness == Brightness.light ? 0.75 : 0.35,
              ),
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.shader,
    required this.time,
    required this.base,
    required this.glowA,
    required this.glowB,
    required this.glowC,
    required this.strength,
  }) : super(repaint: time);

  final ui.FragmentShader shader;
  final ValueNotifier<double> time;
  final Color base;
  final Color glowA;
  final Color glowB;
  final Color glowC;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    var index = 0;
    void setFloat(double value) => shader.setFloat(index++, value);
    void setColor(Color color) => [color.r, color.g, color.b].forEach(setFloat);

    // Same order as the uniforms declared in aurora.frag.
    setFloat(size.width);
    setFloat(size.height);
    setFloat(time.value);
    setColor(base);
    setColor(glowA);
    setColor(glowB);
    setColor(glowC);
    setFloat(strength);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) =>
      oldDelegate.shader != shader ||
      oldDelegate.base != base ||
      oldDelegate.glowA != glowA ||
      oldDelegate.glowB != glowB ||
      oldDelegate.glowC != glowC ||
      oldDelegate.strength != strength;
}
