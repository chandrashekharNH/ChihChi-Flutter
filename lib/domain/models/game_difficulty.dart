import 'dart:math' as math;

/// How Catch World and Learn Blaster get harder level by level: every next level is a little
/// faster, and barriers arrive and multiply as the child moves up.
class CatchWorldDifficulty {
  /// How fast the pictures drift, in points per second.
  static double speed(int level) => math.min(100 + math.max(1, level) * 9, 290).toDouble();

  /// Pictures on screen: one more every five levels.
  static int objectCount(int level) => math.min(10, 7 + (math.max(1, level) - 1) ~/ 5);

  /// Seconds to find each word: a second less every level.
  static double roundTime(int level) => math.max(30, 46 - math.max(1, level).toDouble());

  /// Drifting clouds and balloons that hide the pictures: none at first, then one more every
  /// four levels.
  static int barrierCount(int level) => level < 3 ? 0 : math.min(5, (level + 1) ~/ 4);

  /// Seconds a barrier takes to cross the screen — lower is faster.
  static double barrierCrossingTime(int level) => math.max(4, 9 - math.max(1, level) * 0.25);
}

class LearnBlasterDifficulty {
  /// Seconds a balloon takes to cross the room — lower is faster.
  static double balloonCrossingTime(int level) => math.max(3.6, 9 - math.max(1, level) * 0.28);

  /// Barriers sliding in front of the balloons: one more every three levels.
  static int barrierCount(int level) => math.min(4, 1 + (math.max(1, level) - 1) ~/ 3);

  /// How much faster the barriers slide than on level 1.
  static double barrierSpeed(int level) => math.min(1.8, 1 + (math.max(1, level) - 1) * 0.04);
}
