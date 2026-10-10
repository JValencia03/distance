import 'package:flutter/material.dart';

import 'package:distance/data/models.dart';
import 'package:distance/features/avatar/avatar_style.dart';

/// A flat drawing of an avatar: the same colors and accessory as the 3D
/// character, for small places and for devices without 3D.
class AvatarBadge extends StatelessWidget {
  const AvatarBadge({super.key, required this.avatar, this.size = 40});

  final Avatar avatar;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _AvatarPainter(avatar)),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.avatar);

  final Avatar avatar;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final body = Paint()..color = AvatarStyle.bodyColor(avatar.bodyColor);
    final skin = Paint()..color = AvatarStyle.skinTone(avatar.skinTone);
    final dark = Paint()..color = const Color(0xFF2B2B3A);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.22, s * 0.52, s * 0.56, s * 0.46),
        Radius.circular(s * 0.24),
      ),
      body,
    );
    final head = Offset(s * 0.5, s * 0.38);
    canvas.drawCircle(head, s * 0.24, skin);
    final white = Paint()..color = Colors.white;
    for (final x in [-0.08, 0.08]) {
      canvas.drawCircle(head.translate(s * x, s * 0.02), s * 0.045, white);
      canvas.drawCircle(head.translate(s * x, s * 0.025), s * 0.026, dark);
    }

    switch (avatar.accessory) {
      case 'cap':
        final cap = Paint()..color = const Color(0xFFE85D75);
        canvas.drawArc(
          Rect.fromCircle(center: head, radius: s * 0.24),
          3.3,
          2.8,
          true,
          cap,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(s * 0.2, s * 0.22, s * 0.34, s * 0.05),
            Radius.circular(s * 0.03),
          ),
          cap,
        );
      case 'beanie':
        canvas.drawArc(
          Rect.fromCircle(center: head, radius: s * 0.25),
          3.14,
          3.14,
          true,
          Paint()..color = const Color(0xFF5B8DEF),
        );
        canvas.drawCircle(
          Offset(s * 0.5, s * 0.1),
          s * 0.05,
          Paint()..color = Colors.white,
        );
      case 'headphones':
        final band = Paint()
          ..color = const Color(0xFF3A3A4A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.04;
        canvas.drawArc(
          Rect.fromCircle(center: head, radius: s * 0.26),
          3.14,
          3.14,
          false,
          band,
        );
        final cup = Paint()..color = const Color(0xFFFF6F91);
        canvas.drawCircle(head.translate(-s * 0.25, 0), s * 0.06, cup);
        canvas.drawCircle(head.translate(s * 0.25, 0), s * 0.06, cup);
      case 'flower':
        final flower = head.translate(s * 0.15, -s * 0.17);
        final petal = Paint()..color = const Color(0xFFFFB3D1);
        for (final d in const [
          Offset(0, -1),
          Offset(0.95, -0.3),
          Offset(0.6, 0.8),
          Offset(-0.6, 0.8),
          Offset(-0.95, -0.3),
        ]) {
          canvas.drawCircle(flower + d * (s * 0.045), s * 0.035, petal);
        }
        canvas.drawCircle(
          flower,
          s * 0.03,
          Paint()..color = const Color(0xFFFFD166),
        );
      case 'glasses':
        final frame = Paint()
          ..color = const Color(0xFF2B2B3A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.02;
        canvas.drawCircle(head.translate(-s * 0.08, s * 0.02), s * 0.06, frame);
        canvas.drawCircle(head.translate(s * 0.08, s * 0.02), s * 0.06, frame);
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter oldDelegate) =>
      oldDelegate.avatar != avatar;
}
