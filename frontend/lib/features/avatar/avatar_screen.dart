import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:distance/data/distance_api.dart';
import 'package:distance/data/models.dart';
import 'package:distance/features/avatar/avatar_style.dart';
import 'package:distance/features/avatar/character_preview.dart';
import 'package:distance/l10n/app_localizations.dart';
import 'package:distance/shared/clay.dart';
import 'package:distance/shared/status_views.dart';

/// Lets the user customize the character others see on the plans map.
class AvatarScreen extends StatefulWidget {
  const AvatarScreen({super.key, required this.api});

  final DistanceApi api;

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  AvatarOptions? _options;
  Avatar? _saved;
  Avatar? _editing;
  bool _isDefault = false;
  Object? _loadError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final (options, profile) = await (
        widget.api.fetchAvatarOptions(),
        widget.api.fetchMyAvatar(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _options = options;
        _saved = profile.avatar;
        _editing = profile.avatar;
        _isDefault = profile.isDefault;
      });
    } catch (error) {
      if (!mounted) return;
      // `.wait` wraps the failure of either request.
      setState(
        () => _loadError = error is ParallelWaitError
            ? (error.errors.$1 ?? error.errors.$2)
            : error,
      );
    }
  }

  /// Saving is offered for a changed avatar, and for a default one, so the
  /// user can keep it as their own.
  bool get _canSave => !_saving && (_isDefault || _editing != _saved);

  Future<void> _save() async {
    final avatar = _editing;
    if (avatar == null || !_canSave) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);
    try {
      final profile = await widget.api.saveMyAvatar(avatar);
      if (!mounted) return;
      setState(() {
        _saved = profile.avatar;
        _editing = profile.avatar;
        _isDefault = profile.isDefault;
      });
      HapticFeedback.lightImpact();
      _showMessage(l10n.avatarSaved);
    } on ApiException catch (error) {
      if (mounted) _showMessage(describeError(error, l10n));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _edit(Avatar Function(Avatar) change) =>
      setState(() => _editing = change(_editing!));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = _options;
    final avatar = _editing;
    final Widget body;
    if (options != null && avatar != null) {
      body = _Editor(
        options: options,
        avatar: avatar,
        isDefault: _isDefault,
        onChanged: _edit,
      );
    } else if (_loadError != null) {
      body = ErrorView(error: _loadError!, onRetry: _load);
    } else {
      body = const LoadingView();
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.avatarTitle)),
      body: body,
      bottomNavigationBar: avatar == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.avatarSave),
                ),
              ),
            ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({
    required this.options,
    required this.avatar,
    required this.isDefault,
    required this.onChanged,
  });

  final AvatarOptions options;
  final Avatar avatar;
  final bool isDefault;
  final void Function(Avatar Function(Avatar)) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          height: 300,
          decoration: clayDecoration(
            colors,
            colors.primaryContainer,
            radius: 32,
          ),
          clipBehavior: Clip.antiAlias,
          child: CharacterPreview(avatar: avatar),
        ),
        const SizedBox(height: 12),
        Text(
          isDefault ? l10n.avatarDefaultHint : l10n.avatarSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        if (options.skins.length > 1) ...[
          _SectionTitle(l10n.avatarSkin),
          _Choices(
            options: options.skins,
            selected: avatar.skin,
            onSelected: (id) => onChanged((a) => a.copyWith(skin: id)),
          ),
        ],
        _SectionTitle(l10n.avatarBodyColor),
        _Swatches(
          ids: options.bodyColors,
          selected: avatar.bodyColor,
          colorOf: AvatarStyle.bodyColor,
          nameOf: (id) => AvatarStyle.bodyColorName(id, l10n),
          onSelected: (id) => onChanged((a) => a.copyWith(bodyColor: id)),
        ),
        _SectionTitle(l10n.avatarSkinTone),
        _Swatches(
          ids: options.skinTones,
          selected: avatar.skinTone,
          colorOf: AvatarStyle.skinTone,
          nameOf: (id) => AvatarStyle.skinToneName(id, l10n),
          onSelected: (id) => onChanged((a) => a.copyWith(skinTone: id)),
        ),
        _SectionTitle(l10n.avatarAccessory),
        _Choices(
          options: options.accessories,
          selected: avatar.accessory,
          onSelected: (id) => onChanged((a) => a.copyWith(accessory: id)),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Choices extends StatelessWidget {
  const _Choices({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<AvatarOption> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final option in options)
        ChoiceChip(
          label: Text(option.name),
          selected: option.id == selected,
          onSelected: (_) => onSelected(option.id),
        ),
    ],
  );
}

/// Round color buttons; the selected one gets a ring and a check mark.
class _Swatches extends StatelessWidget {
  const _Swatches({
    required this.ids,
    required this.selected,
    required this.colorOf,
    required this.nameOf,
    required this.onSelected,
  });

  final List<String> ids;
  final String selected;
  final Color Function(String) colorOf;
  final String Function(String) nameOf;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final id in ids)
          Semantics(
            label: nameOf(id),
            selected: id == selected,
            button: true,
            child: Tooltip(
              message: nameOf(id),
              excludeFromSemantics: true,
              child: InkResponse(
                onTap: () => onSelected(id),
                radius: 28,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorOf(id),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: id == selected
                          ? colors.primary
                          : colors.outlineVariant,
                      width: id == selected ? 3 : 1,
                    ),
                  ),
                  child: id == selected
                      ? Icon(
                          Icons.check_rounded,
                          color: colorOf(id).computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white,
                        )
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
