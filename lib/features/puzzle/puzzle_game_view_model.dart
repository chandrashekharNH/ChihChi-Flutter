import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/puzzle_content/puzzle_library.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/puzzle_models.dart';
import '../../domain/models/reward_type.dart';
import '../../domain/models/ui_text.dart';
import '../../domain/models/world_theme.dart';
import '../../game/engine/living_backdrop.dart';
import '../../game/puzzle/puzzle_art_renderer.dart';
import '../../game/puzzle/puzzle_generator.dart';
import '../../game/scenes/puzzle_scene.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/fun_sound_player.dart';
import '../../services/audio/fun_sound_synth.dart';
import '../../services/audio/kids_speech_service.dart';
import '../../services/progress/progress_service.dart';

enum PuzzlePhase { loading, preview, playing, completed }

class PuzzleCompletion {
  const PuzzleCompletion(this.stars, this.score, this.stats);
  final int stars;
  final int score;
  final PuzzleRunStats stats;
}

class PuzzleSavedResult {
  const PuzzleSavedResult(this.isNewBest, this.isGrandFinale);
  final bool isNewBest;

  /// True when this finished the last adventure level and every level is done.
  final bool isGrandFinale;
}

/// Rules and flow for one "Build the Picture" puzzle. The scene renders and reports moves; this
/// counts them, scores the result and drives voice, sound and haptics.
class PuzzleGameViewModel extends ChangeNotifier {
  PuzzleGameViewModel({
    required this.puzzle,
    required this.level,
    required this.difficulty,
    required this.language,
    required AudioService audioService,
    required String childName,
    required bool hapticsEnabled,
    required bool reduceMotion,
    WorldTheme? theme,
  })  : _audio = audioService,
        _speech = KidsSpeechService(childName: childName),
        _haptics = hapticsEnabled,
        _reduceMotion = reduceMotion,
        grid = PuzzleGenerator.grid(difficulty, level == null ? null : (level - 1) % PuzzleWorld.puzzlesPerWorld) {
    stats = PuzzleRunStats(pieces: grid.pieceCount);
    // The living world behind the board, in the child's chosen world; still if motion is reduced.
    scene.setBackdrop(BackdropStyle.world(theme ?? WorldTheme.enchantedForest), animates: !reduceMotion);
  }

  final PuzzleDefinition puzzle;
  final PuzzleDifficulty difficulty;

  /// Adventure level (1…100), or null in free play.
  final int? level;
  final PuzzleGrid grid;
  AppLanguage language;
  final AudioService _audio;
  final KidsSpeechService _speech;
  final _sounds = FunSoundPlayer();
  final bool _haptics;
  final bool _reduceMotion;
  final scene = PuzzleScene();

  PuzzlePhase phase = PuzzlePhase.loading;
  late PuzzleRunStats stats;
  PuzzleCompletion? completion;

  /// Finished picture, for the "look" button and the scorecard.
  PuzzleArt? art;
  Timer? _timer;
  DateTime? _playStart;
  bool _disposed = false;
  int _token = 0;

  String get name => puzzle.name(language);
  bool get canRotate => difficulty.requiresRotation;
  double get targetTime => PuzzleScoring.targetTime(grid.pieceCount, difficulty);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    stop();
    final token = ++_token;
    phase = PuzzlePhase.loading;
    stats = PuzzleRunStats(pieces: grid.pieceCount);
    completion = null;
    _wireScene();
    _changed();
    final wordText = language == AppLanguage.english ? name.toUpperCase() : name;
    final prepared = await PuzzleArtRenderer.render(puzzle.subject, wordText);
    final layout = PuzzleGenerator.makeLayout(grid, difficulty);
    final pieces = await PuzzleArtRenderer.pieceArt(prepared.full, layout);
    if (_disposed || token != _token) return;
    art = prepared;
    scene.configure(PuzzleSetup(
      art: prepared,
      layout: layout,
      pieces: pieces,
      pieceScale: PuzzleArtRenderer.pieceScale(prepared.full, layout),
      difficulty: difficulty,
      reduceMotion: _reduceMotion,
    ));
    phase = PuzzlePhase.preview;
    _speak(name);
    _changed();
    scene.playIntro(1.6, _beginPlaying);
  }

  void stop() {
    _timer?.cancel();
    _speech.stop();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    _speech.dispose();
    _sounds.stop();
    scene.disposeScene();
    super.dispose();
  }

  void _beginPlaying() {
    phase = PuzzlePhase.playing;
    _playStart = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final start = _playStart;
      if (start == null || phase != PuzzlePhase.playing) return;
      stats.time = DateTime.now().difference(start).inMilliseconds / 1000;
      _changed();
    });
    _changed();
  }

  // Controls

  void hint() {
    if (phase != PuzzlePhase.playing || !scene.showHint()) return;
    stats.hints += 1;
    _play(FunSound.whoosh);
    _haptic(HapticFeedback.lightImpact);
    _changed();
  }

  void rotate() {
    if (phase != PuzzlePhase.playing || !canRotate || !scene.rotateSelectedPiece()) return;
    _play(FunSound.squeak);
    _haptic(HapticFeedback.lightImpact);
  }

  /// New language: the name, voice and text follow it straight away.
  void setLanguage(AppLanguage newLanguage) {
    if (newLanguage == language) return;
    language = newLanguage;
    if (phase == PuzzlePhase.preview || phase == PuzzlePhase.playing) _speak(name);
    _changed();
  }

  void _wireScene() {
    scene.onLift = () {
      _play(FunSound.pop);
      _haptic(HapticFeedback.lightImpact);
    };
    scene.onMove = () {
      stats.moves += 1;
      _changed();
    };
    scene.onPlaced = (remaining) {
      stats.piecesPlaced = grid.pieceCount - remaining;
      _play(remaining == 0 ? FunSound.tada : FunSound.pop);
      _audio.playEffect(SoundEffect.correct);
      _haptic(HapticFeedback.mediumImpact);
      _changed();
    };
    scene.onWrongDrop = () {
      stats.wrongPlacements += 1;
      _play(FunSound.boing);
      _haptic(HapticFeedback.selectionClick);
      _changed();
    };
    scene.onComplete = _finish;
  }

  void _finish() {
    _timer?.cancel();
    final start = _playStart;
    if (start != null) stats.time = DateTime.now().difference(start).inMilliseconds / 1000;
    completion = PuzzleCompletion(PuzzleScoring.stars(stats, difficulty), PuzzleScoring.score(stats, difficulty), stats);
    phase = PuzzlePhase.completed;
    _audio.playEffect(SoundEffect.levelComplete);
    _play(FunSound.fanfare);
    _haptic(HapticFeedback.heavyImpact);
    _speak('${UIText.sayAmazing.resolve(language)} $name!');
    _changed();
  }

  /// Saves the finished puzzle (best results, adventure stars, reward stars).
  PuzzleSavedResult? saveResult(ProgressService store) {
    final c = completion;
    if (c == null) return null;
    final isNewBest = store.recordPuzzle(puzzle.id, level, c.stats, c.stars, c.score);
    store.applyRewards([RewardGrant(type: RewardType.star, amount: c.stars, reason: 'Puzzle complete')]);
    var allDone = true;
    for (var l = 1; l <= PuzzleLibrary.totalLevels; l++) {
      if (store.puzzleLevelStars(l) == null) {
        allDone = false;
        break;
      }
    }
    return PuzzleSavedResult(isNewBest, level == PuzzleLibrary.totalLevels && allDone);
  }

  /// The only place the child's name is used: finishing every adventure puzzle.
  void celebrateGrandFinale(String childName) => _speak(UIText.sayGrandFinale(childName).resolve(language));

  void _speak(String line) {
    if (_audio.voiceEnabled) _speech.speakLine(line, language);
  }

  void _play(FunSound sound) {
    if (_audio.soundEnabled) _sounds.play(sound);
  }

  void _haptic(Future<void> Function() feedback) {
    if (_haptics) feedback();
  }
}
