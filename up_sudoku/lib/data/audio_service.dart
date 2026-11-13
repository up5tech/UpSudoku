/// Plays the bundled sound effects.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../core/sound_cue.dart';

/// One preloaded [AudioPlayer] per effect, gated by a single on/off flag
/// (PLAN.md §18).
///
/// Only bundled [AssetSource] files are ever played, so the audio plugin is
/// never used for network playback.
class AudioService {
  AudioService({this.enabled = true});

  /// Asset path of every cue (relative to the `assets/` folder).
  static const Map<SoundCue, String> assets = {
    SoundCue.tap: 'audio/tap.wav',
    SoundCue.place: 'audio/place.wav',
    SoundCue.error: 'audio/error.wav',
    SoundCue.unitComplete: 'audio/unit_complete.wav',
    SoundCue.win: 'audio/win.wav',
    SoundCue.lose: 'audio/lose.wav',
  };

  final Map<SoundCue, AudioPlayer> _players = {};

  /// Whether sound is turned on in the settings.
  bool enabled;

  /// True once [preload] has run (or a cue has already created its player).
  bool get isPreloaded => _players.isNotEmpty;

  /// Loads every effect into memory so the first play has no delay.
  ///
  /// Failures are swallowed: a missing platform plugin (unit tests, desktop
  /// without audio) must never break the game.
  Future<void> preload() async {
    for (final cue in SoundCue.values) {
      try {
        await _playerFor(cue)?.setSource(AssetSource(assets[cue]!));
      } catch (_) {
        // No audio backend available; the game stays silent.
      }
    }
  }

  /// Plays [cue] unless sound is turned off.
  void play(SoundCue cue) {
    if (!enabled) return;
    final player = _playerFor(cue);
    if (player == null) return;
    unawaited(
      Future<void>(() async {
        try {
          // Restart from the beginning so quick repeats still sound.
          await player.stop();
          await player.resume();
        } catch (_) {
          // Ignore playback failures (missing plugin, interrupted audio).
        }
      }),
    );
  }

  /// The player of [cue], or null when the audio backend cannot be created
  /// (unit tests, platforms without an audio plugin).
  AudioPlayer? _playerFor(SoundCue cue) {
    final existing = _players[cue];
    if (existing != null) return existing;
    try {
      return _players[cue] = AudioPlayer();
    } catch (_) {
      return null;
    }
  }

  /// Releases the platform players.
  void dispose() {
    for (final player in _players.values) {
      unawaited(player.dispose());
    }
    _players.clear();
  }
}
