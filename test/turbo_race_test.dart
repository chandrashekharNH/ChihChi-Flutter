import 'dart:io';
import 'dart:math' as math;

import 'package:chihchi/core/localization/localized.dart';
import 'package:chihchi/data/game_content/language_pack.dart';
import 'package:chihchi/domain/models/app_language.dart';
import 'package:chihchi/features/turbo_race/turbo_race_content.dart';
import 'package:chihchi/features/turbo_race/turbo_race_learning.dart';
import 'package:chihchi/features/turbo_race/turbo_race_progress_store.dart';
import 'package:chihchi/features/turbo_race/turbo_race_simulation.dart';
import 'package:chihchi/features/turbo_race/turbo_track.dart';
import 'package:flutter_test/flutter_test.dart';

/// Always returns the same number, like the iOS tests' `{ 0.5 }` random source.
class _Fixed implements math.Random {
  _Fixed(this.value);
  final double value;
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => math.min(max - 1, (value * max).floor());
  @override
  bool nextBool() => value >= 0.5;
}

/// The iOS balance tests' repeatable generator (64-bit LCG), so both apps race the same rivals.
class _Seeded implements math.Random {
  _Seeded(int seed) : _state = seed * 6364136223846793005 + 1442695040888963407;
  int _state;
  @override
  double nextDouble() {
    _state = _state * 6364136223846793005 + 1442695040888963407;
    return (_state >>> 11) / 9007199254740992.0;
  }

  @override
  int nextInt(int max) => (nextDouble() * max).floor() % max;
  @override
  bool nextBool() => nextDouble() < 0.5;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AppTextCatalog.load();
    await LanguagePack.loadAll();
  });

  group('Turbo Race track', () {
    test('the centre line is a closed loop and right is perpendicular to forward', () {
      final track = TurboTrack(TurboRaceCatalog.race(1)!.controlPoints);
      expect(track.length, greaterThan(400));
      expect(track.centre(0).distanceTo(track.centre(track.length)), lessThan(0.01));
      final f = track.forward(100), r = track.right(100);
      expect(f.dot(r).abs(), lessThan(0.001));
      expect((track.wrap(-5) - (track.length - 5)).abs(), lessThan(0.001));
    });
  });

  group('Turbo Race learning gates', () {
    test('every gate offers distinct choices with exactly one answer', () {
      for (final kind in TurboChallengeKind.values) {
        for (final choices in const [2, 3]) {
          final maker = TurboChallengeMaker(kind, choices, AppLanguage.english);
          for (var gate = 0; gate < 10; gate++) {
            final c = maker.challenge(gate);
            expect(c.options.length, choices);
            expect(c.correctIndex, inInclusiveRange(0, choices - 1));
            expect(c.options.map((o) => o.spokenName).toSet().length, choices);
          }
        }
      }
    });

    test("a wrong 'starts with' gate teaches the word's first letter", () {
      final maker = TurboChallengeMaker(TurboChallengeKind.mixed, 3, AppLanguage.english, _Fixed(0));
      final c = maker.challenge(4);
      final q = c.question;
      expect(q, isA<LetterStarting>());
      expect(c.teachingLine(1, AppLanguage.english),
          "${(q as LetterStarting).word} starts with ${c.answer.spokenName}. Let's try the next one!");
    });
  });

  group('Turbo Race simulation', () {
    (TurboRaceSimulation, List<TurboEvent>) drive(TurboRaceDefinition race, double steer) {
      final sim = TurboRaceSimulation(race, _Fixed(0.5))..start();
      final events = <TurboEvent>[];
      for (var i = 0; i < 60 * 60 * 5 && sim.isRunning; i++) {
        events.addAll(sim.step(1 / 60, steer, true));
      }
      return (sim, events);
    }

    test('holding straight on reaches the finish with a lap time for every lap', () {
      final race = TurboRaceCatalog.race(1)!;
      final (sim, events) = drive(race, 0);
      final finishes = events.whereType<RaceFinished>().toList();
      expect(finishes.length, 1);
      expect(finishes.first.position, inInclusiveRange(1, race.rivals + 1));
      expect(sim.lapTimes.length, race.laps);
      expect(events.whereType<GatePassed>().length, race.totalGates);
    });

    test('steering hard right goes through the right-hand gate choice', () {
      final race = TurboRaceCatalog.race(2)!;
      final (_, events) = drive(race, 1);
      final choices = events.whereType<GatePassed>().map((e) => e.choice).toList();
      expect(choices, isNotEmpty);
      expect(choices.every((c) => c == race.gateChoices - 1), isTrue);
    });

    test('three correct gates fill the boost meter', () {
      final sim = TurboRaceSimulation(TurboRaceCatalog.race(1)!)..start();
      expect(sim.fireBoost(), isFalse);
      for (var i = 0; i < 3; i++) {
        sim.applyGateResult(true);
      }
      expect(sim.fireBoost(), isTrue);
      expect(sim.boostsUsed, 1);
    });
  });

  group('Turbo Race progress', () {
    test('results keep the best stars and time, and finishing opens the next race', () {
      final dir = Directory.systemTemp.createTempSync('turbo');
      final store = TurboRaceProgressStore(directory: dir);
      expect(store.progress.isUnlocked(1), isTrue);
      expect(store.progress.isUnlocked(2), isFalse);
      store.record(1, 3, 80, 38, 2);
      store.record(1, 1, 75, 40, 4);
      final r = store.progress.results[1]!;
      expect(r.stars, 3);
      expect(r.bestTime, 75);
      expect(r.bestLap, 38);
      expect(r.bestPosition, 2);
      expect(store.progress.isUnlocked(2), isTrue);
      expect(store.progress.nextRace, 2);
      final reloaded = TurboRaceProgressStore(directory: dir).progress.results[1]!;
      expect((reloaded.stars, reloaded.bestTime, reloaded.bestLap, reloaded.bestPosition), (3, 75.0, 38.0, 2));
    });

    test('finishing race 5 arrives at Sunny City', () {
      final store = TurboRaceProgressStore(directory: Directory.systemTemp.createTempSync('turbo'));
      expect(store.progress.currentDestination, TurboDestination.home);
      for (var race = 1; race <= 5; race++) {
        store.record(race, 1, 90, null, 3);
      }
      expect(store.progress.currentDestination, TurboDestination.sunnyCity);
      expect(store.progress.isUnlocked(6), isFalse); // route 2 is not built yet
    });
  });

  // Simulated drivers race every built race, so the balance stays honest: doing nothing loses,
  // just holding is a mid-pack finish, and good driving with learning wins.
  group('Turbo Race balance', () {
    double steerToward(double target, double lateral) => ((target - lateral) / 2.5).clamp(-1.0, 1.0);

    double goodTarget(TurboRaceSimulation sim, Map<int, int> intended, bool usesPads) {
      final progress = sim.player.progress;
      final index = sim.gates.indexWhere((g) => !g.isPassed);
      if (index >= 0 && sim.gates[index].progress - progress < TurboRaceSimulation.announceDistance) {
        final slots = TurboRaceSimulation.optionOffsets(sim.gates[index].optionCount);
        final choice = intended.putIfAbsent(index, () => index % slots.length);
        return slots[choice];
      }
      final lap = sim.track.wrap(progress);
      if (usesPads) {
        final pad = sim.boostPads.where((p) => p.distance > lap && p.distance - lap < 60).firstOrNull;
        if (pad != null) return pad.lateral;
      }
      return 0;
    }

    (int?, int, double) run(int number, String driver, int seed) {
      final race = TurboRaceCatalog.race(number)!;
      final sim = TurboRaceSimulation(race, _Seeded(seed))..start();
      var samples = 0, close = 0;
      final intended = <int, int>{};
      final learns = driver == 'good' || driver == 'learns';
      for (var tick = 0; tick < 60 * 60 * 6 && sim.isRunning; tick++) {
        final steer = learns ? steerToward(goodTarget(sim, intended, driver == 'good'), sim.player.lateral) : 0.0;
        for (final e in sim.step(1 / 60, steer, driver != 'idle')) {
          if (e is GatePassed) sim.applyGateResult(learns && e.choice == intended[e.index]);
        }
        if (driver == 'good' && sim.boostMeter >= 0.99) sim.fireBoost();
        if (tick % 30 == 0 && sim.elapsed > 8) {
          samples++;
          final nearest = sim.cars.skip(1).map((c) => (c.progress - sim.player.progress).abs()).reduce(math.min);
          if (nearest < 40) close++;
        }
        if (driver == 'idle' && sim.cars.skip(1).every((c) => c.finishTime != null)) break;
      }
      final position = sim.finishPosition ?? (driver == 'idle' ? sim.playerPosition : null);
      return (position, sim.cars.length, samples == 0 ? 0 : close / samples);
    }

    // iOS races in 32-bit floats and Dart in 64-bit, so single seeds play out differently; the
    // balance is checked over 20 seeds instead.
    const seeds = 20;
    List<(int?, int, double)> runAll(int race, String driver) => [for (var s = 1; s <= seeds; s++) run(race, driver, s)];

    for (var race = 1; race <= 5; race++) {
      test('race $race: doing nothing finishes last', () {
        for (final (position, racers, _) in runAll(race, 'idle')) {
          expect(position, racers);
        }
      });
      test('race $race: just holding is mid-pack (never last, almost never first)', () {
        final results = runAll(race, 'holds');
        expect(results.every((r) => r.$1 != null && r.$1! < r.$2), isTrue);
        expect(results.where((r) => r.$1 == 1).length, lessThanOrEqualTo(1));
      });
      test('race $race: holding and getting the gates right is top three nearly every time', () {
        final results = runAll(race, 'learns');
        expect(results.where((r) => r.$1 != null && r.$1! <= 3).length, greaterThanOrEqualTo(seeds * 0.85));
      });
      test('race $race: good driving with learning wins, with rivals close by', () {
        final results = runAll(race, 'good');
        expect(results.where((r) => r.$1 == 1).length, greaterThanOrEqualTo(seeds * 0.85));
        expect(results.map((r) => r.$3).reduce((a, b) => a + b) / seeds, greaterThanOrEqualTo(0.5));
      });
    }
  });
}
