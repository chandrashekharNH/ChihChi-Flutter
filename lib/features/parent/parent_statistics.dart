import 'package:flutter/foundation.dart';

import '../../data/puzzle_content/puzzle_library.dart';
import '../../data/storage/player_progress.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/catch_letter_level.dart';
import '../../domain/models/home_game.dart';
import '../../domain/models/play_session_record.dart';
import '../../services/progress/progress_service.dart';
import 'parent_text.dart';

/// Totals for a set of play sessions (a day, a week, one game).
class ActivitySummary {
  ActivitySummary([Iterable<PlaySessionRecord> sessions = const []]) {
    for (final s in sessions) {
      learningTime += s.duration;
      gamesPlayed += 1;
      levelsCompleted += s.completedLevels.length;
      correctAnswers += s.correctAnswers;
      questionsAnswered += s.questionsAnswered;
      starsEarned += s.starsEarned;
    }
  }

  /// Seconds.
  double learningTime = 0;
  int gamesPlayed = 0;
  int levelsCompleted = 0;
  int correctAnswers = 0;
  int questionsAnswered = 0;
  int starsEarned = 0;

  /// Null when no questions were answered, so the UI never shows a misleading 0%.
  double? get accuracy => questionsAnswered > 0 ? correctAnswers / questionsAnswered : null;
  double? get averageSession => gamesPlayed > 0 ? learningTime / gamesPlayed : null;
  bool get isEmpty => gamesPlayed == 0;
}

class LevelStars {
  const LevelStars(this.level, this.stars);
  final int level;
  final int? stars;
}

class DayActivity {
  DayActivity(this.date, this.learningTime, this.gamesPlayed, this.timeByGame);
  final DateTime date;
  final double learningTime;
  final int gamesPlayed;

  /// Play time per game on this day (only games that were played).
  final Map<HomeGame, double> timeByGame;
}

/// Play time for one game, for the "time by game" charts.
class GameTime {
  const GameTime(this.game, this.time);
  final HomeGame game;
  final double time;
}

/// Progress in one game, read from that game's own saved progress.
class GameProgressSummary {
  GameProgressSummary({
    required this.game,
    required this.totalLevels,
    required this.levels,
    required this.awardsStars,
    required this.countedFromHistory,
    required this.activity,
    required this.piecesPlaced,
    required this.wrongPlacements,
    required this.recentDays,
  });

  final HomeGame game;

  /// Null for games without levels (AR Explorer, Turbo Race).
  final int? totalLevels;

  /// Completed levels in order.
  final List<LevelStars> levels;
  final bool awardsStars;

  /// True when levels are counted from the play history because the game's saved unlocks are
  /// shared with other games.
  final bool countedFromHistory;
  final ActivitySummary activity;
  final int piecesPlaced;
  final int wrongPlacements;

  /// This game's play time on each of the last seven days, oldest first.
  final List<DayActivity> recentDays;

  int get completedCount => levels.length;

  double? get completion {
    final total = totalLevels;
    if (total == null || total <= 0) return null;
    return (completedCount / total).clamp(0, 1).toDouble();
  }

  int? get totalStars => awardsStars ? levels.fold<int>(0, (a, l) => a + (l.stars ?? 0)) : null;

  double? get placementAccuracy {
    final drops = piecesPlaced + wrongPlacements;
    return drops > 0 ? piecesPlaced / drops : null;
  }
}

enum InsightSkill { letters, puzzles }

enum InsightOutcome { goingWell, steady, morePractice }

/// A gentle, rule-based observation from recent answers. Never a diagnosis.
class LearningInsight {
  const LearningInsight(this.skill, this.outcome, this.rate);
  final InsightSkill skill;
  final InsightOutcome outcome;

  /// Share of right answers (or right piece drops) in the insight window.
  final double rate;

  String text(AppLanguage language) {
    switch ((skill, outcome)) {
      case (InsightSkill.letters, InsightOutcome.goingWell):
        return ParentText.lettersGoingWell.resolve(language);
      case (InsightSkill.letters, InsightOutcome.steady):
        return ParentText.lettersSteady.resolve(language);
      case (InsightSkill.letters, InsightOutcome.morePractice):
        return ParentText.lettersPractice.resolve(language);
      case (InsightSkill.puzzles, InsightOutcome.goingWell):
        return ParentText.puzzlesGoingWell.resolve(language);
      case (InsightSkill.puzzles, InsightOutcome.steady):
        return ParentText.puzzlesSteady.resolve(language);
      case (InsightSkill.puzzles, InsightOutcome.morePractice):
        return ParentText.puzzlesPractice.resolve(language);
    }
  }
}

class RewardTotals {
  const RewardTotals({this.stars = 0, this.candy = 0, this.iceCream = 0, this.chocolate = 0});
  final int stars, candy, iceCream, chocolate;
  bool get isEmpty => stars + candy + iceCream + chocolate == 0;
}

extension HomeGameLevels on HomeGame {
  /// Level count from each game's own configuration; null for games without levels.
  int? get levelCount {
    switch (this) {
      case HomeGame.catchLetter:
        return CatchLetterLevels.totalLevels;
      case HomeGame.catchWorld:
      case HomeGame.learnBlaster:
        return sharedLevelCount;
      case HomeGame.buildPicture:
        return PuzzleLibrary.totalLevels;
      case HomeGame.arHunt:
      case HomeGame.turboRace:
        return null;
    }
  }

  /// Catch World and Learn Blaster's level count (their level select shows 20).
  static const sharedLevelCount = 20;

  /// Whether the game saves answers (or puzzle piece drops) the dashboard can measure.
  bool get recordsAnswers => this != HomeGame.catchWorld;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Pure calculations over saved progress, kept apart from the view model so they are easy to test.
class ParentStatistics {
  /// Answers needed in the insight window before an observation is shown.
  static const minimumInsightSample = 10;
  static const insightWindowDays = 14;

  /// Sessions that started on or after `start` and before `end`.
  static List<PlaySessionRecord> sessionsBetween(List<PlaySessionRecord> sessions, DateTime start, DateTime end) =>
      sessions.where((s) => !s.startedAt.isBefore(start) && s.startedAt.isBefore(end)).toList();

  /// The first day of the week containing `now`. `firstWeekday` is 1 (Monday) … 7 (Sunday).
  static DateTime weekStart(DateTime now, int firstWeekday) {
    final today = _day(now);
    final back = (today.weekday - firstWeekday + 7) % 7;
    return DateTime(today.year, today.month, today.day - back);
  }

  /// One entry per day of the calendar week containing `now`.
  static List<DayActivity> weekDays(List<PlaySessionRecord> sessions, DateTime now, int firstWeekday) =>
      _days(sessions, weekStart(now, firstWeekday), 7);

  /// The last seven days ending today, oldest first.
  static List<DayActivity> lastSevenDays(List<PlaySessionRecord> sessions, DateTime now) {
    final today = _day(now);
    return _days(sessions, DateTime(today.year, today.month, today.day - 6), 7);
  }

  static List<DayActivity> _days(List<PlaySessionRecord> sessions, DateTime start, int count) => [
        for (var offset = 0; offset < count; offset++)
          () {
            final day = DateTime(start.year, start.month, start.day + offset);
            final next = DateTime(day.year, day.month, day.day + 1);
            final daySessions = sessionsBetween(sessions, day, next);
            final summary = ActivitySummary(daySessions);
            final byGame = <HomeGame, double>{};
            for (final s in daySessions) {
              byGame[s.game] = (byGame[s.game] ?? 0) + s.duration;
            }
            return DayActivity(day, summary.learningTime, summary.gamesPlayed, byGame);
          }(),
      ];

  /// Play time per game, largest first, leaving out games with no time.
  static List<GameTime> timeByGame(List<PlaySessionRecord> sessions) {
    final totals = <HomeGame, double>{};
    for (final s in sessions) {
      totals[s.game] = (totals[s.game] ?? 0) + s.duration;
    }
    return [
      for (final game in HomeGame.values)
        if ((totals[game] ?? 0) > 0) GameTime(game, totals[game]!),
    ]..sort((a, b) => b.time.compareTo(a.time));
  }

  /// Consecutive days with play, ending today (or yesterday when nothing has been played yet today).
  static int streakDays(List<PlaySessionRecord> sessions, DateTime now) {
    final played = sessions.map((s) => _day(s.startedAt)).toSet();
    var day = _day(now);
    if (!played.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
    var count = 0;
    while (played.contains(day)) {
      count += 1;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  static List<LearningInsight> insights(List<PlaySessionRecord> sessions, DateTime now) {
    final windowStart = now.subtract(const Duration(days: insightWindowDays));
    final recent = sessions.where((s) => !s.startedAt.isBefore(windowStart) && !s.startedAt.isAfter(now)).toList();
    final result = <LearningInsight>[];
    for (final skill in InsightSkill.values) {
      int right, total;
      switch (skill) {
        case InsightSkill.letters:
          // Catch Letter and Learn Blaster both ask the child to find letters.
          final letterGames = recent.where((s) => s.game == HomeGame.catchLetter || s.game == HomeGame.learnBlaster);
          right = letterGames.fold(0, (a, s) => a + s.correctAnswers);
          total = letterGames.fold(0, (a, s) => a + s.questionsAnswered);
        case InsightSkill.puzzles:
          final puzzles = recent.where((s) => s.game == HomeGame.buildPicture);
          right = puzzles.fold(0, (a, s) => a + s.piecesPlaced);
          total = right + puzzles.fold(0, (a, s) => a + s.wrongPlacements);
      }
      if (total < minimumInsightSample) continue;
      final rate = right / total;
      final outcome = rate >= 0.8
          ? InsightOutcome.goingWell
          : rate >= 0.6
              ? InsightOutcome.steady
              : InsightOutcome.morePractice;
      result.add(LearningInsight(skill, outcome, rate));
    }
    return result;
  }

  static List<GameProgressSummary> gameProgress(PlayerProgress progress, List<PlaySessionRecord> sessions, DateTime now) {
    return [
      for (final game in HomeGame.values)
        () {
          final gameSessions = sessions.where((s) => s.game == game).toList();
          List<LevelStars> levels;
          var awardsStars = false, fromHistory = false;
          switch (game) {
            case HomeGame.catchLetter:
              levels = [for (final e in progress.catchLetterStars.entries) LevelStars(e.key, e.value)];
              awardsStars = true;
            case HomeGame.buildPicture:
              levels = [for (final e in progress.puzzleLevelStars.entries) LevelStars(e.key, e.value)];
              awardsStars = true;
            case HomeGame.catchWorld:
            case HomeGame.learnBlaster:
              final finished = {for (final s in gameSessions) ...s.completedLevels.map((l) => l.level)};
              levels = [for (final l in finished) LevelStars(l, null)];
              fromHistory = true;
            case HomeGame.arHunt:
            case HomeGame.turboRace:
              levels = [];
          }
          levels.sort((a, b) => a.level.compareTo(b.level));
          return GameProgressSummary(
            game: game,
            totalLevels: game.levelCount,
            levels: levels,
            awardsStars: awardsStars,
            countedFromHistory: fromHistory,
            activity: ActivitySummary(gameSessions),
            piecesPlaced: gameSessions.fold(0, (a, s) => a + s.piecesPlaced),
            wrongPlacements: gameSessions.fold(0, (a, s) => a + s.wrongPlacements),
            recentDays: lastSevenDays(gameSessions, now),
          );
        }(),
    ];
  }
}

enum DashboardLoadState { loading, ready, unavailable }

/// Read layer over `ProgressService` for the Parent Zone. Holds no game logic and no second copy
/// of progress; `refresh()` recomputes everything from the saved data.
class ParentDashboardViewModel extends ChangeNotifier {
  ParentDashboardViewModel(this._progressService, {DateTime Function()? now, this.firstWeekday = DateTime.monday})
      : _now = now ?? DateTime.now;

  static const recentActivityLimit = 6;

  final ProgressService _progressService;
  final DateTime Function() _now;

  /// 1 (Monday) … 7 (Sunday), from the app language's calendar.
  int firstWeekday;

  DashboardLoadState loadState = DashboardLoadState.loading;
  ActivitySummary today = ActivitySummary();
  ActivitySummary week = ActivitySummary();
  List<DayActivity> weekDays = [];
  List<GameTime> todayByGame = [];
  List<GameTime> weekByGame = [];
  List<GameProgressSummary> games = [];
  List<PlaySessionRecord> recentSessions = [];
  List<LearningInsight> insights = [];
  int streakDays = 0;
  DateTime? recordedSince;
  RewardTotals rewards = const RewardTotals();
  int bestAnswerStreak = 0;
  String childName = '';
  String childAvatar = '';

  void refresh() {
    if (!_progressService.isStoreAvailable) {
      loadState = DashboardLoadState.unavailable;
      notifyListeners();
      return;
    }
    final progress = _progressService.progress;
    final sessions = progress.playSessions;
    final date = _now();
    final dayStart = _day(date);
    final todaySessions = ParentStatistics.sessionsBetween(sessions, dayStart, dayStart.add(const Duration(days: 1)));
    today = ActivitySummary(todaySessions);
    todayByGame = ParentStatistics.timeByGame(todaySessions);
    final ws = ParentStatistics.weekStart(date, firstWeekday);
    final weekSessions = ParentStatistics.sessionsBetween(sessions, ws, DateTime(ws.year, ws.month, ws.day + 7));
    week = ActivitySummary(weekSessions);
    weekByGame = ParentStatistics.timeByGame(weekSessions);
    weekDays = ParentStatistics.weekDays(sessions, date, firstWeekday);
    games = ParentStatistics.gameProgress(progress, sessions, date);
    recentSessions = ([...sessions]..sort((a, b) => b.startedAt.compareTo(a.startedAt))).take(recentActivityLimit).toList();
    insights = ParentStatistics.insights(sessions, date);
    streakDays = ParentStatistics.streakDays(sessions, date);
    recordedSince = sessions.isEmpty ? null : sessions.map((s) => s.startedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    rewards = RewardTotals(
        stars: progress.stars, candy: progress.candy, iceCream: progress.iceCream, chocolate: progress.chocolate);
    bestAnswerStreak = progress.bestStreak;
    childName = progress.childName;
    childAvatar = progress.childAvatar;
    loadState = DashboardLoadState.ready;
    notifyListeners();
  }

  GameProgressSummary? summary(HomeGame game) => games.where((g) => g.game == game).firstOrNull;
}
