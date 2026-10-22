import 'dart:math' as math;

import '../../core/localization/content_names.dart';
import 'app_language.dart';

enum RunCollectTargetMode { letter, word, object }

enum RunCollectWorld {
  enchantedForest('enchanted_forest', 'Enchanted Forest', '🌳'),
  colorfulCity('colorful_city', 'Colorful City', '🏙️'),
  iceKingdom('ice_kingdom', 'Ice Kingdom', '❄️'),
  candyLand('candy_land', 'Candy Land', '🍭'),
  spaceWorld('space_world', 'Space World', '🚀'),
  oceanWorld('ocean_world', 'Ocean World', '🌊'),
  dinosaurWorld('dinosaur_world', 'Dinosaur World', '🦖'),
  magicKingdom('magic_kingdom', 'Magic Kingdom', '🏰');

  const RunCollectWorld(this.rawValue, this.title, this.emoji);
  final String rawValue;
  final String title;
  final String emoji;
}

class RunCollectTarget {
  const RunCollectTarget({
    required this.id,
    required this.symbol,
    required this.emoji,
    required this.englishName,
    required this.kannadaName,
    required this.hindiName,
    required this.mode,
    this.associatedLetter,
    required this.difficulty,
    this.ownName,
  });

  final String id;
  final String symbol;
  final String emoji;
  final String englishName;
  final String kannadaName;
  final String hindiName;
  final RunCollectTargetMode mode;
  final String? associatedLetter;
  final int difficulty;

  /// The word in the letter's own language, for letters that come from a language pack.
  final String? ownName;

  String localizedName(AppLanguage language) {
    if (ownName != null) return ownName!;
    return ContentNames.name(
        key: ContentNames.objectKey(englishName),
        english: englishName,
        kannada: kannadaName,
        hindi: hindiName,
        language: language);
  }

  String localizedSymbol(AppLanguage language) => symbol;

  @override
  bool operator ==(Object other) => other is RunCollectTarget && other.id == id && other.symbol == symbol;
  @override
  int get hashCode => Object.hash(id, symbol);
}

class RunCollectLevelConfig {
  const RunCollectLevelConfig({
    required this.level,
    required this.world,
    required this.mode,
    required this.roundCount,
    required this.targetCount,
    required this.distractorCount,
    required this.obstacleCount,
    required this.baseSpeed,
    required this.timeLimit,
    required this.allowJump,
    required this.allowSlide,
    required this.movingObstacles,
    required this.targetDisplaySeconds,
  });

  final int level;
  final RunCollectWorld world;
  final RunCollectTargetMode mode;
  final int roundCount;
  final int targetCount;
  final int distractorCount;
  final int obstacleCount;
  final double baseSpeed;
  final double timeLimit;
  final bool allowJump;
  final bool allowSlide;
  final bool movingObstacles;
  final double targetDisplaySeconds;

  static RunCollectLevelConfig configuration(int level) {
    final safeLevel = math.max(1, level);
    final RunCollectWorld world;
    if (safeLevel <= 5) {
      world = RunCollectWorld.enchantedForest;
    } else if (safeLevel <= 8) {
      world = RunCollectWorld.colorfulCity;
    } else if (safeLevel <= 11) {
      world = RunCollectWorld.iceKingdom;
    } else if (safeLevel <= 14) {
      world = RunCollectWorld.candyLand;
    } else if (safeLevel <= 17) {
      world = RunCollectWorld.spaceWorld;
    } else if (safeLevel <= 20) {
      world = RunCollectWorld.oceanWorld;
    } else if (safeLevel <= 24) {
      world = RunCollectWorld.dinosaurWorld;
    } else {
      world = RunCollectWorld.magicKingdom;
    }
    final mode = safeLevel <= 4
        ? RunCollectTargetMode.letter
        : safeLevel <= 8
            ? RunCollectTargetMode.word
            : RunCollectTargetMode.object;
    return RunCollectLevelConfig(
      level: safeLevel,
      world: world,
      mode: mode,
      roundCount: math.min(12, 7 + safeLevel ~/ 3),
      targetCount: 1,
      distractorCount: math.min(4, 2 + safeLevel ~/ 5),
      obstacleCount: math.min(5, math.max(0, safeLevel - 1) ~/ 2),
      baseSpeed: math.min(285, 155 + (safeLevel - 1) * 7).toDouble(),
      timeLimit: math.max(12, 25 - (safeLevel ~/ 4)).toDouble(),
      allowJump: safeLevel >= 3,
      allowSlide: safeLevel >= 7,
      movingObstacles: safeLevel >= 12,
      targetDisplaySeconds: safeLevel < 5 ? 2.2 : 1.8,
    );
  }
}
