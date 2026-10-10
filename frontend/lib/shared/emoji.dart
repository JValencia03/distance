import 'package:flutter/material.dart';

/// 3D emoji assets (Microsoft Fluent Emoji) used outside the activity
/// catalog.
abstract final class Emojis {
  static const calendar = 'assets/emoji/event.png';
  static const pin = 'assets/emoji/pin.png';
  static const party = 'assets/emoji/party.png';
  static const cloud = 'assets/emoji/cloud.png';
  static const sparkles = 'assets/emoji/sparkles.png';
}

/// A decorative 3D emoji. It is hidden from screen readers: the text next to
/// it always carries the meaning.
class Emoji3d extends StatelessWidget {
  const Emoji3d(this.asset, {super.key, this.size = 48, this.heroTag});

  final String asset;
  final double size;

  /// When set, the emoji flies to the emoji with the same tag on the next
  /// screen.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      width: size,
      height: size,
      excludeFromSemantics: true,
      // The 256 px source stays sharp at every size used in the app.
      filterQuality: FilterQuality.medium,
    );
    final tag = heroTag;
    return tag == null ? image : Hero(tag: tag, child: image);
  }
}
