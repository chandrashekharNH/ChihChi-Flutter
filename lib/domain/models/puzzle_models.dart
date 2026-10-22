import 'dart:ui' as ui;

import '../../core/ui/palette.dart';
import 'app_language.dart';

enum PuzzleCategory {
  animals('🦁'),
  nature('🌳'),
  vehicles('🚗'),
  food('🍎'),
  space('🚀'),
  dinosaurs('🦖'),
  objects('🧸'),
  places('🏰'),
  india('🪔'),
  letters('🔤'),
  numbers('🔢'),
  colors('🎨'),
  words('📝');

  const PuzzleCategory(this.icon);
  final String icon;
}

/// Background painted behind scene puzzles.
enum PuzzleBackdrop { meadow, farm, jungle, underwater, beach, space, night, snow, city, desert, sky, festival, indoor, volcano }

/// One emoji placed on a scene. Coordinates are 0…1 of the picture, `y` from the top.
class PuzzleSceneElement {
  const PuzzleSceneElement(this.emoji, this.x, this.y, this.size);
  final String emoji;
  final double x;
  final double y;
  final double size;
}

/// What a puzzle picture shows.
sealed class PuzzleSubject {
  const PuzzleSubject();

  /// Every emoji the picture draws (for looking up artwork).
  List<String> get emojis;
}

/// One big object (lion, rocket…) on a soft backdrop.
class ObjectSubject extends PuzzleSubject {
  const ObjectSubject(this.emoji, this.backdrop);
  final String emoji;
  final PuzzleBackdrop backdrop;
  @override
  List<String> get emojis => [emoji];
}

/// Several objects on a painted backdrop (farm, space…).
class SceneSubject extends PuzzleSubject {
  const SceneSubject(this.backdrop, this.elements);
  final PuzzleBackdrop backdrop;
  final List<PuzzleSceneElement> elements;
  @override
  List<String> get emojis => elements.map((e) => e.emoji).toList();
}

/// A big letter with its object: "A → 🍎".
class LetterSubject extends PuzzleSubject {
  const LetterSubject(this.symbol, this.emoji);
  final String symbol;
  final String emoji;
  @override
  List<String> get emojis => [emoji];
}

/// A numeral with that many objects (quantity up to 20).
class NumberSubject extends PuzzleSubject {
  const NumberSubject(this.value, this.emoji);
  final int value;
  final String emoji;
  @override
  List<String> get emojis => [emoji];
}

/// An object on a backing of one colour.
class ColorSubject extends PuzzleSubject {
  const ColorSubject(this.color);
  final PuzzleColor color;
  @override
  List<String> get emojis => [color.emoji];
}

/// Written word with its picture.
class WordSubject extends PuzzleSubject {
  const WordSubject(this.emoji);
  final String emoji;
  @override
  List<String> get emojis => [emoji];
}

/// A photo the child took or chose. Kept only in memory, never saved.
class PhotoSubject extends PuzzleSubject {
  const PhotoSubject(this.image);
  final ui.Image image;
  @override
  List<String> get emojis => const [];
}

enum PuzzleColor {
  red(0.91, 0.2, 0.23, '🍎'),
  blue(0.16, 0.42, 0.93, '🐳'),
  green(0.18, 0.68, 0.3, '🐸'),
  yellow(0.99, 0.83, 0.12, '🌻'),
  orange(0.98, 0.55, 0.12, '🍊'),
  purple(0.58, 0.3, 0.86, '🍇'),
  pink(0.98, 0.5, 0.72, '🌸'),
  brown(0.55, 0.35, 0.2, '🐻'),
  black(0.12, 0.12, 0.14, '🐈‍⬛'),
  white(0.97, 0.97, 0.97, '🐑'),
  gray(0.55, 0.57, 0.6, '🐘'),
  skyBlue(0.45, 0.78, 0.98, '🦋');

  const PuzzleColor(this.r, this.g, this.b, this.emoji);
  final double r, g, b;

  /// A familiar object that is naturally this colour.
  final String emoji;

  ui.Color get color => rgb(r, g, b);
}

class PuzzleDefinition {
  const PuzzleDefinition({required this.id, required this.category, required this.subject, required this.names});
  final String id;
  final PuzzleCategory category;
  final PuzzleSubject subject;

  /// Name per language; spoken at the start and shown when complete.
  final Map<AppLanguage, String> names;

  String name(AppLanguage language) => names[language] ?? names[AppLanguage.english] ?? id;

  /// Small symbol for lists and maps.
  String get thumbnail {
    final s = subject;
    switch (s) {
      case ObjectSubject():
        return s.emoji;
      case WordSubject():
        return s.emoji;
      case SceneSubject():
        if (s.elements.isEmpty) return '🧩';
        return s.elements.reduce((a, b) => a.size >= b.size ? a : b).emoji;
      case LetterSubject():
        return s.symbol;
      case NumberSubject():
        return '${s.value}';
      case ColorSubject():
        return s.color.emoji;
      case PhotoSubject():
        return '📷';
    }
  }

  /// All photo puzzles share one id, so their results take one small entry in saved progress.
  static const photoPuzzleID = 'my_photo';

  /// A free-play puzzle made from the child's own photo.
  static PuzzleDefinition photo(ui.Image image, Map<AppLanguage, String> names) =>
      PuzzleDefinition(id: photoPuzzleID, category: PuzzleCategory.objects, subject: PhotoSubject(image), names: names);

  @override
  bool operator ==(Object other) => other is PuzzleDefinition && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class PuzzleGrid {
  const PuzzleGrid(this.rows, this.columns);
  final int rows;
  final int columns;
  int get pieceCount => rows * columns;
  @override
  bool operator ==(Object other) => other is PuzzleGrid && other.rows == rows && other.columns == columns;
  @override
  int get hashCode => Object.hash(rows, columns);
}

enum PuzzleDifficulty {
  veryEasy(1, '🐣'),
  easy(2, '🐥'),
  normal(3, '🦊'),
  advanced(4, '🦁'),
  expert(5, '🐉');

  const PuzzleDifficulty(this.rawValue, this.icon);
  final int rawValue;
  final String icon;

  static PuzzleDifficulty? fromRaw(int? raw) {
    for (final d in values) {
      if (d.rawValue == raw) return d;
    }
    return null;
  }

  /// Grids (rows × columns) used by this difficulty, easiest first.
  List<PuzzleGrid> get grids {
    switch (this) {
      case PuzzleDifficulty.veryEasy:
        return const [PuzzleGrid(1, 2), PuzzleGrid(1, 3), PuzzleGrid(2, 2)];
      case PuzzleDifficulty.easy:
        return const [PuzzleGrid(2, 2), PuzzleGrid(2, 3), PuzzleGrid(3, 3)];
      case PuzzleDifficulty.normal:
        return const [PuzzleGrid(3, 3), PuzzleGrid(3, 4), PuzzleGrid(4, 4)];
      case PuzzleDifficulty.advanced:
        return const [PuzzleGrid(4, 4), PuzzleGrid(5, 5), PuzzleGrid(6, 6)];
      case PuzzleDifficulty.expert:
        return const [PuzzleGrid(6, 6), PuzzleGrid(7, 7), PuzzleGrid(8, 8)];
    }
  }

  /// Jigsaw tabs from Easy up; Very Easy uses rounded squares.
  bool get usesJigsawShapes => this != PuzzleDifficulty.veryEasy;

  /// Pieces start turned and must be rotated (Advanced and Expert).
  bool get requiresRotation => rawValue >= PuzzleDifficulty.advanced.rawValue;

  /// Faint picture on the board to guide placement (Very Easy, Easy).
  bool get showsGhostImage => rawValue <= PuzzleDifficulty.easy.rawValue;

  /// Target glows when a dragged piece is near it (Very Easy … Normal).
  bool get showsNearGlow => rawValue <= PuzzleDifficulty.normal.rawValue;

  /// How close (in piece sizes) a drop must be to snap.
  double get snapTolerance => const [0.6, 0.5, 0.42, 0.36, 0.3][index];

  /// Target time (seconds per piece) for the time bonus.
  double get secondsPerPiece => const [12.0, 10.0, 8.0, 7.0, 6.0][index];
  bool get showsTimeChallenge => rawValue >= PuzzleDifficulty.advanced.rawValue;

  /// Young children are scored on finishing, not on speed or mistakes.
  bool get scoresMistakes => rawValue >= PuzzleDifficulty.normal.rawValue;
}

/// One world of the puzzle adventure: 10 puzzles in order.
class PuzzleWorld {
  const PuzzleWorld({required this.id, required this.category, required this.puzzleIDs});
  final int id; // 1…10
  final PuzzleCategory category;
  final List<String> puzzleIDs;

  static const puzzlesPerWorld = 10;

  int get firstLevel => (id - 1) * puzzlesPerWorld + 1;
  int get lastLevel => firstLevel + puzzlesPerWorld - 1;
  Iterable<int> get levels => Iterable.generate(puzzlesPerWorld, (i) => firstLevel + i);
  bool containsLevel(int level) => level >= firstLevel && level <= lastLevel;
}

/// Saved progress for one puzzle: best results plus totals over every play.
class PuzzleResult {
  PuzzleResult({
    this.stars = 0,
    this.bestScore = 0,
    this.bestTime = 0,
    this.plays = 0,
    this.totalTime = 0,
    this.totalMoves = 0,
    this.totalWrongPlacements = 0,
    this.totalHints = 0,
  });
  int stars;
  int bestScore;
  double bestTime;
  int plays;
  double totalTime;
  int totalMoves;
  int totalWrongPlacements;
  int totalHints;

  Map<String, dynamic> toJson() => {
        'stars': stars,
        'bestScore': bestScore,
        'bestTime': bestTime,
        'plays': plays,
        'totalTime': totalTime,
        'totalMoves': totalMoves,
        'totalWrongPlacements': totalWrongPlacements,
        'totalHints': totalHints,
      };

  factory PuzzleResult.fromJson(Map<String, dynamic> j) => PuzzleResult(
        stars: j['stars'] as int? ?? 0,
        bestScore: j['bestScore'] as int? ?? 0,
        bestTime: (j['bestTime'] as num?)?.toDouble() ?? 0,
        plays: j['plays'] as int? ?? 0,
        totalTime: (j['totalTime'] as num?)?.toDouble() ?? 0,
        totalMoves: j['totalMoves'] as int? ?? 0,
        totalWrongPlacements: j['totalWrongPlacements'] as int? ?? 0,
        totalHints: j['totalHints'] as int? ?? 0,
      );
}

/// Stats of one play of one puzzle.
class PuzzleRunStats {
  PuzzleRunStats({required this.pieces, this.piecesPlaced = 0, this.moves = 0, this.wrongPlacements = 0, this.hints = 0, this.time = 0});
  int pieces;
  int piecesPlaced;
  int moves;
  int wrongPlacements;
  int hints;
  double time;
}
