/// App-wide constants that are not part of the Sudoku domain.
///
/// Domain constants (units, peers, bit masks) live in
/// `lib/domain/sudoku_constants.dart`.
library;

/// Display name of the game.
const String kAppName = 'UpSudoku';

/// Bundled font family (see `pubspec.yaml` and `ASSETS_LICENSE.md`).
const String kFontFamily = 'Baloo2';

/// Versioned `shared_preferences` key prefixes (see PLAN.md §17).
const String kSettingsKey = 'settings_v1';
const String kStatsKeyPrefix = 'stats_v1_';
const String kGameKeyPrefix = 'game_v1_';
const String kDailyKey = 'daily_v1';
