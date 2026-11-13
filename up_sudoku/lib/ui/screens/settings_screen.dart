/// Sound, haptics, theme, language, highlighting and data reset.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../controllers/stats_controller.dart';
import '../../data/storage_service.dart';
import '../../domain/models/settings.dart';
import '../../l10n/app_localizations.dart';

/// Settings screen (PLAN.md §14.2).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _resetData(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.resetDataTitle),
        content: Text(l10n.resetDataBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.reset),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final storage = context.read<StorageService>();
    final stats = context.read<StatsController>();
    final settings = context.read<SettingsController>();
    await storage.clearAll();
    stats.reset();
    settings.reset();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.allDataCleared)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          _SectionHeader(l10n.soundAndFeedback),
          SwitchListTile(
            title: Text(l10n.soundEffects),
            subtitle: Text(l10n.soundEffectsSubtitle),
            value: settings.sound,
            onChanged: settings.setSound,
          ),
          SwitchListTile(
            title: Text(l10n.haptics),
            subtitle: Text(l10n.hapticsSubtitle),
            value: settings.haptics,
            onChanged: settings.setHaptics,
          ),
          const Divider(),
          _SectionHeader(l10n.appearance),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<ThemePreference>(
              // The tick costs the width that "Hệ thống" needs on small phones.
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemePreference.system,
                  label: Text(l10n.themeSystem),
                ),
                ButtonSegment(
                  value: ThemePreference.light,
                  label: Text(l10n.themeLight),
                ),
                ButtonSegment(
                  value: ThemePreference.dark,
                  label: Text(l10n.themeDark),
                ),
              ],
              selected: {settings.settings.theme},
              onSelectionChanged: (selection) =>
                  settings.setTheme(selection.first),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.largeDigits),
            subtitle: Text(l10n.largeDigitsSubtitle),
            value: settings.largeDigits,
            onChanged: settings.setLargeDigits,
          ),
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(l10n.language),
            trailing: DropdownButton<AppLanguage>(
              underline: const SizedBox.shrink(),
              value: settings.language,
              onChanged: (value) {
                if (value != null) settings.setLanguage(value);
              },
              items: [
                for (final language in AppLanguage.values)
                  DropdownMenuItem(
                    value: language,
                    child: Text(l10n.languageName(language)),
                  ),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.boardHighlighting),
          SwitchListTile(
            title: Text(l10n.highlightPeers),
            subtitle: Text(l10n.highlightPeersSubtitle),
            value: settings.highlightPeers,
            onChanged: settings.setHighlightPeers,
          ),
          SwitchListTile(
            title: Text(l10n.highlightSameDigit),
            subtitle: Text(l10n.highlightSameDigitSubtitle),
            value: settings.highlightSameDigit,
            onChanged: settings.setHighlightSameDigit,
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(l10n.resetData),
            subtitle: Text(l10n.resetDataSubtitle),
            onTap: () => _resetData(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
