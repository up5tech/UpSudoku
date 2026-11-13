import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'controllers/game_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/stats_controller.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'data/audio_service.dart';
import 'data/puzzle_repository.dart';
import 'data/storage_service.dart';
import 'l10n/app_localizations.dart';
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
    this.audio,
  });

  /// The loaded puzzle pools.
  final PuzzleRepository repository;

  /// Local persistence (shared_preferences).
  final StorageService storage;

  /// The sound service; created (and preloaded) by the app when omitted.
  final AudioService? audio;

  @override
  State<UpSudokuApp> createState() => _UpSudokuAppState();
}

class _UpSudokuAppState extends State<UpSudokuApp> with WidgetsBindingObserver {
  late final SettingsController _settings;
  late final StatsController _stats;
  late final GameController _game;
  late final AudioService _audio;

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
    _audio = widget.audio ?? AudioService();
    _syncAudio();
    _settings.addListener(_syncAudio);
    if (widget.audio == null) unawaited(_audio.preload());
    WidgetsBinding.instance.addObserver(this);
  }

  /// Keeps the audio service in step with the sound setting.
  void _syncAudio() => _audio.enabled = _settings.sound;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_syncAudio);
    _audio.dispose();
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
        Provider<AudioService>.value(value: _audio),
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
          locale: settings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
