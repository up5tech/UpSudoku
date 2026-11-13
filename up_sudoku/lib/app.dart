import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/game_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/stats_controller.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'data/puzzle_repository.dart';
import 'data/storage_service.dart';
import 'ui/screens/home_screen.dart';

/// Root widget of the app.
///
/// The controllers are provided at the root (PLAN.md §13.1); the puzzle pools
/// are loaded before the app starts (see `main.dart`).
class UpSudokuApp extends StatefulWidget {
  const UpSudokuApp({
    super.key,
    required this.repository,
    required this.storage,
  });

  /// The loaded puzzle pools.
  final PuzzleRepository repository;

  /// Local persistence (shared_preferences).
  final StorageService storage;

  @override
  State<UpSudokuApp> createState() => _UpSudokuAppState();
}

class _UpSudokuAppState extends State<UpSudokuApp> with WidgetsBindingObserver {
  late final SettingsController _settings;
  late final StatsController _stats;
  late final GameController _game;

  @override
  void initState() {
    super.initState();
    _settings = SettingsController(storage: widget.storage);
    _stats = StatsController(storage: widget.storage);
    _game = GameController(
      repository: widget.repository,
      storage: widget.storage,
      stats: _stats,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _game.dispose();
    _stats.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding pauses the game (which also autosaves), so the timer never
    // keeps running while the app is hidden and the board is not shown.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_game.hasGame && _game.isPlaying) _game.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PuzzleRepository>.value(value: widget.repository),
        Provider<StorageService>.value(value: widget.storage),
        ChangeNotifierProvider<SettingsController>.value(value: _settings),
        ChangeNotifierProvider<StatsController>.value(value: _stats),
        ChangeNotifierProvider<GameController>.value(value: _game),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: settings.themeMode,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
