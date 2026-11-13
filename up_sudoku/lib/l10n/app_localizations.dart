/// Every user-visible string, in English and Vietnamese.
///
/// Hand-written instead of generated ARB files: the app has two locales and a
/// flat string table keeps the lookup explicit and testable. New strings go in
/// as a getter using `_t(english, vietnamese)`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../domain/logic/technique.dart';
import '../domain/models/difficulty.dart';
import '../domain/models/settings.dart';

/// The localized strings of one locale.
class AppLocalizations {
  const AppLocalizations(this.locale);

  /// The locale these strings are for.
  final Locale locale;

  /// Locales the app ships strings for.
  static const List<Locale> supportedLocales = [Locale('en'), Locale('vi')];

  /// The delegate installed on `MaterialApp`.
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// The strings of the surrounding context.
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  /// True when Vietnamese strings are used.
  bool get isVietnamese => locale.languageCode == 'vi';

  String _t(String en, String vi) => isVietnamese ? vi : en;

  // ---------------------------------------------------------------- common

  String get continueGame => _t('Continue', 'Tiếp tục');
  String get play => _t('Play', 'Chơi');
  String get pause => _t('Pause', 'Tạm dừng');
  String get resume => _t('Resume', 'Tiếp tục');
  String get home => _t('Home', 'Trang chủ');
  String get cancel => _t('Cancel', 'Huỷ');
  String get statistics => _t('Statistics', 'Thống kê');
  String get howToPlay => _t('How to play', 'Cách chơi');
  String get settings => _t('Settings', 'Cài đặt');

  /// Best time shown on the home cards.
  String bestTime(String time) => _t('Best $time', 'Kỷ lục $time');

  /// `12/200 solved`.
  String solvedCount(int done, int total) =>
      _t('$done/$total solved', 'Đã giải $done/$total');

  String get poolComingSoon => _t('Pool coming soon', 'Bộ câu đố sắp có');

  // ------------------------------------------------------------ difficulty

  /// The localized name of [difficulty].
  String difficulty(Difficulty difficulty) => switch (difficulty) {
        Difficulty.easy => _t('Easy', 'Dễ'),
        Difficulty.medium => _t('Medium', 'Trung bình'),
        Difficulty.hard => _t('Hard', 'Khó'),
        Difficulty.veryHard => _t('Very Hard', 'Rất khó'),
      };

  /// One-line description of [difficulty] on the home cards.
  String difficultyDescription(Difficulty difficulty) => switch (difficulty) {
        Difficulty.easy => _t(
            'Solved with singles — a gentle start.',
            'Chỉ cần kỹ thuật cơ bản — khởi đầu nhẹ nhàng.',
          ),
        Difficulty.medium => _t(
            'Pairs, triples and pointing — a warm-up.',
            'Cặp, bộ ba và pointing — khởi động vừa sức.',
          ),
        Difficulty.hard => _t(
            'Fish and wings — real deductions needed.',
            'Fish và wing — cần suy luận thật sự.',
          ),
        Difficulty.veryHard => _t(
            'Chains and beyond — for the brave.',
            'Chuỗi suy luận và hơn thế — dành cho người gan dạ.',
          ),
      };

  /// Rule badge for the feedback mode.
  String feedbackBadge(FeedbackMode feedback) => switch (feedback) {
        FeedbackMode.instant => feedbackInstant,
        FeedbackMode.conflictsOnly => conflictsOnly,
        FeedbackMode.none => noLiveFeedback,
      };

  String get feedbackInstant => _t('Instant feedback', 'Phản hồi tức thì');
  String get conflictsOnly => _t('Conflicts only', 'Chỉ báo trùng');
  String get noLiveFeedback =>
      _t('No live feedback', 'Không phản hồi trực tiếp');

  /// `3 hints`.
  String hintsBadge(int count) => _t('$count hints', '$count gợi ý');

  /// `5 mistakes`.
  String mistakesBadge(int count) => _t('$count mistakes', '$count lỗi');

  // ------------------------------------------------------------ home screen

  String get dailyPuzzle => _t('Daily puzzle', 'Câu đố hằng ngày');
  String get dailyCompleted => _t('completed today', 'đã hoàn thành hôm nay');
  String get dailySameEveryday =>
      _t('same puzzle for everyone', 'cùng một câu đố cho mọi người');

  /// `4 day streak`.
  String dayStreak(int days) => _t('$days day streak', 'chuỗi $days ngày');

  String get playDaily => _t('Play daily', 'Chơi câu đố ngày');
  String get playDailyAgain => _t('Play daily again', 'Chơi lại câu đố ngày');

  // ------------------------------------------------------------ game screen

  /// `Mistakes: 2` when the limit is unlimited.
  String mistakesCount(int mistakes) =>
      _t('Mistakes: $mistakes', 'Lỗi: $mistakes');

  /// `Mistakes: 2 / 5`.
  String mistakesOf(int mistakes, int limit) =>
      _t('Mistakes: $mistakes / $limit', 'Lỗi: $mistakes / $limit');

  String get paused => _t('Paused', 'Đã tạm dừng');

  String get undo => _t('Undo', 'Hoàn tác');
  String get redo => _t('Redo', 'Làm lại');
  String get erase => _t('Erase', 'Xoá');
  String get notes => _t('Notes', 'Ghi chú');
  String get autoNotes => _t('Auto notes', 'Ghi chú tự động');

  /// `Hint 3`.
  String hintWithCount(int left) => _t('Hint $left', 'Gợi ý $left');

  /// `Check 2`.
  String checkWithCount(int left) => _t('Check $left', 'Kiểm tra $left');

  String get showMore => _t('Show more', 'Xem thêm');
  String get apply => _t('Apply', 'Áp dụng');
  String get revealCell => _t('Reveal cell', 'Mở ô');
  String get closeHint => _t('Close hint', 'Đóng gợi ý');

  /// Accessibility label of a digit button.
  String digitLabel(int digit, int remaining, {required bool notesMode}) {
    final base = _t(
      'Digit $digit, $remaining remaining',
      'Số $digit, còn $remaining',
    );
    return notesMode ? _t('$base, note mode', '$base, chế độ ghi chú') : base;
  }

  /// Accessibility label of the timer.
  String elapsedTime(String time) =>
      _t('Elapsed time $time', 'Thời gian đã chơi $time');

  /// Accessibility label of a board cell, without its content.
  String boardCell(int row, int column) =>
      _t('Row $row, column $column', 'Hàng $row, cột $column');

  /// `, value 7` — appended after [boardCell].
  String boardValue(int value) => _t(', value $value', ', giá trị $value');

  /// `, given` — appended after [boardValue].
  String get boardGiven => _t(', given', ', số cho sẵn');

  /// `, notes 1 4 7`.
  String boardNotes(String notes) => _t(', notes $notes', ', ghi chú $notes');

  /// `, empty` — appended after [boardCell].
  String get boardEmpty => _t(', empty', ', trống');

  // ----------------------------------------------------------------- hints

  String get hint => _t('Hint', 'Gợi ý');

  /// Tooltip of the chevron that reveals actions hidden by a narrow toolbar.
  String get moreActions => _t('More actions', 'Thêm thao tác');

  /// The name of [technique] as shown in a hint headline.
  String techniqueName(Technique technique) => switch (technique) {
        Technique.nakedSingle => _t('Naked Single', 'Single trần'),
        Technique.hiddenSingle => _t('Hidden Single', 'Single ẩn'),
        Technique.nakedPair => _t('Naked Pair', 'Cặp trần'),
        Technique.hiddenPair => _t('Hidden Pair', 'Cặp ẩn'),
        Technique.nakedTriple => _t('Naked Triple', 'Bộ ba trần'),
        Technique.hiddenTriple => _t('Hidden Triple', 'Bộ ba ẩn'),
        Technique.pointing => _t('Pointing Pair/Triple', 'Pointing đôi/bộ ba'),
        Technique.boxLine => _t('Box/Line Reduction', 'Loại trừ hộp/hàng'),
        Technique.nakedQuad => _t('Naked Quad', 'Bộ bốn trần'),
        Technique.hiddenQuad => _t('Hidden Quad', 'Bộ bốn ẩn'),
        Technique.xWing => _t('X-Wing', 'X-Wing'),
        Technique.swordfish => _t('Swordfish', 'Swordfish'),
        Technique.xyWing => _t('XY-Wing', 'XY-Wing'),
        Technique.xyzWing => _t('XYZ-Wing', 'XYZ-Wing'),
      };
  String get noSimpleTechnique =>
      _t('No simple technique applies', 'Không có kỹ thuật đơn giản phù hợp');
  String get somethingIsWrong =>
      _t('Something here is incorrect', 'Ô này chưa đúng');

  String get revealExplanation => _t(
        'The grader cannot finish this puzzle with simple techniques. '
            'Reveal one cell to keep going.',
        'Bộ chấm không thể giải xong câu đố bằng các kỹ thuật đơn giản. '
            'Hãy mở một ô để tiếp tục.',
      );

  String get wrongDigitExplanation => _t(
      'This digit does not match the solution.',
      'Chữ số này không khớp lời giải.');

  /// Stage-2 explanation of a placement hint.
  String placementExplanation(int digit) => _t(
        'Digit $digit can only go in this cell.',
        'Số $digit chỉ có thể nằm ở ô này.',
      );

  /// Stage-2 explanation of an elimination hint.
  String eliminationExplanation(String digits, int cells) => _t(
        'Remove $digits from $cells ${cells == 1 ? 'cell' : 'cells'}.',
        'Loại $digits khỏi $cells ô.',
      );

  String get candidatesAlreadyRemoved => _t(
      'Those candidates are already removed.',
      'Các ứng viên đó đã được loại rồi.');

  String get boardFullButWrong => _t(
        'The board is full but something is still wrong.',
        'Bàn cờ đã đầy nhưng vẫn còn chỗ sai.',
      );

  // ---------------------------------------------------------------- results

  String get puzzleSolved => _t('Puzzle solved!', 'Đã giải xong!');

  /// Accessibility label of the star row.
  String starsLabel(int stars) => _t('$stars of 3 stars', '$stars trên 3 sao');

  /// `Score: 1234`.
  String scoreValue(int score) => _t('Score: $score', 'Điểm: $score');

  String get flawlessWin =>
      _t('Flawless — no mistakes.', 'Hoàn hảo — không có lỗi nào.');

  /// `Mistakes: 2` on the result dialog.
  String mistakesLine(int mistakes) =>
      _t('Mistakes: $mistakes', 'Lỗi: $mistakes');

  /// `Hints: 1`.
  String hintsUsedLine(int hints) => _t('Hints: $hints', 'Gợi ý: $hints');

  /// `Checks: 1`.
  String checksUsedLine(int checks) =>
      _t('Checks: $checks', 'Kiểm tra: $checks');

  String get nextPuzzle => _t('Next puzzle', 'Câu đố khác');
  String get newPuzzle => _t('New puzzle', 'Câu đố mới');

  String get outOfMistakes => _t('Out of mistakes', 'Hết lượt sai');

  /// Body of the lose dialog.
  String outOfMistakesBody(int limit) => _t(
        'You reached the limit of $limit mistakes. '
            'Start a new puzzle when you are ready.',
        'Bạn đã đạt giới hạn $limit lỗi. '
            'Hãy bắt đầu câu đố mới khi sẵn sàng.',
      );

  // ------------------------------------------------------------------ stats

  String get started => _t('Started', 'Đã bắt đầu');
  String get winRate => _t('Win rate', 'Tỷ lệ thắng');
  String get bestTimeLabel => _t('Best time', 'Thời gian tốt nhất');
  String get averageTime => _t('Average time', 'Thời gian trung bình');
  String get flawlessWins => _t('Flawless wins', 'Thắng hoàn hảo');
  String get streak => _t('Streak', 'Chuỗi thắng');

  /// `3 (best 7)`.
  String streakValue(int current, int best) =>
      _t('$current (best $best)', '$current (tốt nhất $best)');

  /// `12 solved` on a stats card.
  String statsSolved(int count) => _t('$count solved', '$count đã giải');

  // --------------------------------------------------------------- settings

  String get soundAndFeedback => _t('Sound & feedback', 'Âm thanh & phản hồi');
  String get soundEffects => _t('Sound effects', 'Hiệu ứng âm thanh');
  String get soundEffectsSubtitle => _t(
        'Tap, place, error and win sounds',
        'Âm thanh chọn ô, đặt số, báo lỗi và thắng',
      );
  String get haptics => _t('Haptics', 'Rung');
  String get hapticsSubtitle => _t(
        'Vibrate on placement and mistakes',
        'Rung khi đặt số và khi nhập sai',
      );

  String get appearance => _t('Appearance', 'Giao diện');
  String get themeSystem => _t('System', 'Hệ thống');
  String get themeLight => _t('Light', 'Sáng');
  String get themeDark => _t('Dark', 'Tối');
  String get largeDigits => _t('Large digits', 'Chữ số lớn');
  String get largeDigitsSubtitle => _t(
        'Bigger digits and notes on the board',
        'Chữ số và ghi chú lớn hơn trên bàn cờ',
      );

  String get boardHighlighting => _t('Board highlighting', 'Tô sáng bàn cờ');
  String get highlightPeers => _t('Highlight peers', 'Tô sáng các ô liên quan');
  String get highlightPeersSubtitle => _t(
        'Tint the row, column and box of the cell',
        'Tô màu hàng, cột và ô 3×3 của ô đang chọn',
      );
  String get highlightSameDigit =>
      _t('Highlight same digit', 'Tô sáng cùng chữ số');
  String get highlightSameDigitSubtitle => _t(
        'Tint the other cells holding that digit',
        'Tô màu các ô khác có cùng chữ số đó',
      );

  String get language => _t('Language', 'Ngôn ngữ');
  String get languageSystem => _t('System', 'Theo máy');
  String get languageEnglish => _t('English', 'Tiếng Anh');
  String get languageVietnamese => _t('Vietnamese', 'Tiếng Việt');

  /// Name of a language option in its own language.
  String languageName(AppLanguage language) => switch (language) {
        AppLanguage.system => languageSystem,
        AppLanguage.english => languageEnglish,
        AppLanguage.vietnamese => languageVietnamese,
      };

  String get resetData => _t('Reset data', 'Xoá dữ liệu');
  String get resetDataSubtitle => _t(
        'Statistics, saved games and daily streak',
        'Thống kê, ván đang chơi và chuỗi ngày',
      );
  String get resetDataTitle => _t('Reset data?', 'Xoá dữ liệu?');
  String get resetDataBody => _t(
        'This clears statistics, saved games and the daily streak. '
            'It cannot be undone.',
        'Thao tác này xoá thống kê, các ván đang chơi và chuỗi ngày. '
            'Không thể hoàn tác.',
      );
  String get reset => _t('Reset', 'Xoá');
  String get allDataCleared =>
      _t('All data cleared.', 'Đã xoá toàn bộ dữ liệu.');

  // ------------------------------------------------------------ how to play

  String get goalTitle => _t('The goal', 'Mục tiêu');
  String get goalBody => _t(
        'Fill the 9×9 grid so every row, column and 3×3 box contains '
            'each digit from 1 to 9 exactly once. Every bundled puzzle has '
            'exactly one solution.',
        'Điền kín lưới 9×9 sao cho mỗi hàng, mỗi cột và mỗi ô 3×3 '
            'chứa đủ các số từ 1 đến 9, mỗi số đúng một lần. '
            'Mọi câu đố trong app đều có duy nhất một lời giải.',
      );

  String get controlsTitle => _t('Controls', 'Điều khiển');
  String get controlsBody => _t(
        'Tap a cell to select it, then tap a digit on the pad. '
            'Notes lets the pad write candidates instead of digits. '
            'Erase clears the selected cell. Undo and Redo step through '
            'your moves, including notes removed automatically.',
        'Chạm vào một ô để chọn, rồi chạm số trên bàn phím. '
            'Ghi chú để bàn phím ghi ứng viên thay vì điền số. '
            'Xoá làm trống ô đang chọn. Hoàn tác và Làm lại đi qua các nước đi, '
            'kể cả những ghi chú bị xoá tự động.',
      );

  String get notesTitle => _t('Notes', 'Ghi chú');
  String get notesBody => _t(
        'Notes are the candidates you keep by hand. Placing a digit '
            'removes it from the notes of the cells that share a row, '
            'column or box (except on Very Hard). Auto notes fills every '
            'candidate for you on Easy and Medium.',
        'Ghi chú là các ứng viên bạn tự đánh dấu. Khi đặt một số, số đó '
            'được xoá khỏi ghi chú của các ô cùng hàng, cột hoặc ô 3×3 '
            '(trừ mức Rất khó). Ghi chú tự động điền mọi ứng viên ở mức Dễ và '
            'Trung bình.',
      );

  String get hintsTitle => _t('Hints and checks', 'Gợi ý và kiểm tra');
  String get hintsBody => _t(
        'A hint names the technique that applies and highlights its '
            'cells; ask for more to read the explanation, then apply it. '
            'If the board holds a wrong digit the hint points at it. On '
            'Very Hard, a puzzle can be beyond the simple techniques — the '
            'hint then offers to reveal one cell. Check board marks every '
            'wrong digit and is limited per difficulty.',
        'Gợi ý cho biết kỹ thuật phù hợp và tô sáng các ô liên quan; '
            'bấm xem thêm để đọc giải thích rồi áp dụng. Nếu trên bàn có số sai, '
            'gợi ý sẽ chỉ đúng ô đó. Ở mức Rất khó, câu đố có thể vượt ngoài '
            'các kỹ thuật đơn giản — khi đó gợi ý sẽ đề nghị mở một ô. '
            'Kiểm tra bàn cờ đánh dấu mọi số sai và có số lượt giới hạn theo mức.',
      );

  String get difficultiesTitle => _t('Difficulties', 'Các mức độ');
  String get difficultiesBody => _t(
        'Easy: singles only, instant feedback, unlimited mistakes.\n'
            'Medium: pairs, triples and pointing; instant feedback with a '
            '5-mistake limit.\n'
            'Hard: fish and wings; only duplicate conflicts are shown, '
            '3 checks.\n'
            'Very Hard: beyond the implemented techniques; no live '
            'feedback, 1 check, 1 hint.',
        'Dễ: chỉ kỹ thuật cơ bản, phản hồi tức thì, không giới hạn lỗi.\n'
            'Trung bình: cặp, bộ ba và pointing; phản hồi tức thì, tối đa 5 lỗi.\n'
            'Khó: fish và wing; chỉ báo trùng lặp, 3 lượt kiểm tra.\n'
            'Rất khó: vượt ngoài các kỹ thuật đã cài; không phản hồi trực tiếp, '
            '1 lượt kiểm tra, 1 gợi ý.',
      );

  String get scoringTitle => _t('Scoring and stars', 'Điểm và sao');
  String get scoringBody => _t(
        'Finishing faster than par and avoiding mistakes, hints and '
            'checks earns more points. Three stars need a flawless win '
            'within par time.',
        'Hoàn thành nhanh hơn mốc thời gian và tránh lỗi, gợi ý, kiểm tra sẽ '
            'được nhiều điểm hơn. Ba sao cần thắng hoàn hảo trong thời gian mốc.',
      );

  String get offlineTitle => _t('Offline', 'Ngoại tuyến');
  String get offlineBody => _t(
        'Everything is bundled with the app: puzzles, fonts and '
            'sounds. No network is ever used, and your games and '
            'statistics stay on this device.',
        'Mọi thứ đều nằm trong app: câu đố, phông chữ và âm thanh. '
            'Không bao giờ dùng mạng, và các ván chơi cùng thống kê chỉ lưu trên '
            'thiết bị này.',
      );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
