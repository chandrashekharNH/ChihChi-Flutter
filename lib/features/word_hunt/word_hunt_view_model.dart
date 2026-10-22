import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../domain/models/app_language.dart';
import '../../domain/models/game_difficulty.dart';
import '../../domain/models/game_engagement.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/reward_type.dart';
import '../../domain/models/world_theme.dart';
import '../../game/engine/living_backdrop.dart';
import '../../game/scenes/word_hunt_scene.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/kids_speech_service.dart';
import '../../services/reward/reward_service.dart';
import '../ar_explorer/ar_hunt_content.dart';
import '../common/wrong_catch_card.dart';

/// Catch World: ten rounds of "find this", three lives, a timer per round.
class WordHuntViewModel extends ChangeNotifier {
  WordHuntViewModel({
    required this.level,
    required this.language,
    required AudioService audioService,
    required RewardService rewardService,
    String childName = '',
    WorldTheme? theme,
  })  : _audio = audioService,
        _rewards = rewardService,
        _speech = KidsSpeechService(childName: childName, isEnabled: () => audioService.voiceEnabled) {
    // The living world behind the game, in the child's chosen world.
    scene.setBackdrop(BackdropStyle.world(theme ?? WorldTheme.enchantedForest));
  }

  final int level;
  final AppLanguage language;
  final AudioService _audio;
  final RewardService _rewards;
  final KidsSpeechService _speech;
  final scene = WordHuntScene();
  final _random = math.Random();

  static const totalRounds = 10;

  GameState gameState = const GameLoading();
  bool get isLevelCompleted => gameState is GameLevelCompleted;
  ARHuntObject? currentTarget;
  List<ARHuntObject> currentObjects = [];
  int score = 0;
  int lives = 3;
  double timeRemaining = 45;
  int roundNumber = 0;
  int streak = 0;
  PlayBoost boost = PlayBoost();
  bool isSlowMotion = false;
  int correctAnswers = 0;
  int questionsAnswered = 0;
  String feedbackMessage = '';

  /// Set after a wrong tap: what was tapped and what the child is looking for.
  WrongCatchNote? wrongCatch;
  List<RewardGrant> sessionRewards = [];
  List<RewardGrant> pendingRewardGrants = [];
  int levelCompleteStars = 0;

  /// Speed, crowding, time and barriers all grow with the level.
  int get objectCount => CatchWorldDifficulty.objectCount(level);
  double get speed => CatchWorldDifficulty.speed(level);
  double get roundTime => CatchWorldDifficulty.roundTime(level);

  /// Level 4+ hides the emoji in the target card.
  bool get showEmojiInTarget => level < 4;

  final Set<String> _used = {};
  Timer? _timer;
  Timer? _flow;
  Timer? _slow;
  bool _disposed = false;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _after(double seconds, VoidCallback f) {
    _flow?.cancel();
    _flow = Timer(Duration(milliseconds: (seconds * 1000).round()), () {
      if (!_disposed) f();
    });
  }

  void startGame() {
    _used.clear();
    score = 0;
    lives = 3;
    timeRemaining = roundTime;
    roundNumber = 0;
    streak = 0;
    boost = PlayBoost();
    _endSlowMotion();
    correctAnswers = 0;
    questionsAnswered = 0;
    feedbackMessage = '';
    sessionRewards = [];
    pendingRewardGrants = [];
    levelCompleteStars = 0;
    _timer?.cancel();
    scene.onObjectTapped = objectTapped;
    scene.onRoundExpired = () {};
    _loadNextRound();
  }

  /// Slows everything down for a few seconds, if a power-up has been earned.
  void useSlowMotion() {
    if (isSlowMotion || !boost.useSlowMotion()) return;
    isSlowMotion = true;
    scene.setSlowMotion(true);
    _audio.playEffect(SoundEffect.rewardPop);
    _slow?.cancel();
    _slow = Timer(Duration(milliseconds: (PlayBoost.slowMotionSeconds * 1000).round()), () {
      _endSlowMotion();
      _changed();
    });
    _changed();
  }

  void _endSlowMotion() {
    _slow?.cancel();
    isSlowMotion = false;
    scene.setSlowMotion(false);
  }

  void cleanup() {
    _endSlowMotion();
    _timer?.cancel();
    _flow?.cancel();
    _speech.stop();
    scene.resetRound();
  }

  @override
  void dispose() {
    _disposed = true;
    cleanup();
    _speech.dispose();
    scene.disposeScene();
    super.dispose();
  }

  /// Says the current word again (e.g. from the speaker button).
  void repeatInstruction() {
    final t = currentTarget;
    if (t != null) _speech.speakWordInstruction(t.localizedName(language), language);
  }

  void _loadNextRound() {
    if (roundNumber >= totalRounds || lives <= 0) {
      _finishLevel();
      return;
    }
    final pool = [...ARHuntContent.easyObjects]..shuffle(_random);
    final target = pool.where((o) => !_used.contains(o.id)).firstOrNull;
    if (target == null) {
      _finishLevel();
      return;
    }
    _used.add(target.id);
    final distractors = pool.where((o) => o.id != target.id).take(objectCount - 1);
    currentTarget = target;
    currentObjects = [target, ...distractors]..shuffle(_random);
    roundNumber += 1;
    timeRemaining = roundTime;
    pendingRewardGrants = [];
    gameState = const GameInstruction();
    scene.configure(
      objects: currentObjects,
      targetID: target.id,
      fallSpeed: speed,
      barrierCount: CatchWorldDifficulty.barrierCount(level),
      barrierCrossingTime: CatchWorldDifficulty.barrierCrossingTime(level),
    );
    repeatInstruction();
    _changed();
    _after(1.8, () {
      if (gameState is! GameInstruction) return;
      gameState = const GamePlaying();
      scene.startRound();
      _startTimer();
      _changed();
    });
  }

  void objectTapped(String id, bool correct) {
    _timer?.cancel();
    wrongCatch = null;
    questionsAnswered += 1;
    if (correct) {
      correctAnswers += 1;
      streak += 1;
      boost.correct();
      score += 10 + streak * 2 + math.max(0, timeRemaining ~/ 9);
      final grants = [..._rewards.rewardsForCorrectAnswer(streak), ..._rewards.rewardsForBoost(boost)];
      pendingRewardGrants = grants;
      sessionRewards.addAll(grants);
      feedbackMessage = _rewards.celebrationMessage(streak, language);
      final name = currentObjects.where((o) => o.id == id).firstOrNull?.localizedName(language) ?? id;
      gameState = GameAnswerCorrect(name);
      _audio.playCorrectFeedback();
      _speech.speakCorrect(name, language);
      _changed();
      _after(1.5, _moveToNextRound);
      return;
    }
    streak = 0;
    boost.wrong();
    lives -= 1;
    feedbackMessage = _rewards.encouragementMessage(language);
    _audio.playWrongFeedback();
    // Name what was tapped and what we want, while the scene lights up the right one.
    final tapped = currentObjects.where((o) => o.id == id).firstOrNull;
    final target = currentTarget;
    if (tapped != null && target != null) {
      wrongCatch = WrongCatchNote(
        WrongCatchLabel(tapped.emoji, tapped.localizedName(language)),
        WrongCatchLabel(target.emoji, target.localizedName(language)),
      );
    }
    if (lives > 0) {
      if (wrongCatch != null) {
        _speech.speakLine(wrongCatch!.spokenLine(language), language);
      } else {
        _speech.speakEncouragement(language);
      }
    } else {
      _speech.speakGameOver(language);
    }
    gameState = const GameAnswerWrong();
    _changed();
    // Leave time to hear the names and look at the highlighted answer.
    _after(wrongCatch == null ? 1.5 : 3.0, _moveToNextRound);
  }

  void _roundExpired() {
    if (gameState is! GamePlaying) return;
    _timer?.cancel();
    wrongCatch = null;
    streak = 0;
    boost.wrong();
    questionsAnswered += 1;
    lives -= 1;
    feedbackMessage = _rewards.encouragementMessage(language);
    _audio.playWrongFeedback();
    if (lives <= 0) {
      _speech.speakGameOver(language);
      gameState = const GameOver();
    } else {
      _speech.speakEncouragement(language);
      gameState = const GameAnswerWrong();
      _after(1.5, _moveToNextRound);
    }
    _changed();
  }

  void _moveToNextRound() {
    scene.resetRound();
    if (lives <= 0) {
      gameState = const GameOver();
      _changed();
      return;
    }
    if (roundNumber >= totalRounds) {
      _finishLevel();
      return;
    }
    _loadNextRound();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      timeRemaining -= 0.1;
      if (timeRemaining <= 0) {
        timeRemaining = 0;
        t.cancel();
        _roundExpired();
      }
      _changed();
    });
  }

  void _finishLevel() {
    _timer?.cancel();
    final stars = _rewards.starsForAccuracy(accuracy);
    sessionRewards.addAll([..._rewards.rewardsForLevelCompletion(level, accuracy, streak), ..._rewards.rewardsForBossLevel(level)]);
    levelCompleteStars = stars;
    _audio.playEffect(SoundEffect.levelComplete);
    _speech.speakLevelComplete(language);
    gameState = GameLevelCompleted(stars, sessionRewards);
    _changed();
  }

  void pauseGame() {
    if (gameState is! GamePlaying) return;
    gameState = const GamePaused();
    _timer?.cancel();
    scene.pauseRound();
    _changed();
  }

  void resumeGame() {
    if (gameState is! GamePaused) return;
    gameState = const GamePlaying();
    scene.resumeRound();
    _startTimer();
    _changed();
  }

  double get accuracy => questionsAnswered > 0 ? correctAnswers / questionsAnswered : 0;
}
