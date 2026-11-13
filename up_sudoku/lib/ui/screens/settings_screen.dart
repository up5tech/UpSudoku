/// Sound, haptics, theme, highlighting and data reset.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../controllers/stats_controller.dart';
import '../../data/storage_service.dart';
import '../../domain/models/settings.dart';

/// Settings screen (PLAN.md §14.2).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _resetData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset data?'),
        content: const Text(
          'This clears statistics, saved games and the daily streak. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
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
    ).showSnackBar(const SnackBar(content: Text('All data cleared.')));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Sound & feedback'),
          SwitchListTile(
            title: const Text('Sound effects'),
            subtitle: const Text('Tap, place, error and win sounds'),
            value: settings.sound,
            onChanged: settings.setSound,
          ),
          SwitchListTile(
            title: const Text('Haptics'),
            subtitle: const Text('Vibrate on placement and mistakes'),
            value: settings.haptics,
            onChanged: settings.setHaptics,
          ),
          const Divider(),
          const _SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<ThemePreference>(
              segments: const [
                ButtonSegment(
                  value: ThemePreference.system,
                  label: Text('System'),
                ),
                ButtonSegment(value: ThemePreference.light, label: Text('Light')),
                ButtonSegment(value: ThemePreference.dark, label: Text('Dark')),
              ],
              selected: {settings.settings.theme},
              onSelectionChanged: (selection) =>
                  settings.setTheme(selection.first),
            ),
          ),
          SwitchListTile(
            title: const Text('Large digits'),
            subtitle: const Text('Bigger digits and notes on the board'),
            value: settings.largeDigits,
            onChanged: settings.setLargeDigits,
          ),
          const Divider(),
          const _SectionHeader('Board highlighting'),
          SwitchListTile(
            title: const Text('Highlight peers'),
            subtitle: const Text('Tint the row, column and box of the cell'),
            value: settings.highlightPeers,
            onChanged: settings.setHighlightPeers,
          ),
          SwitchListTile(
            title: const Text('Highlight same digit'),
            subtitle: const Text('Tint the other cells holding that digit'),
            value: settings.highlightSameDigit,
            onChanged: settings.setHighlightSameDigit,
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('Reset data'),
            subtitle: const Text('Statistics, saved games and daily streak'),
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
