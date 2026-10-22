import 'dart:math' as math;

import '../../domain/models/letter_lesson.dart';
import '../../domain/models/level_configuration.dart';

class DifficultyService {
  const DifficultyService();

  LevelConfiguration configuration(int level) => LevelConfiguration.configuration(level);

  /// Selects which lessons appear in a given level. Level 1-5: first 5 letters; 6-10: next 5; etc.
  List<LetterLesson> lessonsForLevel(int level, List<LetterLesson> allLessons) {
    if (allLessons.isEmpty) return [];
    const bucketSize = 5;
    final start = (math.max(0, level - 1) ~/ bucketSize) * bucketSize;
    if (start >= allLessons.length) return ([...allLessons]..shuffle()).take(bucketSize).toList();
    return allLessons.sublist(start, math.min(start + bucketSize, allLessons.length));
  }
}
