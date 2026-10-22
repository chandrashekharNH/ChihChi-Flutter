import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../services/progress/child_profile_files.dart';
import 'turbo_race_content.dart';

/// A race's best result so far.
class TurboRaceResult {
  const TurboRaceResult({required this.stars, required this.bestTime, this.bestLap, required this.bestPosition});
  final int stars;
  final double bestTime;
  final double? bestLap;
  final int bestPosition;

  factory TurboRaceResult.fromJson(Map<String, dynamic> j) => TurboRaceResult(
        stars: (j['stars'] as num?)?.toInt() ?? 1,
        bestTime: (j['bestTime'] as num?)?.toDouble() ?? 0,
        bestLap: (j['bestLap'] as num?)?.toDouble(),
        bestPosition: (j['bestPosition'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toJson() =>
      {'stars': stars, 'bestTime': bestTime, if (bestLap != null) 'bestLap': bestLap, 'bestPosition': bestPosition};
}

/// Everything Turbo Race remembers, saved as one small JSON file on this device (like AR Explorer).
/// Rewards still go through `ProgressService`.
class TurboRaceProgress {
  Map<int, TurboRaceResult> results = {};

  /// Correct learning gates per kind ("letters", "colors", …), for the parent's view later.
  Map<String, int> correctGates = {};
  int boostsUsed = 0;

  TurboRaceProgress();

  /// Missing keys fall back to defaults, so older files still load.
  factory TurboRaceProgress.fromJson(Map<String, dynamic> j) {
    final p = TurboRaceProgress();
    final results = j['results'];
    if (results is Map) {
      for (final e in results.entries) {
        final n = int.tryParse('${e.key}');
        if (n != null && e.value is Map) p.results[n] = TurboRaceResult.fromJson(Map<String, dynamic>.from(e.value as Map));
      }
    }
    final gates = j['correctGates'];
    if (gates is Map) p.correctGates = {for (final e in gates.entries) '${e.key}': (e.value as num).toInt()};
    p.boostsUsed = (j['boostsUsed'] as num?)?.toInt() ?? 0;
    return p;
  }

  Map<String, dynamic> toJson() => {
        'results': {for (final e in results.entries) '${e.key}': e.value.toJson()},
        'correctGates': correctGates,
        'boostsUsed': boostsUsed,
      };

  /// Race 1 is always open; finishing a race (any stars) opens the next one that is built.
  bool isUnlocked(int number) {
    if (TurboRaceCatalog.race(number) == null) return false;
    return number == 1 || results[number - 1] != null;
  }

  bool isCompleted(int number) => results[number] != null;

  /// The first race not yet finished (where ChihChi's car waits on the map).
  int get nextRace =>
      TurboRaceCatalog.races.map((r) => r.number).where((n) => results[n] == null).firstOrNull ??
      (TurboRaceCatalog.races.lastOrNull?.number ?? 1);

  /// The furthest destination reached: its route's last race is finished.
  TurboDestination get currentDestination =>
      TurboDestination.values.lastWhere((d) => d.raceNumbers.isEmpty || results[d.raceNumbers.last] != null,
          orElse: () => TurboDestination.home);

  int get totalStars => results.values.fold(0, (sum, r) => sum + r.stars);
}

class TurboRaceProgressStore extends ChangeNotifier {
  TurboRaceProgressStore({Directory? directory})
      : _file = File('${(directory ?? ChildProfileFiles.activeDirectory).path}/turbo-race-progress.json') {
    progress = _load(_file);
  }

  final File _file;
  late TurboRaceProgress progress;

  /// Keeps the best of each measure, so a slower replay never loses a star or a best time.
  void record(int number, int stars, double time, double? bestLap, int position) => _update((p) {
        final old = p.results[number];
        final laps = [old?.bestLap, bestLap].whereType<double>();
        p.results[number] = TurboRaceResult(
          stars: math.max(old?.stars ?? 0, stars.clamp(1, 3)),
          bestTime: math.min(old?.bestTime ?? time, time),
          bestLap: laps.isEmpty ? null : laps.reduce(math.min),
          bestPosition: math.min(old?.bestPosition ?? position, position),
        );
      });

  void recordLearning(Map<String, int> correctGates, int boostsUsed) => _update((p) {
        for (final e in correctGates.entries) {
          p.correctGates[e.key] = (p.correctGates[e.key] ?? 0) + e.value;
        }
        p.boostsUsed += boostsUsed;
      });

  void _update(void Function(TurboRaceProgress) change) {
    change(progress);
    notifyListeners();
    try {
      _file.parent.createSync(recursive: true);
      _file.writeAsStringSync(jsonEncode(progress.toJson()), flush: true);
    } catch (_) {
      // Progress stays in memory for this session; the game keeps working.
    }
  }

  static TurboRaceProgress _load(File file) {
    try {
      if (!file.existsSync()) return TurboRaceProgress();
      final decoded = jsonDecode(file.readAsStringSync());
      return decoded is Map<String, dynamic> ? TurboRaceProgress.fromJson(decoded) : TurboRaceProgress();
    } catch (_) {
      return TurboRaceProgress();
    }
  }
}
