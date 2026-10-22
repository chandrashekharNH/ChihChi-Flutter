import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:chihchi/core/localization/localized.dart';
import 'package:chihchi/data/game_content/language_pack.dart';
import 'package:chihchi/data/puzzle_content/puzzle_library.dart';
import 'package:chihchi/domain/models/app_language.dart';
import 'package:chihchi/domain/models/game_difficulty.dart';
import 'package:chihchi/domain/models/game_engagement.dart';
import 'package:chihchi/domain/models/puzzle_models.dart';
import 'package:chihchi/features/ar_explorer/ar_explorer_content.dart';
import 'package:chihchi/features/ar_explorer/ar_explorer_recognition.dart';
import 'package:chihchi/game/puzzle/puzzle_generator.dart';
import 'package:chihchi/services/progress/progress_service.dart';
import 'package:chihchi/services/reward/reward_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AppTextCatalog.load();
    await LanguagePack.loadAll();
  });

  group('Build the Picture', () {
    test('at least 500 puzzles in every language, unique ids, names everywhere', () {
      for (final language in AppLanguage.values) {
        final all = PuzzleLibrary.all(language);
        expect(all.length, greaterThanOrEqualTo(500), reason: '$language');
        expect(all.map((p) => p.id).toSet().length, all.length);
        for (final p in all) {
          expect(p.name(language), isNotEmpty, reason: p.id);
        }
        for (final category in PuzzleCategory.values) {
          expect(PuzzleLibrary.puzzles(category, language), isNotEmpty, reason: '$category');
        }
      }
    });

    test('100 adventure levels resolve in every language', () {
      for (final language in AppLanguage.values) {
        final worlds = PuzzleLibrary.worlds(language);
        expect(worlds.length, 10);
        for (final w in worlds) {
          expect(w.puzzleIDs.length, PuzzleWorld.puzzlesPerWorld);
        }
        for (var level = 1; level <= PuzzleLibrary.totalLevels; level++) {
          expect(PuzzleLibrary.adventure(level, language), isNotNull, reason: 'level $level $language');
        }
      }
    });

    test('letter puzzles switch to the matching letter in another language', () {
      final english = PuzzleLibrary.puzzles(PuzzleCategory.letters, AppLanguage.english).first;
      final kannada = PuzzleLibrary.equivalent(english, AppLanguage.kannada)!;
      expect(kannada.category, PuzzleCategory.letters);
      expect(kannada.id.startsWith('letter.kn.'), isTrue);
    });

    test('pieces tile the grid and neighbouring edges fit together', () {
      for (final difficulty in PuzzleDifficulty.values) {
        for (final grid in difficulty.grids) {
          final layout = PuzzleGenerator.makeLayout(grid, difficulty);
          expect(layout.pieces.length, grid.pieceCount);
          final byCell = {for (final p in layout.pieces) '${p.row},${p.column}': p};
          for (final p in layout.pieces) {
            if (p.row == 0) expect(p.top, PuzzleEdge.flat);
            if (p.column == 0) expect(p.left, PuzzleEdge.flat);
            if (p.row == grid.rows - 1) expect(p.bottom, PuzzleEdge.flat);
            if (p.column == grid.columns - 1) expect(p.right, PuzzleEdge.flat);
            final right = byCell['${p.row},${p.column + 1}'];
            if (right != null) expect(p.right, right.left.opposite);
            final below = byCell['${p.row + 1},${p.column}'];
            if (below != null) expect(p.bottom, below.top.opposite);
            if (!difficulty.requiresRotation) expect(p.startRotation, 0);
            if (!difficulty.usesJigsawShapes) {
              expect([p.top, p.right, p.bottom, p.left].every((e) => e == PuzzleEdge.flat), isTrue);
            }
          }
          if (difficulty.requiresRotation) {
            expect(layout.pieces.where((p) => p.startRotation != 0).length, greaterThanOrEqualTo(grid.pieceCount ~/ 2));
          }
        }
      }
    });

    test('adventure grids grow through a world and stay within the difficulty', () {
      for (final d in PuzzleDifficulty.values) {
        final counts = [for (var s = 0; s < PuzzleWorld.puzzlesPerWorld; s++) PuzzleGenerator.grid(d, s).pieceCount];
        expect(counts, [...counts]..sort());
        expect(counts.first, d.grids.first.pieceCount);
        expect(counts.last, d.grids.last.pieceCount);
      }
      expect(PuzzleDifficulty.veryEasy.grids.first.pieceCount, 2);
      expect(PuzzleDifficulty.expert.grids.last.pieceCount, 64);
    });

    test('a piece snaps only near its place and turned the right way', () {
      const cell = Size(100, 100), target = Offset(200, 200);
      expect(PuzzleSnapRule.snaps(const Offset(220, 210), target, 0, cell, PuzzleDifficulty.normal), isTrue);
      expect(PuzzleSnapRule.snaps(const Offset(220, 210), target, 1, cell, PuzzleDifficulty.normal), isFalse);
      expect(PuzzleSnapRule.snaps(const Offset(300, 200), target, 0, cell, PuzzleDifficulty.expert), isFalse);
      expect(PuzzleSnapRule.snaps(const Offset(250, 200), target, 4, cell, PuzzleDifficulty.veryEasy), isTrue);
    });

    test('scores stay encouraging; young children always get full marks', () {
      final sloppy = PuzzleRunStats(pieces: 4, wrongPlacements: 20, hints: 5, time: 999);
      expect(PuzzleScoring.stars(sloppy, PuzzleDifficulty.veryEasy), 5);
      expect(PuzzleScoring.score(sloppy, PuzzleDifficulty.easy), 1000);
      expect(PuzzleScoring.stars(sloppy, PuzzleDifficulty.expert), greaterThanOrEqualTo(2));
      expect(PuzzleScoring.score(sloppy, PuzzleDifficulty.expert), inInclusiveRange(100, 1000));
      final perfect = PuzzleRunStats(pieces: 16, piecesPlaced: 16, moves: 16);
      expect(PuzzleScoring.stars(perfect, PuzzleDifficulty.advanced), 5);
      expect(PuzzleScoring.score(perfect, PuzzleDifficulty.advanced), 1000);
    });

    test('adventure levels unlock in order and keep best results', () {
      final service = ProgressService(file: File('${Directory.systemTemp.createTempSync('puzzle').path}/progress.json'));
      expect(service.isPuzzleLevelUnlocked(1), isTrue);
      expect(service.isPuzzleLevelUnlocked(2), isFalse);
      final stats = PuzzleRunStats(pieces: 4, piecesPlaced: 4, moves: 5, time: 30);
      service.recordPuzzle('cat', 1, stats, 3, 700);
      expect(service.isPuzzleLevelUnlocked(2), isTrue);
      expect(service.recordPuzzle('cat', 1, stats, 5, 900), isTrue);
      expect(service.puzzleLevelStars(1), 5);
      expect(service.puzzleResult('cat')?.plays, 2);
      expect(service.puzzleTotals.moves, 10);
    });
  });

  group('Games get harder level by level', () {
    test('Catch World: faster every level, more pictures, less time, more barriers', () {
      for (var l = 2; l <= 20; l++) {
        expect(CatchWorldDifficulty.speed(l), greaterThan(CatchWorldDifficulty.speed(l - 1)));
        expect(CatchWorldDifficulty.objectCount(l), greaterThanOrEqualTo(CatchWorldDifficulty.objectCount(l - 1)));
        expect(CatchWorldDifficulty.roundTime(l), lessThanOrEqualTo(CatchWorldDifficulty.roundTime(l - 1)));
        expect(CatchWorldDifficulty.barrierCount(l), greaterThanOrEqualTo(CatchWorldDifficulty.barrierCount(l - 1)));
      }
      expect(CatchWorldDifficulty.barrierCount(1), 0);
      expect(CatchWorldDifficulty.barrierCount(20), 5);
      expect(CatchWorldDifficulty.speed(20), greaterThan(CatchWorldDifficulty.speed(1) * 2));
      expect(CatchWorldDifficulty.roundTime(99), greaterThanOrEqualTo(30));
    });

    test('Learn Blaster: balloons speed up and barriers multiply', () {
      for (var l = 2; l <= 20; l++) {
        expect(LearnBlasterDifficulty.balloonCrossingTime(l), lessThanOrEqualTo(LearnBlasterDifficulty.balloonCrossingTime(l - 1)));
        expect(LearnBlasterDifficulty.barrierCount(l), greaterThanOrEqualTo(LearnBlasterDifficulty.barrierCount(l - 1)));
      }
      expect(LearnBlasterDifficulty.barrierCount(1), 1);
      expect(LearnBlasterDifficulty.barrierCount(20), 4);
      expect(LearnBlasterDifficulty.balloonCrossingTime(99), greaterThanOrEqualTo(3.6));
    });

    test('three in a row is on fire, five earns a slow-motion, a miss ends the streak', () {
      final boost = PlayBoost();
      expect(boost.isOnFire, isFalse);
      expect(boost.useSlowMotion(), isFalse);
      boost.correct();
      boost.correct();
      expect(boost.isOnFire, isFalse);
      boost.correct();
      expect(boost.isOnFire, isTrue);
      expect(RewardService().rewardsForBoost(boost).map((g) => g.amount), [1]);
      final fourth = boost.correct(), fifth = boost.correct();
      expect(!fourth && fifth, isTrue);
      expect(boost.slowMotionCharges, 1);
      boost.wrong();
      expect(boost.isOnFire, isFalse);
      expect(boost.slowMotionCharges, 1);
      expect(boost.useSlowMotion(), isTrue);
      expect(boost.useSlowMotion(), isFalse);
      for (var i = 0; i < 30; i++) {
        boost.correct();
      }
      expect(boost.slowMotionCharges, PlayBoost.maximumCharges);
    });

    test('every fifth level is a boss level with a bigger prize', () {
      expect([for (var l = 1; l <= 20; l++) if (PlayBoost.isBossLevel(l)) l], [5, 10, 15, 20]);
      expect(RewardService().rewardsForBossLevel(10).map((g) => g.amount), [3]);
      expect(RewardService().rewardsForBossLevel(11), isEmpty);
    });
  });

  group('AR Explorer recognition rules', () {
    final candidates = [for (final o in ARExplorerCatalog.objects) RecognitionCandidate(o.id, o.keywords)];

    test('a clear label is taught; a weak one is only asked about; nothing names nothing', () {
      expect(ARExplorerRecognitionRules.decideLabels([('Cup', 0.85)], candidates).objectID, 'cup');
      expect(ARExplorerRecognitionRules.decideLabels([('Cup', 0.85)], candidates).certainty, RecognitionCertainty.confident);
      expect(ARExplorerRecognitionRules.decideLabels([('Mug', 0.45)], candidates).certainty, RecognitionCertainty.probable);
      expect(ARExplorerRecognitionRules.decideLabels([('Sky', 0.9)], candidates).certainty, RecognitionCertainty.unsure);
    });

    test('a face in the picture is not taught as an object', () {
      final labels = [('Beard', 0.92), ('Dog', 0.62)];
      expect(ARExplorerRecognitionRules.decideLabels(labels, candidates).certainty, isNot(RecognitionCertainty.confident));
      expect(ARExplorerRecognitionRules.pointsElsewhere(labels, candidates), isFalse);
      expect(ARExplorerRecognitionRules.pointsElsewhere([('Beard', 0.92), ('Dog', 0.3)], candidates), isTrue);
    });

    test('two close objects are not taught', () {
      final d = ARExplorerRecognitionRules.decideLabels([('Cup', 0.7), ('Bottle', 0.65)], candidates);
      expect(d.certainty, isNot(RecognitionCertainty.confident));
    });

    test('one clear colour is found; grey or mixed areas are not', () {
      Uint8List fill(List<int> rgb, int n) => Uint8List.fromList([for (var i = 0; i < n; i++) ...[...rgb, 255]]);
      expect(ARExplorerRecognitionRules.dominantColor(fill([230, 30, 40], 100)), ExplorerColor.red);
      expect(ARExplorerRecognitionRules.dominantColor(fill([30, 90, 230], 100)), ExplorerColor.blue);
      expect(ARExplorerRecognitionRules.dominantColor(fill([128, 128, 128], 100)), isNull);
      final mixed = Uint8List.fromList([...fill([230, 30, 40], 50), ...fill([30, 200, 60], 50)]);
      expect(ARExplorerRecognitionRules.dominantColor(mixed), isNull);
    });
  });
}
