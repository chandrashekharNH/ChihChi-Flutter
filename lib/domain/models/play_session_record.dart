import 'dart:math' as math;

import 'home_game.dart';

class CompletedLevel {
  CompletedLevel(this.level, this.stars);
  int level;

  /// Stars for games that award them per level (Catch Letter, Build the Picture).
  int? stars;

  Map<String, dynamic> toJson() => {'level': level, if (stars != null) 'stars': stars};
  factory CompletedLevel.fromJson(Map<String, dynamic> j) => CompletedLevel(j['level'] as int, j['stars'] as int?);
}

/// One stretch of play on a game screen, kept on this device so the Parent Zone can show real
/// activity (time played, levels finished, answers). Only `ProgressService` writes these.
class PlaySessionRecord {
  PlaySessionRecord({
    String? id,
    required this.game,
    required this.startedAt,
    this.duration = 0,
    this.correctAnswers = 0,
    this.wrongAnswers = 0,
    this.piecesPlaced = 0,
    this.wrongPlacements = 0,
    this.starsEarned = 0,
    List<CompletedLevel>? completedLevels,
  })  : id = id ?? '${DateTime.now().microsecondsSinceEpoch}${math.Random().nextInt(99999)}',
        completedLevels = completedLevels ?? [];

  final String id;
  HomeGame game;
  DateTime startedAt;

  /// Seconds spent with the game on screen and the app active.
  double duration;
  int correctAnswers;
  int wrongAnswers;

  /// Build the Picture: pieces dropped in the right place, and drops in the wrong place.
  int piecesPlaced;
  int wrongPlacements;
  int starsEarned;
  List<CompletedLevel> completedLevels;

  int get questionsAnswered => correctAnswers + wrongAnswers;

  bool get hasResults => questionsAnswered > 0 || piecesPlaced > 0 || starsEarned > 0 || completedLevels.isNotEmpty;

  /// Adds a finished level, keeping the best stars if the level was finished twice.
  void recordCompletedLevel(int level, int? stars) {
    final index = completedLevels.indexWhere((c) => c.level == level);
    if (index >= 0) {
      if (stars != null) completedLevels[index].stars = math.max(completedLevels[index].stars ?? 0, stars);
    } else {
      completedLevels.add(CompletedLevel(level, stars));
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'game': game.rawValue,
        'startedAt': startedAt.toIso8601String(),
        'duration': duration,
        'correctAnswers': correctAnswers,
        'wrongAnswers': wrongAnswers,
        'piecesPlaced': piecesPlaced,
        'wrongPlacements': wrongPlacements,
        'starsEarned': starsEarned,
        'completedLevels': completedLevels.map((c) => c.toJson()).toList(),
      };

  static PlaySessionRecord? fromJson(Map<String, dynamic> j) {
    final game = HomeGame.fromRaw(j['game'] as String?);
    if (game == null) return null;
    return PlaySessionRecord(
      id: j['id'] as String?,
      game: game,
      startedAt: DateTime.tryParse(j['startedAt'] as String? ?? '') ?? DateTime.now(),
      duration: (j['duration'] as num?)?.toDouble() ?? 0,
      correctAnswers: j['correctAnswers'] as int? ?? 0,
      wrongAnswers: j['wrongAnswers'] as int? ?? 0,
      piecesPlaced: j['piecesPlaced'] as int? ?? 0,
      wrongPlacements: j['wrongPlacements'] as int? ?? 0,
      starsEarned: j['starsEarned'] as int? ?? 0,
      completedLevels: ((j['completedLevels'] as List?) ?? [])
          .map((c) => CompletedLevel.fromJson((c as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}
