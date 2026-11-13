import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_sudoku/app.dart';
import 'package:up_sudoku/controllers/game_controller.dart';
import 'package:up_sudoku/data/puzzle_repository.dart';
import 'package:up_sudoku/data/storage_service.dart';
import 'package:up_sudoku/domain/models/settings.dart';
import 'package:up_sudoku/ui/screens/game_screen.dart';
import 'package:up_sudoku/ui/screens/how_to_play_screen.dart';
import 'package:up_sudoku/ui/screens/settings_screen.dart';
import 'package:up_sudoku/ui/screens/stats_screen.dart';
import 'package:up_sudoku/ui/widgets/hint_panel.dart';
import 'package:up_sudoku/ui/widgets/number_pad.dart';
import 'package:up_sudoku/ui/widgets/sudoku_board.dart';

/// Test fonts are a fixed-width placeholder by default; loading the real ones
/// measures the same text the player sees.
Future<void> _loadAppFonts() async {
  final loader = FontLoader('Baloo2');
  for (final path in [
    'assets/fonts/Baloo2-Regular.ttf',
    'assets/fonts/Baloo2-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Vietnamese strings are the longest ones the app ships, so they are the
/// useful worst case for a small phone.
void main() {
  setUpAll(_loadAppFonts);

  testWidgets('every Vietnamese screen fits a 320x568 phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = PuzzleRepository();
    await repository.load();
    SharedPreferences.setMockInitialValues({
      'settings_v1': jsonEncode(
        const Settings(language: AppLanguage.vietnamese).toJson(),
      ),
    });
    final storage = await StorageService.create();

    await tester.pumpWidget(
      UpSudokuApp(repository: repository, storage: storage),
    );
    await tester.pumpAndSettle();
    // A render overflow would have been thrown while laying the screen out.
    expect(tester.takeException(), isNull, reason: 'home');

    await tester.tap(find.byTooltip('Thống kê'));
    await tester.pumpAndSettle();
    expect(find.byType(StatsScreen), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'stats');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cách chơi'));
    await tester.pumpAndSettle();
    expect(find.byType(HowToPlayScreen), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'how to play');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cài đặt'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'settings');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Chơi').first);
    // Bounded pumps: the running game rebuilds its timer every second, so
    // pumpAndSettle would never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GameScreen), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'game');

    // Short screens give the space to the board instead of the pad.
    final pad = tester.getSize(find.byType(NumberPad));
    expect(pad.height, lessThan(210));
    expect(pad.height, greaterThanOrEqualTo(140));

    // A normal phone keeps the pad exactly as designed.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull, reason: 'normal phone');
    expect(tester.getSize(find.byType(NumberPad)).height, 210);

    // Landscape, tablet and large system fonts: the board must keep a usable
    // square and nothing may overflow or leave the screen.
    Future<void> checkGameAt(
      String reason,
      Size size, {
      double textScale = 1.0,
      required double minBoard,
      double? maxGutter,
    }) async {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      await tester.binding.setSurfaceSize(size);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: reason);

      final box = tester.getSize(find.byType(SudokuBoard));
      final side = math.min(box.width, box.height);
      expect(side, greaterThanOrEqualTo(minBoard), reason: reason);
      // A wide pane that is much wider than the square board would leave empty
      // gutters either side of it instead of giving the width to the controls.
      if (maxGutter != null) {
        expect(
          box.width - side,
          lessThanOrEqualTo(maxGutter),
          reason: '$reason (gutter)',
        );
      }

      final pad = tester.getRect(find.byType(NumberPad));
      expect(pad.left, greaterThanOrEqualTo(0), reason: reason);
      expect(pad.right, lessThanOrEqualTo(size.width + 0.01), reason: reason);
      expect(pad.bottom, lessThanOrEqualTo(size.height + 0.01), reason: reason);
      expect(pad.height, greaterThan(60), reason: reason);
    }

    /// The hint panel is the tallest thing that can appear above the board, so
    /// it is the real worst case for the two-pane layout.
    Future<void> checkHintAt(
      String reason,
      Size size, {
      double textScale = 1.0,
      required double minBoard,
      required double minPad,
    }) async {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      await tester.binding.setSurfaceSize(size);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(GameScreen));
      final game = Provider.of<GameController>(context, listen: false);
      game.requestHint();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HintPanel), findsOneWidget, reason: reason);
      expect(tester.takeException(), isNull, reason: reason);

      final box = tester.getSize(find.byType(SudokuBoard));
      final side = math.min(box.width, box.height);
      expect(side, greaterThanOrEqualTo(minBoard), reason: reason);

      final panel = tester.getRect(find.byType(HintPanel));
      expect(panel.height, greaterThan(40), reason: reason);
      expect(panel.right, lessThanOrEqualTo(size.width + 0.01), reason: reason);

      final pad = tester.getRect(find.byType(NumberPad));
      expect(pad.height, greaterThanOrEqualTo(minPad), reason: reason);
      expect(pad.bottom, lessThanOrEqualTo(size.height + 0.01), reason: reason);

      game.closeHint();
      await tester.pump();
    }

    await checkGameAt(
      '390x844 at 2x text',
      const Size(390, 844),
      textScale: 2,
      minBoard: 220,
    );
    await checkGameAt(
      '320x568 at 1.5x text',
      const Size(320, 568),
      textScale: 1.5,
      minBoard: 150,
    );
    await checkGameAt(
      'landscape phone 844x390',
      const Size(844, 390),
      minBoard: 240,
      maxGutter: 24,
    );
    await checkGameAt(
      'landscape phone 844x390 at 2x text',
      const Size(844, 390),
      textScale: 2,
      minBoard: 200,
      maxGutter: 24,
    );
    await checkHintAt(
      'landscape phone 844x390 with a hint',
      const Size(844, 390),
      minBoard: 200,
      minPad: 200,
    );
    // At 2x text the status row and the hint together use ~130 px of a 334 px
    // body, so the pad lands at ~186 px: three rows of ~58 px, still above the
    // 48 px touch target, while the board keeps its full height.
    await checkHintAt(
      'landscape phone 844x390 with a hint at 2x text',
      const Size(844, 390),
      textScale: 2,
      minBoard: 180,
      minPad: 180,
    );
    await checkGameAt(
      'tablet 1024x768',
      const Size(1024, 768),
      minBoard: 400,
      maxGutter: 24,
    );
    await checkGameAt(
      'tablet portrait 768x1024 at 2x text',
      const Size(768, 1024),
      textScale: 2,
      minBoard: 300,
    );

    // Back to the default text scale: the phone layout is unchanged.
    tester.platformDispatcher.clearAllTestValues();
    await checkGameAt(
      'phone again',
      const Size(320, 568),
      minBoard: 180,
    );
    expect(tester.getSize(find.byType(NumberPad)).height, lessThan(210));
  });
}
