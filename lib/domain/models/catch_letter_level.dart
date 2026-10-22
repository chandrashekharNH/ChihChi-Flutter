import 'dart:math' as math;
import 'dart:ui';

import '../../core/ui/palette.dart';
import 'level_configuration.dart';

/// How a Catch Letter question is built. Every mode keeps the letter as the thing to catch.
enum CatchLetterMode {
  singleLetter,
  letterGroup,
  letterNumber,
  letterObject,
  animal,
  color,
  shape,
  colorShape,

  /// Plain coloured bubbles, no letter: "Catch blue".
  plainColor,
  nature,
  space,
  city,
  memory,
  mixedMastery,
}

/// One 5-level world of the Catch Letter adventure.
enum CatchLetterBatch {
  firstAdventure,
  lettersAndNumbers,
  lettersAndObjects,
  animalWorld,
  colorsAndShapes,
  natureWorld,
  spaceWorld,
  cityAdventure,
  memoryChallenge,
  chihchiMaster;

  static const levelsPerBatch = 5;

  int get rawValue => index + 1;
  int get firstLevel => (rawValue - 1) * levelsPerBatch + 1;
  int get lastLevel => firstLevel + levelsPerBatch - 1;
  Iterable<int> get levels => Iterable.generate(levelsPerBatch, (i) => firstLevel + i);
  bool containsLevel(int level) => level >= firstLevel && level <= lastLevel;
  CatchLetterBatch? get next => rawValue < values.length ? values[rawValue] : null;

  static CatchLetterBatch? fromRaw(int raw) => raw >= 1 && raw <= values.length ? values[raw - 1] : null;

  static CatchLetterBatch containing(int level) {
    final index = (math.max(1, math.min(level, CatchLetterLevels.totalLevels)) - 1) ~/ levelsPerBatch + 1;
    return fromRaw(index) ?? CatchLetterBatch.firstAdventure;
  }

  String get icon => const ['🌱', '🔢', '🍎', '🐯', '🌈', '🌳', '🚀', '🏙️', '🧠', '👑'][index];

  List<Color> get gradient {
    switch (this) {
      case CatchLetterBatch.firstAdventure:
        return [rgb(0.36, 0.78, 0.42), rgb(0.12, 0.52, 0.3)];
      case CatchLetterBatch.lettersAndNumbers:
        return [rgb(0.36, 0.62, 1.0), rgb(0.2, 0.3, 0.75)];
      case CatchLetterBatch.lettersAndObjects:
        return [rgb(1.0, 0.55, 0.4), rgb(0.85, 0.25, 0.35)];
      case CatchLetterBatch.animalWorld:
        return [rgb(0.55, 0.75, 0.2), rgb(0.2, 0.45, 0.15)];
      case CatchLetterBatch.colorsAndShapes:
        return [rgb(1.0, 0.5, 0.75), rgb(0.55, 0.35, 0.95)];
      case CatchLetterBatch.natureWorld:
        return [rgb(0.4, 0.8, 0.6), rgb(0.1, 0.5, 0.45)];
      case CatchLetterBatch.spaceWorld:
        return [rgb(0.2, 0.2, 0.5), rgb(0.04, 0.04, 0.18)];
      case CatchLetterBatch.cityAdventure:
        return [rgb(1.0, 0.72, 0.3), rgb(0.4, 0.45, 0.6)];
      case CatchLetterBatch.memoryChallenge:
        return [rgb(0.55, 0.3, 0.8), rgb(0.2, 0.1, 0.4)];
      case CatchLetterBatch.chihchiMaster:
        return [rgb(1.0, 0.8, 0.2), rgb(0.85, 0.4, 0.1)];
    }
  }

  /// Base colour for the game backdrop.
  Color get sceneColor {
    switch (this) {
      case CatchLetterBatch.firstAdventure:
        return rgb(0.12, 0.5, 0.25);
      case CatchLetterBatch.lettersAndNumbers:
        return rgb(0.12, 0.22, 0.6);
      case CatchLetterBatch.lettersAndObjects:
        return rgb(0.6, 0.2, 0.25);
      case CatchLetterBatch.animalWorld:
        return rgb(0.2, 0.42, 0.12);
      case CatchLetterBatch.colorsAndShapes:
        return rgb(0.42, 0.22, 0.62);
      case CatchLetterBatch.natureWorld:
        return rgb(0.08, 0.42, 0.36);
      case CatchLetterBatch.spaceWorld:
        return rgb(0.04, 0.04, 0.2);
      case CatchLetterBatch.cityAdventure:
        return rgb(0.3, 0.33, 0.46);
      case CatchLetterBatch.memoryChallenge:
        return rgb(0.22, 0.1, 0.4);
      case CatchLetterBatch.chihchiMaster:
        return rgb(0.55, 0.3, 0.08);
    }
  }

  /// Soft floating decoration in the game backdrop.
  List<String> get ambientEmojis => const [
        ['🌱', '🌼', '☁️'],
        ['🔢', '✏️', '📏'],
        ['🍎', '⚽', '🎈'],
        ['🌴', '🐒', '🦜'],
        ['🌈', '🔺', '🟣'],
        ['🌳', '🌸', '🦋'],
        ['⭐', '🪐', '✨'],
        ['🏢', '🚦', '☁️'],
        ['❓', '🔮', '✨'],
        ['👑', '🏆', '✨'],
      ][index];

  /// Big things that drift in front of the bubbles and partly hide them (taps pass through).
  List<String> get barrierEmojis => const [
        ['☁️', '🌳', '🌼'],
        ['☁️', '🌳', '🌼'],
        ['☁️', '🎈', '📦'],
        ['🌴', '🌿', '🪨'],
        ['☁️', '🌈', '🎨'],
        ['🌳', '🌿', '☁️'],
        ['🪐', '☄️', '🌑'],
        ['🚌', '🏢', '☁️'],
        ['🔮', '☁️', '🌫️'],
        ['☁️', '🏆', '🌳'],
      ][index];

  /// Non-letter things that float among the letters in themed worlds.
  List<String> get decoyEmojis {
    switch (this) {
      case CatchLetterBatch.natureWorld:
        return const ['🌳', '🌸', '☀️', '🌙', '☁️', '🐟', '🍄', '🦋'];
      case CatchLetterBatch.spaceWorld:
        return const ['🚀', '⭐', '🪐', '🌙', '👽', '☄️', '🛸', '🌍'];
      case CatchLetterBatch.cityAdventure:
        return const ['🏙️', '🚗', '🚌', '🚦', '🏪', '🚕', '🚲', '🏠'];
      default:
        return const ['⭐', '🎈', '🌸', '🚗', '🐟', '🪐', '🍄', '🚌'];
    }
  }
}

/// An inclusive integer range (Swift `ClosedRange<Int>`).
class IntRange {
  const IntRange(this.lower, this.upper);
  final int lower;
  final int upper;
  bool contains(int v) => v >= lower && v <= upper;
  List<int> toList() => [for (var i = lower; i <= upper; i++) i];
}

/// Everything that makes one Catch Letter level different. Built by `CatchLetterLevels`.
class CatchLetterLevelDefinition {
  const CatchLetterLevelDefinition({
    required this.level,
    required this.batch,
    required this.mode,
    required this.letterIndices,
    required this.numbers,
    required this.animalStart,
    required this.animalEnd,
    required this.questionCount,
    required this.distractorCount,
    required this.barrierCount,
    required this.barrierCrossingTime,
    required this.targetScale,
    required this.distractorScaleMin,
    required this.distractorScaleMax,
    required this.movementSpeed,
    required this.spawnInterval,
    required this.timeLimit,
    required this.memorizeSeconds,
  });

  final int level;
  final CatchLetterBatch batch;
  final CatchLetterMode mode;

  /// Target letters, as positions in the selected language's alphabet.
  final List<int> letterIndices;

  /// Numbers mixed in as distractors (letter + number modes).
  final IntRange? numbers;

  /// Which animal lessons to use (animal mode), `animalStart..<animalEnd`.
  final int? animalStart;
  final int? animalEnd;
  bool get hasAnimalRange => animalStart != null && animalEnd != null;

  final int questionCount;
  final int distractorCount;

  /// Drifting obstacles that partly cover the bubbles.
  final int barrierCount;

  /// Seconds a barrier takes to drift across the screen — lower is faster.
  final double barrierCrossingTime;
  final double targetScale;
  final double distractorScaleMin;
  final double distractorScaleMax;
  final double movementSpeed;
  final double spawnInterval;
  final double timeLimit;

  /// How long the letter is shown before it hides (memory questions only).
  final double memorizeSeconds;

  bool get usesMemoryChallenge => mode == CatchLetterMode.memory;
  bool get usesMixedContent => mode == CatchLetterMode.mixedMastery;
  int get levelInBatch => level - batch.firstLevel + 1;
  bool get isBatchFinale => level == batch.lastLevel;

  LevelConfiguration get levelConfiguration => LevelConfiguration(
        level: level,
        objectCount: distractorCount + 1,
        fallSpeed: movementSpeed,
        minimumObjectScale: distractorScaleMin,
        maximumObjectScale: distractorScaleMax,
        spawnInterval: spawnInterval,
        timeLimit: timeLimit,
        distractorCount: distractorCount,
        multipleTargets: false,
        questionsPerLevel: questionCount,
      );
}

class _Blueprint {
  const _Blueprint(this.mode, {this.letters = const [], this.numbers, this.animals});
  final CatchLetterMode mode;
  final List<int> letters;
  final IntRange? numbers;

  /// [start, end) of the animal lessons.
  final List<int>? animals;
}

List<int> _range(int a, int b) => [for (var i = a; i <= b; i++) i];

class CatchLetterLevels {
  static const totalLevels = 50;

  static final List<int> _allLetters = List.generate(30, (i) => i);

  /// What each level teaches, in order. Difficulty numbers are computed separately.
  static final List<_Blueprint> _blueprints = [
    // Batch 1 — My First Adventure
    const _Blueprint(CatchLetterMode.singleLetter, letters: [0]),
    const _Blueprint(CatchLetterMode.singleLetter, letters: [1]),
    const _Blueprint(CatchLetterMode.letterGroup, letters: [0, 1]),
    const _Blueprint(CatchLetterMode.singleLetter, letters: [2]),
    const _Blueprint(CatchLetterMode.letterGroup, letters: [0, 1, 2]),
    // Batch 2 — Letters + Numbers
    const _Blueprint(CatchLetterMode.letterNumber, letters: [3], numbers: IntRange(1, 2)),
    const _Blueprint(CatchLetterMode.letterNumber, letters: [4], numbers: IntRange(1, 3)),
    const _Blueprint(CatchLetterMode.letterNumber, letters: [3, 4], numbers: IntRange(1, 4)),
    const _Blueprint(CatchLetterMode.letterNumber, letters: [5], numbers: IntRange(1, 5)),
    const _Blueprint(CatchLetterMode.letterNumber, letters: [3, 4, 5], numbers: IntRange(1, 9)),
    // Batch 3 — Letters + Objects
    const _Blueprint(CatchLetterMode.letterObject, letters: [6, 7]),
    const _Blueprint(CatchLetterMode.letterObject, letters: [8, 9]),
    const _Blueprint(CatchLetterMode.letterObject, letters: [6, 7, 8, 9]),
    const _Blueprint(CatchLetterMode.letterObject, letters: [10, 11]),
    _Blueprint(CatchLetterMode.letterObject, letters: _range(6, 11)),
    // Batch 4 — Animal World
    const _Blueprint(CatchLetterMode.animal, animals: [0, 2]),
    const _Blueprint(CatchLetterMode.animal, animals: [2, 4]),
    const _Blueprint(CatchLetterMode.animal, animals: [0, 4]),
    const _Blueprint(CatchLetterMode.animal, animals: [4, 6]),
    const _Blueprint(CatchLetterMode.animal, animals: [0, 6]),
    // Batch 5 — Colors & Shapes
    const _Blueprint(CatchLetterMode.color, letters: [12, 13]),
    _Blueprint(CatchLetterMode.color, letters: _range(12, 15)),
    const _Blueprint(CatchLetterMode.shape, letters: [12, 13]),
    _Blueprint(CatchLetterMode.shape, letters: _range(12, 15)),
    _Blueprint(CatchLetterMode.colorShape, letters: _range(12, 15)),
    // Batch 6 — Nature World
    const _Blueprint(CatchLetterMode.nature, letters: [16]),
    const _Blueprint(CatchLetterMode.nature, letters: [17]),
    const _Blueprint(CatchLetterMode.nature, letters: [16, 17]),
    const _Blueprint(CatchLetterMode.nature, letters: [18]),
    const _Blueprint(CatchLetterMode.nature, letters: [16, 17, 18]),
    // Batch 7 — Space World
    const _Blueprint(CatchLetterMode.space, letters: [19]),
    const _Blueprint(CatchLetterMode.space, letters: [20]),
    const _Blueprint(CatchLetterMode.space, letters: [19, 20]),
    const _Blueprint(CatchLetterMode.space, letters: [21]),
    const _Blueprint(CatchLetterMode.space, letters: [19, 20, 21]),
    // Batch 8 — City Adventure
    const _Blueprint(CatchLetterMode.city, letters: [22]),
    const _Blueprint(CatchLetterMode.city, letters: [23]),
    const _Blueprint(CatchLetterMode.city, letters: [22, 23]),
    const _Blueprint(CatchLetterMode.city, letters: [24, 25]),
    _Blueprint(CatchLetterMode.city, letters: _range(22, 25)),
    // Batch 9 — Memory Challenge
    _Blueprint(CatchLetterMode.memory, letters: _range(0, 5)),
    _Blueprint(CatchLetterMode.memory, letters: _range(0, 11)),
    _Blueprint(CatchLetterMode.memory, letters: _range(6, 17)),
    _Blueprint(CatchLetterMode.memory, letters: _range(12, 25)),
    _Blueprint(CatchLetterMode.memory, letters: _allLetters),
    // Batch 10 — ChihChi Master
    _Blueprint(CatchLetterMode.letterNumber, letters: _allLetters, numbers: const IntRange(1, 9)),
    _Blueprint(CatchLetterMode.letterObject, letters: _allLetters),
    const _Blueprint(CatchLetterMode.animal, animals: [0, 100]),
    _Blueprint(CatchLetterMode.memory, letters: _allLetters),
    _Blueprint(CatchLetterMode.mixedMastery, letters: _allLetters, numbers: const IntRange(1, 9), animals: const [0, 100]),
  ];

  static CatchLetterLevelDefinition definition(int requested) {
    final level = math.max(1, math.min(requested, totalLevels));
    final blueprint = _blueprints[level - 1];
    final batch = CatchLetterBatch.containing(level);
    final world = batch.rawValue - 1; // 0...9
    final step = level - batch.firstLevel; // 0...4

    final questionCount = world == 0 ? const [4, 5, 5, 6, 6][step] : math.min(10, 6 + world ~/ 3 + (step >= 3 ? 1 : 0));
    var distractorCount = world == 0 ? const [4, 4, 5, 5, 6][step] : math.min(8, 5 + world ~/ 3 + step ~/ 2);
    if (blueprint.mode == CatchLetterMode.memory) distractorCount = math.min(distractorCount, 4 + step);
    final progress = (level - 1).toDouble();
    final barrierCount = math.min(8, 1 + (level - 1) ~/ 5);
    final barrierCrossingTime = math.max(3.5, 9.0 - progress * 0.11);

    final targetScale =
        world == 0 ? const [1.3, 1.3, 1.2, 1.2, 1.1][step] : math.max(0.92, 1.1 - 0.02 * world - 0.01 * step);
    final smallest = math.max(0.74, 0.95 - 0.025 * world - 0.01 * step);
    final speed = 100.0 + progress * 3.6;

    final double memorizeSeconds;
    switch (level) {
      case 41:
        memorizeSeconds = 3.5;
      case 42:
        memorizeSeconds = 3.0;
      case 43:
        memorizeSeconds = 2.6;
      case 44:
        memorizeSeconds = 2.3;
      case 45:
        memorizeSeconds = 2.0;
      case 49:
        memorizeSeconds = 1.8;
      default:
        memorizeSeconds = 2.5;
    }

    return CatchLetterLevelDefinition(
      level: level,
      batch: batch,
      mode: blueprint.mode,
      letterIndices: blueprint.letters,
      numbers: blueprint.numbers,
      animalStart: blueprint.animals?[0],
      animalEnd: blueprint.animals?[1],
      questionCount: questionCount,
      distractorCount: distractorCount,
      barrierCount: barrierCount,
      barrierCrossingTime: barrierCrossingTime,
      targetScale: targetScale,
      distractorScaleMin: smallest,
      distractorScaleMax: 1.0,
      movementSpeed: math.min(speed, 280),
      spawnInterval: math.max(1.2, 2.5 - world * 0.12),
      timeLimit: 60,
      memorizeSeconds: memorizeSeconds,
    );
  }
}

enum CatchLetterColor {
  red(0.93, 0.2, 0.22, '🔴'),
  blue(0.16, 0.45, 0.95, '🔵'),
  green(0.18, 0.7, 0.3, '🟢'),
  yellow(0.98, 0.78, 0.1, '🟡'),
  purple(0.6, 0.3, 0.9, '🟣');

  const CatchLetterColor(this.r, this.g, this.b, this.swatch);
  final double r, g, b;
  final String swatch;
  Color get color => rgb(r, g, b);
}

enum CatchLetterShape {
  circle('⚪️'),
  star('⭐'),
  triangle('🔺'),
  square('🟧');

  const CatchLetterShape(this.icon);
  final String icon;
}
