import 'package:flutter/painting.dart';

import 'package:distance/l10n/app_localizations.dart';

/// How avatar ids from the server catalog are drawn. Unknown ids get neutral
/// fallbacks, so options added on the server still render.
abstract final class AvatarStyle {
  static const _bodyColors = {
    'coral': Color(0xFFFF8A80),
    'mint': Color(0xFF7FD8BE),
    'lavender': Color(0xFFB39DDB),
    'sky': Color(0xFF81C7F5),
    'sunflower': Color(0xFFFFD166),
    'peach': Color(0xFFFFB38A),
    'forest': Color(0xFF4F9D69),
    'charcoal': Color(0xFF4A4E69),
  };

  static const _skinTones = {
    'tone1': Color(0xFFFDE3CF),
    'tone2': Color(0xFFF3C9A4),
    'tone3': Color(0xFFE0A878),
    'tone4': Color(0xFFC68642),
    'tone5': Color(0xFF8D5524),
    'tone6': Color(0xFF5C3A1E),
  };

  static Color bodyColor(String id) =>
      _bodyColors[id] ?? const Color(0xFFB0B0C0);

  static Color skinTone(String id) => _skinTones[id] ?? const Color(0xFFE0A878);

  /// Name of a body color for screen readers and tooltips.
  static String bodyColorName(String id, AppLocalizations l10n) => switch (id) {
    'coral' => l10n.colorCoral,
    'mint' => l10n.colorMint,
    'lavender' => l10n.colorLavender,
    'sky' => l10n.colorSky,
    'sunflower' => l10n.colorSunflower,
    'peach' => l10n.colorPeach,
    'forest' => l10n.colorForest,
    'charcoal' => l10n.colorCharcoal,
    _ => id,
  };

  /// "Tono 3" for `tone3`; skin tones are ordered from light to dark.
  static String skinToneName(String id, AppLocalizations l10n) {
    final number = int.tryParse(id.replaceFirst('tone', ''));
    return number == null ? id : l10n.skinToneName(number);
  }
}
