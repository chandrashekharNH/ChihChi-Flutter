import 'dart:math' as math;

class LevelConfiguration {
  const LevelConfiguration({
    required this.level,
    required this.objectCount,
    required this.fallSpeed,
    required this.minimumObjectScale,
    required this.maximumObjectScale,
    required this.spawnInterval,
    required this.timeLimit,
    required this.distractorCount,
    required this.multipleTargets,
    required this.questionsPerLevel,
  });

  final int level;
  final int objectCount;
  final double fallSpeed;
  final double minimumObjectScale;
  final double maximumObjectScale;
  final double spawnInterval;
  final double? timeLimit;
  final int distractorCount;
  final bool multipleTargets;
  final int questionsPerLevel;

  static LevelConfiguration configuration(int level) {
    switch (level) {
      case 1:
        return const LevelConfiguration(level: 1, objectCount: 7, fallSpeed: 140, minimumObjectScale: 1.0,
            maximumObjectScale: 1.0, spawnInterval: 2.5, timeLimit: 180, distractorCount: 2,
            multipleTargets: false, questionsPerLevel: 5);
      case 2:
        return const LevelConfiguration(level: 2, objectCount: 7, fallSpeed: 160, minimumObjectScale: 0.95,
            maximumObjectScale: 1.0, spawnInterval: 2.2, timeLimit: 180, distractorCount: 2,
            multipleTargets: false, questionsPerLevel: 6);
      case 3:
        return const LevelConfiguration(level: 3, objectCount: 8, fallSpeed: 180, minimumObjectScale: 0.9,
            maximumObjectScale: 1.0, spawnInterval: 2.0, timeLimit: 175, distractorCount: 3,
            multipleTargets: false, questionsPerLevel: 6);
      case 4:
        return const LevelConfiguration(level: 4, objectCount: 8, fallSpeed: 200, minimumObjectScale: 0.85,
            maximumObjectScale: 1.0, spawnInterval: 1.8, timeLimit: 170, distractorCount: 3,
            multipleTargets: false, questionsPerLevel: 7);
      case 5:
        return const LevelConfiguration(level: 5, objectCount: 9, fallSpeed: 220, minimumObjectScale: 0.85,
            maximumObjectScale: 1.0, spawnInterval: 1.7, timeLimit: 165, distractorCount: 4,
            multipleTargets: false, questionsPerLevel: 7);
      default:
        final extra = level - 5;
        return LevelConfiguration(
          level: level,
          objectCount: math.min(9 + extra ~/ 2, 10),
          fallSpeed: math.min(220.0 + extra * 12.0, 340.0),
          minimumObjectScale: math.max(0.7, 0.85 - extra * 0.02),
          maximumObjectScale: 1.0,
          spawnInterval: math.max(1.2, 1.7 - extra * 0.05),
          timeLimit: math.max(120.0, 165.0 - extra * 3.0),
          distractorCount: math.min(4 + extra ~/ 3, 6),
          multipleTargets: level >= 15,
          questionsPerLevel: math.min(7 + extra ~/ 3, 10),
        );
    }
  }
}
