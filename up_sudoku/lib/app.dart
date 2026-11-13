import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/game_controller.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'data/puzzle_repository.dart';
import 'ui/screens/home_screen.dart';

/// Root widget of the app.
///
/// The controllers are provided at the root (PLAN.md §13.1); the puzzle pools
/// are loaded before the app starts (see `main.dart`).
class UpSudokuApp extends StatelessWidget {
  const UpSudokuApp({super.key, required this.repository});

  /// The loaded puzzle pools.
  final PuzzleRepository repository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PuzzleRepository>.value(value: repository),
        ChangeNotifierProvider<GameController>(
          create: (_) => GameController(repository: repository),
        ),
      ],
      child: MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
