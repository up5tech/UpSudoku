/// The timer shown in the game top bar.
///
/// It listens to its own [ValueNotifier] so the board is not rebuilt every
/// second.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Elapsed-time display in `mm:ss` (or `h:mm:ss` for long games).
class GameTimer extends StatelessWidget {
  const GameTimer({super.key, required this.elapsed});

  /// Notifier with the elapsed seconds.
  final ValueListenable<int> elapsed;

  /// Formats [seconds] as `mm:ss` or `h:mm:ss`.
  static String format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: elapsed,
      builder: (context, value, _) {
        return Semantics(
          label: 'Elapsed time ${format(value)}',
          child: Text(
            format(value),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        );
      },
    );
  }
}
