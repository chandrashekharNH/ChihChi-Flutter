import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../data/game_content/run_collect_content.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/game_difficulty.dart';
import '../../domain/models/game_engagement.dart';
import '../../domain/models/reward_type.dart';
import '../../domain/models/run_collect.dart';
import '../../game/scenes/learn_blaster_scene.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/fun_sound_player.dart';
import '../../services/audio/fun_sound_synth.dart';
import '../../services/audio/kids_speech_service.dart';
import '../../services/progress/progress_service.dart';
import '../../services/reward/reward_service.dart';
import '../common/wrong_catch_card.dart';

sealed class BlasterFeedback {
  const BlasterFeedback();
}

class BlasterCorrect extends BlasterFeedback {
  const BlasterCorrect(this.message);
  final String message;
}

class BlasterTryAgain extends BlasterFeedback {
  const BlasterTryAgain(this.message);
  final String message;
}

class BlasterFunny extends BlasterFeedback {
  const BlasterFunny(this.message);
  final String message;
}

/// A wrong balloon: what was hit and what we are looking for.
class BlasterLearn extends BlasterFeedback {
  const BlasterLearn(this.note);
  final WrongCatchNote note;
}

/// Game rules for Learn Blaster: balloons with letters, words or objects float across a playroom
/// and the child shoots the one that matches the prompt.
class LearnBlasterViewModel extends ChangeNotifier {
  LearnBlasterViewModel({
    required this.level,
    required this.language,
    required RewardService rewardService,
    required AudioService audioService,
    String childName = '',
  })  : _rewards = rewardService,
        _audio = audioService,
        _speech = KidsSpeechService(childName: childName, isEnabled: () => audioService.voiceEnabled) {
    final config = RunCollectLevelConfig.configuration(level);
    mode = config.mode;
    totalRounds = math.min(config.roundCount, 10);
    _distractorCount = config.distractorCount;
    _crossing = LearnBlasterDifficulty.balloonCrossingTime(level);
    scene.onFire = fire;
  }

  final int level;
  final AppLanguage language;
  late final RunCollectTargetMode mode;
  late final int totalRounds;
  final RewardService _rewards;
  final AudioService _audio;
  final KidsSpeechService _speech;
  final _sounds = FunSoundPlayer();
  final scene = LearnBlasterScene();
  late final int _distractorCount;
  late final double _crossing;
  final _random = math.Random();

  /// Stars once the level is done; null while playing.
  int? completedStars;
  bool get isLevelCompleted => completedStars != null;
  RunCollectTarget? currentTarget;
  int round = 0;
  int score = 0;
  int streak = 0;
  PlayBoost boost = PlayBoost();
  bool isSlowMotion = false;
  int correctAnswers = 0;
  int wrongShots = 0;
  BlasterFeedback? feedback;
  List<RewardGrant> sessionRewards = [];

  List<RunCollectTarget> _pool = [];
  List<RunCollectTarget> _roundTargets = [];
  bool _accepting = false;
  bool _disposed = false;
  final List<Timer> _timers = [];
  Timer? _feedbackTimer;
  Timer? _slowTimer;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _after(double seconds, VoidCallback action) {
    late final Timer t;
    t = Timer(Duration(milliseconds: (seconds * 1000).round()), () {
      _timers.remove(t);
      if (!_disposed) action();
    });
    _timers.add(t);
  }

  // Prompt

  String get promptText {
    final t = currentTarget;
    if (t == null) return '';
    return mode == RunCollectTargetMode.letter ? t.localizedSymbol(language) : t.localizedName(language);
  }

  String? get promptHint {
    final t = currentTarget;
    if (t == null || mode != RunCollectTargetMode.letter) return null;
    return '${t.emoji} ${t.localizedName(language)}';
  }

  bool get showsShootTip => round == 1 && correctAnswers == 0 && wrongShots == 0;

  // Flow

  void start() {
    stop();
    _pool = RunCollectContent.targets(language, mode).where((t) => t.difficulty <= (level < 6 ? 1 : 2)).toList()..shuffle(_random);
    round = 0;
    score = 0;
    streak = 0;
    boost = PlayBoost();
    _endSlowMotion();
    correctAnswers = 0;
    wrongShots = 0;
    sessionRewards = [];
    feedback = null;
    completedStars = null;
    _startRound();
  }

  /// Saves this level's rewards, completion and answers.
  void saveResults(ProgressService store) {
    store.applyRewards(sessionRewards);
    store.completeLevel(level);
    store.recordAnswers(correctAnswers, wrongShots);
  }

  void useSlowMotion() {
    if (isSlowMotion || !boost.useSlowMotion()) return;
    isSlowMotion = true;
    scene.setSlowMotion(true);
    _audio.playEffect(SoundEffect.rewardPop);
    _slowTimer?.cancel();
    _slowTimer = Timer(Duration(milliseconds: (PlayBoost.slowMotionSeconds * 1000).round()), () {
      _endSlowMotion();
      _changed();
    });
    _changed();
  }

  void _endSlowMotion() {
    _slowTimer?.cancel();
    isSlowMotion = false;
    scene.setSlowMotion(false);
  }

  void stop() {
    _endSlowMotion();
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _feedbackTimer?.cancel();
    _accepting = false;
    _speech.stop();
    _sounds.stop();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    _speech.dispose();
    scene.disposeScene();
    super.dispose();
  }

  void repeatInstruction() => _speakInstruction();

  void fire() {
    final target = currentTarget;
    if (isLevelCompleted || !_accepting || target == null) return;
    final shot = scene.shotAtAim();
    scene.fire(shot);
    _audio.playEffect(SoundEffect.buttonTap);
    _play(FunSound.pew);
    switch (shot.hit) {
      case HitTarget(:final id) when id == target.id:
        _correctHit(target);
      case HitTarget(:final id):
        _wrongHit(id, target);
      case HitToy(:final id):
        _after(0.16, () {
          scene.reactToy(id);
          _play(_toySound(id));
        });
        _showFeedback(const BlasterFunny('😂'));
      case HitNothing():
        break;
    }
  }

  void _startRound() {
    if (round >= totalRounds || _pool.isEmpty) {
      _finishLevel();
      return;
    }
    round += 1;
    final target = _pool[(round - 1) % _pool.length];
    currentTarget = target;
    final distractors = RunCollectContent.distractors(target, language, mode, _distractorCount, _random);
    _roundTargets = [target, ...distractors];
    scene.showTargets(([..._roundTargets]..shuffle(_random)).map(_face).toList(), _crossing);
    scene.showsTip = showsShootTip;
    _speakInstruction();
    _accepting = true;
    _changed();
  }

  void _correctHit(RunCollectTarget target) {
    _accepting = false;
    correctAnswers += 1;
    streak += 1;
    boost.correct();
    score += 10;
    sessionRewards.addAll([..._rewards.rewardsForCorrectAnswer(streak), ..._rewards.rewardsForBoost(boost)]);
    _showFeedback(BlasterCorrect(_rewards.celebrationMessage(streak, language)));
    scene.showsTip = false;
    _after(0.16, () {
      scene.popTarget(target.id);
      _audio.playCorrectFeedback();
      _play(FunSound.pop);
      _after(0.12, () {
        _play(streak % 3 == 0 ? FunSound.giggle : FunSound.tada);
        _speech.speakCorrect(target.localizedName(language), language);
        _after(1.5, () {
          scene.clearTargets();
          _after(0.3, _startRound);
        });
      });
    });
    _changed();
  }

  void _wrongHit(String hitID, RunCollectTarget target) {
    wrongShots += 1;
    streak = 0;
    boost.wrong();
    scene.showsTip = false;
    _audio.playWrongFeedback();
    // Name what was hit and what we want, and light up the right balloon, so a miss still teaches.
    final hit = _roundTargets.where((t) => t.id == hitID).firstOrNull;
    if (hit != null) {
      final note = WrongCatchNote(_label(hit), _label(target));
      _showFeedback(BlasterLearn(note), 2.8);
      _speech.speakLine(note.spokenLine(language), language);
    } else {
      _showFeedback(BlasterTryAgain(_rewards.encouragementMessage(language)));
      _speech.speakEncouragement(language);
    }
    _after(0.16, () {
      scene.wobbleTarget(hitID);
      _play(FunSound.wahWah);
      scene.highlightTarget(target.id);
    });
    _changed();
  }

  void _finishLevel() {
    _accepting = false;
    scene.clearTargets();
    currentTarget = null;
    final shots = correctAnswers + wrongShots;
    final accuracy = shots > 0 ? correctAnswers / shots : 0.0;
    _endSlowMotion();
    sessionRewards.addAll([..._rewards.rewardsForLevelCompletion(level, accuracy, streak), ..._rewards.rewardsForBossLevel(level)]);
    _speech.speakLevelComplete(language);
    _audio.playEffect(SoundEffect.levelComplete);
    _play(FunSound.fanfare);
    completedStars = _rewards.starsForAccuracy(accuracy);
    _changed();
  }

  // Helpers

  LearnBlasterTargetFace _face(RunCollectTarget t) {
    switch (mode) {
      case RunCollectTargetMode.letter:
        return LearnBlasterTargetFace(id: t.id, title: t.localizedSymbol(language));
      case RunCollectTargetMode.word:
        return LearnBlasterTargetFace(id: t.id, title: t.localizedName(language), emoji: t.emoji);
      case RunCollectTargetMode.object:
        return LearnBlasterTargetFace(id: t.id, emoji: t.emoji);
    }
  }

  WrongCatchLabel _label(RunCollectTarget t) {
    if (mode == RunCollectTargetMode.letter) {
      final symbol = t.localizedSymbol(language);
      return WrongCatchLabel(symbol, symbol);
    }
    return WrongCatchLabel(t.emoji, t.localizedName(language));
  }

  static FunSound _toySound(String id) => switch (id) {
        'car' => FunSound.honk,
        'duck' => FunSound.squeak,
        'plane' => FunSound.whoosh,
        _ => FunSound.boing,
      };

  void _speakInstruction() {
    final t = currentTarget;
    if (t == null) return;
    final name = t.localizedName(language);
    if (mode == RunCollectTargetMode.letter) {
      _speech.speakLetterInstruction(t.localizedSymbol(language), name, language);
    } else {
      _speech.speakWordInstruction(name, language, action: SpeechAction.pop);
    }
  }

  void _play(FunSound sound) {
    if (_audio.soundEnabled) _sounds.play(sound);
  }

  void _showFeedback(BlasterFeedback f, [double seconds = 1.3]) {
    feedback = f;
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(Duration(milliseconds: (seconds * 1000).round()), () {
      feedback = null;
      _changed();
    });
    _changed();
  }
}
