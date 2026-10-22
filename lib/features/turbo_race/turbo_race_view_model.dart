import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/app_language.dart';
import '../../domain/models/reward_type.dart';
import '../../game/scenes/turbo_race_scene.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/fun_sound_player.dart';
import '../../services/audio/fun_sound_synth.dart';
import '../../services/audio/kids_speech_service.dart';
import '../../services/progress/progress_service.dart';
import '../../services/reward/reward_service.dart';
import 'turbo_race_content.dart';
import 'turbo_race_learning.dart';
import 'turbo_race_progress_store.dart';
import 'turbo_race_simulation.dart';
import 'turbo_race_text.dart';

enum TurboPhase { intro, countdown, racing, paused, finished }

enum TurboFeedbackKind { boost, learn, info }

class TurboFeedback {
  const TurboFeedback(this.kind, this.text);
  final TurboFeedbackKind kind;
  final String text;
}

class TurboRaceOutcome {
  const TurboRaceOutcome({
    required this.position,
    required this.racers,
    required this.time,
    required this.bestLap,
    required this.gatesCorrect,
    required this.totalGates,
    required this.starGoals,
    required this.rewards,
    required this.finishOrder,
  });
  final int position;
  final int racers;
  final double time;
  final double? bestLap;
  final int gatesCorrect;
  final int totalGates;

  /// Finish, learning goal, bonus goal.
  final List<bool> starGoals;
  final List<RewardGrant> rewards;

  /// Car indices in finishing order (car 0 is the player).
  final List<int> finishOrder;

  int get stars => starGoals.where((g) => g).length;
}

/// Runs one Turbo Race: intro camera, countdown, the frame loop, learning gates, rewards and
/// results. The rules are in `TurboRaceSimulation`; drawing is in `TurboRaceScene`.
class TurboRaceViewModel extends ChangeNotifier {
  TurboRaceViewModel({
    required this.race,
    required this.language,
    required AudioService audioService,
    required RewardService rewardService,
    required String childName,
    required bool usesOwnCharacter,
  })  : _audio = audioService,
        _rewards = rewardService,
        playerName = usesOwnCharacter && childName.isNotEmpty ? childName : TurboRacer.forCar(0).name(language),
        _speech = KidsSpeechService(childName: childName, isEnabled: () => audioService.voiceEnabled),
        _maker = TurboChallengeMaker(race.learning, race.gateChoices, language) {
    simulation = TurboRaceSimulation(race);
    scene = TurboRaceScene(race, simulation, language)..onFrame = _tick;
  }

  final TurboRaceDefinition race;
  final AppLanguage language;

  /// The child's name when they drive as their own character, else ChihChi's.
  final String playerName;
  late final TurboRaceSimulation simulation;
  late final TurboRaceScene scene;
  final AudioService _audio;
  final RewardService _rewards;
  final KidsSpeechService _speech;
  final TurboChallengeMaker _maker;
  final _sounds = FunSoundPlayer();

  // HUD state
  TurboPhase phase = TurboPhase.intro;
  int countdown = 3;
  int position = 1;
  int lap = 1;
  int speed = 0;
  double boostMeter = 0;
  bool isBoosting = false;
  String? banner;
  TurboFeedback? feedback;
  int starsCollected = 0;
  int gatesCorrect = 0;
  bool hasSteered = false;
  bool isHolding = false;
  bool showsHoldHint = false;
  bool showsGo = false;
  List<int> standings = [];
  TurboRaceOutcome? result;

  double _steer = 0;
  bool _throttle = false;
  double _phaseTime = 0;
  double _hudTime = 0;
  final Map<int, TurboChallenge> _challenges = {};
  int _wrongGates = 0;
  final Map<String, int> _correctByKind = {};
  double _idleTime = 0;
  double _lastPassCallout = -10;
  Timer? _feedbackTimer;
  Timer? _goTimer;
  Timer? _finishTimer;
  bool _disposed = false;

  static const _introSeconds = 3.2;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  // Lifecycle

  void start() {
    phase = TurboPhase.intro;
    _phaseTime = 0;
    scene.introMode = true;
    _speech.speakLine(TurboRaceText.goingTo(race.destination.name(language)).resolve(language), language);
    _changed();
  }

  void stop() {
    _feedbackTimer?.cancel();
    _goTimer?.cancel();
    _finishTimer?.cancel();
    _speech.stop();
    _sounds.stop();
    scene.isPaused = true;
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    _speech.dispose();
    scene.disposeScene();
    super.dispose();
  }

  void pause() {
    if (phase != TurboPhase.racing && phase != TurboPhase.intro && phase != TurboPhase.countdown) return;
    simulation.pause();
    phase = TurboPhase.paused;
    scene.isPaused = true;
    _changed();
  }

  void resume() {
    if (phase != TurboPhase.paused) return;
    scene.isPaused = false;
    scene.introMode = false;
    // Resume straight into a short countdown so the child is ready.
    phase = TurboPhase.countdown;
    countdown = 3;
    _phaseTime = 0;
    _changed();
  }

  // Input

  /// A finger went down (drive) or lifted (coast).
  void setHolding(bool held) {
    _throttle = held;
    if (isHolding != held) {
      isHolding = held;
      _changed();
    }
    if (held) _idleTime = 0;
  }

  /// −1 … 1 from the drag gesture.
  void setSteer(double value) {
    _steer = value.clamp(-1.0, 1.0);
    scene.steer = _steer;
    if (value.abs() > 0.2 && !hasSteered) {
      hasSteered = true;
      _changed();
    }
  }

  void fireBoost() {
    if (phase != TurboPhase.racing || !simulation.fireBoost()) return;
    boostMeter = 0;
    _play(FunSound.whoosh);
    _showFeedback(TurboFeedback(TurboFeedbackKind.boost, TurboRaceText.boostShout.resolve(language)), 1.2);
  }

  // Frame loop (driven by the scene's clock)

  void _tick(double dt) {
    _phaseTime += dt;
    switch (phase) {
      case TurboPhase.intro:
        scene.introProgress = _phaseTime / _introSeconds;
        if (_phaseTime >= _introSeconds) _beginCountdown();
      case TurboPhase.countdown:
        scene.introMode = false;
        _setHint(!_throttle);
        if (_phaseTime >= 1) {
          _phaseTime = 0;
          if (countdown > 1) {
            countdown -= 1;
            _play(FunSound.pop);
          } else {
            phase = TurboPhase.racing;
            simulation.start();
            showsGo = true;
            _goTimer = Timer(const Duration(milliseconds: 900), () {
              showsGo = false;
              _changed();
            });
            _speech.speakLine(TurboRaceText.go.resolve(language), language);
            _play(FunSound.tada);
          }
          _changed();
        }
      case TurboPhase.racing:
        final events = simulation.step(dt, _steer, _throttle);
        _idleTime = _throttle ? 0 : _idleTime + dt;
        _setHint(_idleTime > 1);
        events.forEach(_handle);
        _hudTime += dt;
        if (_hudTime >= 0.1) {
          _hudTime = 0;
          _refreshHUD();
        }
      case TurboPhase.paused:
      case TurboPhase.finished:
        break;
    }
  }

  void _setHint(bool value) {
    if (showsHoldHint == value) return;
    showsHoldHint = value;
    _changed();
  }

  void _beginCountdown() {
    phase = TurboPhase.countdown;
    countdown = 3;
    _phaseTime = 0;
    _speech.speakLine(TurboRaceText.ready.resolve(language), language);
    _play(FunSound.pop);
    _changed();
  }

  void _refreshHUD() {
    final player = simulation.player;
    position = simulation.playerPosition;
    lap = simulation.playerLap;
    speed = (player.speed * 3.6 * 1.3).round();
    boostMeter = simulation.boostMeter;
    isBoosting = player.boostTime > 0;
    standings = simulation.standings;
    _changed();
  }

  // Events

  void _handle(TurboEvent event) {
    switch (event) {
      case GateAhead(:final index):
        final challenge = _maker.challenge(index);
        _challenges[index] = challenge;
        scene.showGate(index, simulation.gates[index].progress, challenge);
        banner = challenge.banner(language);
        _speech.speakLine(challenge.spokenPrompt(language), language);
        _changed();
      case GatePassed(:final index, :final choice):
        final challenge = _challenges[index];
        if (challenge == null) return;
        final correct = choice == challenge.correctIndex;
        simulation.applyGateResult(correct);
        scene.resolveGate(index, choice, challenge.correctIndex);
        banner = null;
        if (correct) {
          gatesCorrect += 1;
          final key = _kindKey(challenge);
          _correctByKind[key] = (_correctByKind[key] ?? 0) + 1;
          _play(FunSound.tada);
          _audio.playCorrectFeedback();
          _showFeedback(TurboFeedback(TurboFeedbackKind.boost, TurboRaceText.boostShout.resolve(language)), 1.2);
          _speech.speakPraise(language);
        } else {
          _wrongGates += 1;
          _play(FunSound.boing);
          // Never harsh: name the right answer, a small slowdown, and on we go.
          final line = challenge.teachingLine(choice, language);
          _showFeedback(TurboFeedback(TurboFeedbackKind.learn, line), 2.6);
          _speech.speakLine(line, language);
        }
      case StarCollected(:final index):
        starsCollected += 1;
        scene.collectPickup(index);
        _play(FunSound.pop);
        _changed();
      case BoostPadHit():
        _play(FunSound.whoosh);
      case LapStarted(lap: final newLap):
        if (newLap == race.laps) {
          _showFeedback(TurboFeedback(TurboFeedbackKind.info, '🏁 ${TurboRaceText.finalLap.resolve(language)}'), 1.6);
          _speech.speakLine(TurboRaceText.finalLap.resolve(language), language);
        }
      case Bump():
        _play(FunSound.boing);
        _showFeedback(TurboFeedback(TurboFeedbackKind.info, '💥 ${TurboRaceText.oops.resolve(language)}'), 0.9);
      case RivalOops(:final car):
        final racer = TurboRacer.forCar(car);
        if (feedback == null) {
          _showFeedback(
              TurboFeedback(TurboFeedbackKind.info, '${racer.face} ${racer.name(language)}: ${TurboRaceText.oops.resolve(language)}'), 1.4);
        }
      case Overtook(:final car):
        final racer = TurboRacer.forCar(car);
        if (simulation.playerPosition == 1) {
          // Taking the lead is the big moment: always said out loud.
          _lastPassCallout = simulation.elapsed;
          _play(FunSound.whoosh);
          _showFeedback(TurboFeedback(TurboFeedbackKind.boost, '🥇 ${TurboRaceText.youLead.resolve(language)}'), 1.4);
          _speech.speakLine(TurboRaceText.youLead.resolve(language), language);
        } else if (simulation.elapsed - _lastPassCallout > 1.5) {
          _lastPassCallout = simulation.elapsed;
          _showFeedback(
              TurboFeedback(TurboFeedbackKind.boost, '🎉 ${TurboRaceText.youPassed('${racer.face} ${racer.name(language)}').resolve(language)}'), 1.2);
        }
      case OvertakenBy(:final car):
        if (simulation.elapsed - _lastPassCallout <= 1.5 || feedback != null) return;
        _lastPassCallout = simulation.elapsed;
        final racer = TurboRacer.forCar(car);
        _showFeedback(TurboFeedback(TurboFeedbackKind.info, TurboRaceText.passedYou('${racer.face} ${racer.name(language)}').resolve(language)), 1.2);
      case RivalFinished(:final car, :final place):
        // The winner crossing the line while the child is still racing: cheer them on.
        if (place != 1) return;
        final racer = TurboRacer.forCar(car);
        final line = TurboRaceText.rivalWon(racer.name(language)).resolve(language);
        _showFeedback(TurboFeedback(TurboFeedbackKind.info, '🏁 ${racer.face} $line'), 2);
        _speech.speakLine(line, language);
      case RaceFinished(position: final place):
        _finish(place);
    }
  }

  void _finish(int place) {
    _refreshHUD();
    banner = null;
    final bonusMet = switch (race.bonus) {
      BonusCollectStars(:final count) => starsCollected >= count,
      BonusFinishTopThree() => place <= 3,
      BonusUseBoost(:final count) => simulation.boostsUsed >= count,
      BonusNoWrongGates() => _wrongGates == 0,
      BonusWin() => place == 1,
    };
    final goals = [true, gatesCorrect >= race.learningGoal, bonusMet];
    final stars = goals.where((g) => g).length;
    result = TurboRaceOutcome(
      position: place,
      racers: simulation.cars.length,
      time: simulation.elapsed,
      bestLap: simulation.bestLap,
      gatesCorrect: gatesCorrect,
      totalGates: race.totalGates,
      starGoals: goals,
      rewards: _rewards.rewardsForRace(stars, place),
      finishOrder: simulation.standings,
    );
    scene.celebrate();
    _play(place == 1 ? FunSound.fanfare : FunSound.tada);
    final line = place == 1
        ? '${TurboRaceText.finish.resolve(language)} ${TurboRaceText.place(1).resolve(language)}'
        : '${TurboRaceText.greatTry.resolve(language)} ${TurboRaceText.retryLine(race.number + place).resolve(language)}';
    _speech.speakLine(line, language);
    // A moment of the finish on screen, then the results.
    _finishTimer = Timer(const Duration(milliseconds: 1600), () {
      phase = TurboPhase.finished;
      scene.isPaused = true;
      _changed();
    });
    _changed();
  }

  /// Saves the best result, learning counts and rewards.
  void save(TurboRaceProgressStore store, ProgressService progress) {
    final r = result;
    if (r == null) return;
    store.record(race.number, r.stars, r.time, r.bestLap, r.position);
    store.recordLearning(_correctByKind, simulation.boostsUsed);
    progress.applyRewards(r.rewards);
    progress.recordAnswers(gatesCorrect, _wrongGates);
  }

  String _kindKey(TurboChallenge c) => switch (c.question) {
        FindSymbol(:final symbol) => int.tryParse(symbol) == null ? 'letters' : 'numbers',
        LetterStarting() => 'letters',
        ColorQuestion() => 'colors',
        ShapeQuestion() => 'shapes',
      };

  void _showFeedback(TurboFeedback f, double seconds) {
    feedback = f;
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(Duration(milliseconds: (seconds * 1000).round()), () {
      feedback = null;
      _changed();
    });
    _changed();
  }

  void _play(FunSound sound) {
    if (_audio.soundEnabled) _sounds.play(sound);
  }
}
