import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_sudoku/app.dart';
import 'package:up_sudoku/controllers/game_controller.dart';
import 'package:up_sudoku/core/sound_cue.dart';
import 'package:up_sudoku/data/audio_service.dart';
import 'package:up_sudoku/data/puzzle_repository.dart';
import 'package:up_sudoku/data/storage_service.dart';
import 'package:up_sudoku/ui/screens/game_screen.dart';
import 'package:up_sudoku/ui/widgets/sudoku_board.dart';

/// Records the cues the game asks for instead of touching the audio plugin.
class _SpyAudioService extends AudioService {
  _SpyAudioService() : super(enabled: true);

  final List<SoundCue> played = <SoundCue>[];

  @override
  void play(SoundCue cue) => played.add(cue);
}

void main() {
  testWidgets('a tap and a placement play one cue each', (tester) async {
    final repository = PuzzleRepository();
    await repository.load();

    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    final audio = _SpyAudioService();

    await tester.pumpWidget(
      UpSudokuApp(
        repository: repository,
        storage: storage,
        audio: audio,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Play').first);
    await tester.pumpAndSettle();

    final game = Provider.of<GameController>(
      tester.element(find.byType(GameScreen)),
      listen: false,
    );
    expect(audio.played, isEmpty, reason: 'starting a game is silent');

    final empty = List<int>.generate(81, (i) => i)
        .firstWhere((i) => game.values[i] == 0);
    final board = tester.getRect(
      find
          .descendant(
            of: find.byType(SudokuBoard),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    final cell = board.width / 9;
    await tester.tapAt(
      Offset(
        board.left + (empty % 9 + 0.5) * cell,
        board.top + (empty ~/ 9 + 0.5) * cell,
      ),
    );
    await tester.pump();

    expect(audio.played, [SoundCue.tap]);

    await tester.tap(find.byKey(ValueKey('digit-${game.entry.solution[empty]}')));
    await tester.pump();

    expect(audio.played, [SoundCue.tap, SoundCue.place]);
  });
}
