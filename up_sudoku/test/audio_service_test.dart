import 'package:flutter_test/flutter_test.dart';
import 'package:up_sudoku/core/sound_cue.dart';
import 'package:up_sudoku/data/audio_service.dart';

void main() {
  test('every cue maps to a distinct bundled asset', () {
    expect(AudioService.assets.keys.toSet(), SoundCue.values.toSet());
    expect(
      AudioService.assets.values.toSet().length,
      SoundCue.values.length,
      reason: 'two cues must not share a file',
    );
    for (final path in AudioService.assets.values) {
      expect(path, startsWith('audio/'));
      expect(path, endsWith('.wav'));
    }
  });

  test('turning sound off keeps every player unloaded', () {
    final audio = AudioService(enabled: false);

    for (final cue in SoundCue.values) {
      audio.play(cue);
    }

    expect(audio.enabled, isFalse);
    expect(audio.isPreloaded, isFalse);
    audio.dispose();
  });

  test('the on/off flag follows the setting', () {
    final audio = AudioService();
    expect(audio.enabled, isTrue);

    audio.enabled = false;
    expect(audio.enabled, isFalse);

    audio.enabled = true;
    expect(audio.enabled, isTrue);
    audio.dispose();
  });
}
