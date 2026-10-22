import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../core/localization/localized.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/reward_type.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/fun_sound_player.dart';
import '../../services/audio/fun_sound_synth.dart';
import '../../services/audio/kids_speech_service.dart';
import '../../services/progress/progress_service.dart';
import '../../services/reward/reward_service.dart';
import 'ar_explorer_content.dart';
import 'ar_explorer_engine.dart';
import 'ar_explorer_mission.dart';
import 'ar_explorer_progress_store.dart';
import 'ar_explorer_recognition.dart';
import 'ar_explorer_text.dart';
import 'ar_explorer_world_content.dart';

enum ExplorerMood { idle, cheering, curious, thinking }

/// A finished challenge: what was learned, then "Next".
class ExplorerCard {
  ExplorerCard({
    required this.emoji,
    required this.title,
    required this.lines,
    required this.names,
    required this.stars,
    this.objectID,
    this.color,
    this.count,
    this.word,
    this.letter,
    this.offersLanguageChallenge = false,
    this.isPraise = true,
  });
  String emoji;
  String title;

  /// Spoken aloud; the screen shows pictures instead.
  List<String> lines;
  String? objectID;
  ExplorerColor? color;
  int? count;

  /// The word taught and its first letter, shown big (objects and animals).
  String? word;
  String? letter;
  Map<AppLanguage, String> names;
  int stars;
  bool offersLanguageChallenge;

  /// False for a gentle correction: the card teaches without the party.
  bool isPraise;
}

enum QuizKind { count, memoryFirst, animalName, language }

class ExplorerQuiz {
  const ExplorerQuiz(this.kind, this.question, this.options, this.answer, [this.language]);
  final QuizKind kind;
  final String question;
  final List<String> options;
  final String answer;

  /// For "What is this in Kannada?".
  final AppLanguage? language;
}

class ExplorerSummary {
  const ExplorerSummary({
    required this.discovered,
    required this.correct,
    required this.total,
    required this.stars,
    this.unlockedLevel,
    this.newCollectible,
    this.storyComplete = false,
  });
  final int discovered, correct, total, stars;
  final int? unlockedLevel;
  final String? newCollectible;
  final bool storyComplete;
}

sealed class ExplorerPhase {
  const ExplorerPhase();
}

class PhasePlaying extends ExplorerPhase {
  const PhasePlaying();
}

class PhaseChecking extends ExplorerPhase {
  const PhaseChecking();
}

/// Ask "Is this a …?": a medium-confidence result before teaching, or Find Things' question.
class PhaseConfirm extends ExplorerPhase {
  const PhaseConfirm(this.objectID);
  final String objectID;
}

class PhaseDiscovery extends ExplorerPhase {
  const PhaseDiscovery(this.card);
  final ExplorerCard card;
}

class PhaseMemoryShow extends ExplorerPhase {
  const PhaseMemoryShow(this.objectIDs);
  final List<String> objectIDs;
}

class PhaseQuiz extends ExplorerPhase {
  const PhaseQuiz(this.quiz);
  final ExplorerQuiz quiz;
}

class PhaseFinished extends ExplorerPhase {
  const PhaseFinished(this.summary);
  final ExplorerSummary summary;
}

/// One AR Explorer session: shows a mission, turns the child's taps into recognitions (or taps on
/// ChihChi's own content), judges them gently, teaches, rewards and moves on.
class ARExplorerViewModel extends ChangeNotifier {
  ARExplorerViewModel({
    required this.level,
    required ARExplorerMode? mode,
    required this.language,
    required this.engine,
    required ProgressService progressService,
    required ARExplorerProgressStore store,
    required AudioService audioService,
    required String childName,
    required this.companionEmoji,
  })  : modes = level?.modes ?? (mode == null ? [ARExplorerMode.discover] : [mode]),
        _progress = progressService,
        _store = store,
        _audio = audioService,
        hintsEnabled = store.progress.hintsEnabled,
        _speech = KidsSpeechService(childName: childName, isEnabled: () => audioService.voiceEnabled && store.progress.voiceGuidance) {
    missions = modes.length > 1
        ? ARExplorerMissionGenerator.masterSession(modes, language, _random)
        : ARExplorerMissionGenerator.session(modes[0], language, _random);
  }

  final ARExplorerLevel? level;
  final List<ARExplorerMode> modes;
  AppLanguage language;

  /// The language "What is this in…?" asks about: the family's next-best language.
  AppLanguage challengeLanguage = AppLanguage.english;
  final bool hintsEnabled;
  final String companionEmoji;
  final ARExplorerEngine engine;
  final ProgressService _progress;
  final ARExplorerProgressStore _store;
  final AudioService _audio;
  final _rewards = RewardService();
  final KidsSpeechService _speech;
  final _sounds = FunSoundPlayer();
  final _random = math.Random();
  late final _candidates = [for (final o in ARExplorerCatalog.objects) RecognitionCandidate(o.id, o.keywords)];

  ExplorerPhase phase = const PhasePlaying();
  late List<ARExplorerMission> missions;
  int missionIndex = 0;
  String? message;

  /// The picture version of `message`, shown in ChihChi's bubble.
  String? messageEmoji;
  String? hintText;
  String? hintEmoji;
  ExplorerMood mood = ExplorerMood.idle;
  bool isPaused = false;
  List<String> countFound = [];
  Set<ScavengerItem> scavengerTicked = {};

  /// AR Adventure: Magic Stars brought back so far.
  int magicStars = 0;
  int mysteryClue = 0;

  int _hintStep = 0;
  int _correctMissions = 0;
  int _wrongAnswers = 0;
  int _starsEarned = 0;
  int _streak = 0;
  final Set<String> _discovered = {};
  String? _lastTaughtObjectID;
  Offset? _lastTapPoint;
  ExplorerColor? _pendingColor;
  (String?, bool) _openQuiz = (null, false);
  int _tapToken = 0;
  Timer? _messageTimer, _memoryTimer, _followUpTimer;
  final List<Timer> _reminders = [];
  bool _disposed = false;

  static bool showsVirtualContent(ARExplorerLevel? level, ARExplorerMode? mode) =>
      (level?.modes ?? (mode == null ? const <ARExplorerMode>[] : [mode])).any((m) => m.usesVirtualStage);

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  ARExplorerMission? get mission => missionIndex < missions.length ? missions[missionIndex] : null;
  bool get _isAdventure => modes.length == 1 && modes[0] == ARExplorerMode.adventure;

  /// Magic Stars the story needs (one per real-world challenge).
  int get magicStarGoal => _isAdventure ? missions.where((m) => m.restoresMagicStar).length : 0;

  String _r(Localized l) => l.resolve(language);

  /// "Find something RED!" — the line at the bottom of the screen.
  String get missionText {
    final goal = mission?.goal;
    if (goal == null) return '';
    switch (goal) {
      case DiscoverAnything():
        return _r(ARExplorerText.missionDiscover);
      case FindObject(:final id):
        if (modes.contains(ARExplorerMode.mystery) && ARExplorerCatalog.mysteryClues[id] != null) {
          return ARExplorerCatalog.clue(mysteryClue, id, language) ?? _r(ARExplorerText.mysteryIntro);
        }
        return _r(ARExplorerText.findAnother(objectName(id)));
      case FindColor(:final color):
        return _r(ARExplorerText.missionColor(color));
      case FindShape(:final shape):
        return _r(ARExplorerText.missionShape(shape));
      case FindLetter(:final letter):
        return _r(ARExplorerText.missionLetter(letter));
      case CountObjects(:final count):
        return _r(ARExplorerText.missionCount(count, countFound.length));
      case Scavenger():
        return _r(ARExplorerText.missionScavenger);
      case MemoryRound(:final ask):
        return _r(ARExplorerText.missionFind(objectName(ask)));
      case FindColorAndShape(:final color, :final shape):
        return _r(ARExplorerText.missionColorShape(color, shape));
      case MeetAnimal(:final id):
        return engine.hasStage ? _r(ARExplorerText.tapTheAnimal(animalName(id))) : _r(ARExplorerText.tapFloorToPlace);
      case OpenPortal():
        return engine.hasStage ? _r(ARExplorerText.portalAppeared) : _r(ARExplorerText.openPortalMission);
      case CollectTreasure():
        return _r(ARExplorerText.findTreasure);
    }
  }

  bool get isMystery {
    final goal = mission?.goal;
    return goal is FindObject && ARExplorerCatalog.mysteryClues[goal.id] != null && modes.contains(ARExplorerMode.mystery);
  }

  // Flow

  void start() {
    _say(_r(ARExplorerText.welcomeExplorer));
    engine.placeCompanionAutomatically(companionEmoji);
    _beginMission();
  }

  void stop() {
    _cancelReminders();
    _messageTimer?.cancel();
    _memoryTimer?.cancel();
    _followUpTimer?.cancel();
    _tapToken++;
    _speech.stop();
    _sounds.stop();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    _speech.dispose();
    super.dispose();
  }

  void setLanguage(AppLanguage newLanguage) {
    language = newLanguage;
    _changed();
  }

  void _beginMission() {
    _hintStep = 0;
    hintText = null;
    hintEmoji = null;
    messageEmoji = null;
    message = null;
    mysteryClue = 0;
    countFound = [];
    scavengerTicked = {};
    _pendingColor = null;
    mood = ExplorerMood.idle;
    final goal = mission?.goal;
    if (goal == null) {
      _finish();
      return;
    }
    if (goal is! CollectTreasure) engine.removeTreasure();
    if (goal is MemoryRound) {
      phase = PhaseMemoryShow(goal.objects);
      _say('${_r(ARExplorerText.rememberThese)} ${goal.objects.map(objectName).join(', ')}');
      _memoryTimer?.cancel();
      _memoryTimer = Timer(const Duration(seconds: 6), memoryReady);
      _changed();
      return;
    }
    phase = const PhasePlaying();
    if (goal.isVirtual) {
      _setUpVirtualMission(goal);
    } else if (isMystery) {
      _say('${_r(ARExplorerText.mysteryIntro)} $missionText');
    } else {
      _say(missionText);
    }
    _scheduleReminder();
    _changed();
  }

  void _cancelReminders() {
    for (final t in _reminders) {
      t.cancel();
    }
    _reminders.clear();
  }

  /// Young children lose track: after a quiet while, ChihChi says the task again (twice at most).
  void _scheduleReminder() {
    _cancelReminders();
    for (final seconds in const [15, 40]) {
      _reminders.add(Timer(Duration(seconds: seconds), () {
        if (!_disposed && phase is PhasePlaying && !isPaused) _say(missionText);
      }));
    }
  }

  /// "I'm ready" on the memory card, or its timer.
  void memoryReady() {
    _memoryTimer?.cancel();
    if (phase is! PhaseMemoryShow) return;
    phase = const PhasePlaying();
    _say(missionText);
    _scheduleReminder();
    _changed();
  }

  void repeatMission() => _say(missionText);

  /// 🔊 on a discovery card: hear what was learned again.
  void repeatCard() {
    final p = phase;
    if (p is PhaseDiscovery) _say([p.card.title, ...p.card.lines].join(' '));
  }

  void skip() {
    if (mission == null) return;
    _tapToken++;
    _followUpTimer?.cancel();
    _streak = 0;
    _advance();
  }

  void togglePause() {
    isPaused = !isPaused;
    if (isPaused) {
      _speech.stop();
      engine.pause();
    } else {
      engine.resume();
    }
    _changed();
  }

  void sceneBecameInactive() {
    _speech.stop();
    engine.pause();
  }

  void sceneBecameActive() {
    if (!isPaused) engine.resume();
  }

  // Hints

  void showHint() {
    final goal = mission?.goal;
    if (!hintsEnabled || goal == null) return;
    _hintStep += 1;
    String text;
    var emoji = '👀';
    if (goal is FindObject && isMystery) {
      // Mystery hints are the next clue.
      mysteryClue = math.min(mysteryClue + 1, (ARExplorerCatalog.mysteryClues[goal.id]?.length ?? 1) - 1);
      text = missionText;
      emoji = '🕵️';
    } else if (goal is MeetAnimal) {
      if (engine.hasStage) {
        text = _r(ARExplorerText.tapTheAnimal(animalName(goal.id)));
        emoji = '👆${ARExplorerWorldCatalog.animal(goal.id)?.emoji ?? '🐾'}';
      } else {
        text = _r(ARExplorerText.hintPlace);
        emoji = '👇📱';
      }
    } else if (goal is OpenPortal) {
      text = engine.hasStage ? _r(ARExplorerText.portalAppeared) : _r(ARExplorerText.hintPlace);
      emoji = engine.hasStage ? '👆🌀' : '👇📱';
    } else if (goal is CollectTreasure) {
      final t = goal.treasure.emoji;
      switch (engine.treasureDirection()) {
        case TreasureDirection.left:
          text = _r(ARExplorerText.lookLeft);
          emoji = '⬅️$t';
        case TreasureDirection.right:
          text = _r(ARExplorerText.lookRight);
          emoji = '$t➡️';
        case TreasureDirection.behind:
          text = _r(ARExplorerText.lookBehind);
          emoji = '🔄$t';
        case TreasureDirection.ahead:
        case null:
          text = _r(ARExplorerText.lookAhead);
          emoji = '👀$t';
      }
    } else if (_hintStep == 1) {
      text = _r(ARExplorerText.hintLookAround);
    } else {
      switch (goal) {
        case FindColor(:final color):
          text = _r(ARExplorerText.hintColor(color));
          emoji = color.emoji;
        case FindShape(:final shape):
        case FindColorAndShape(:final shape):
          final pool = ARExplorerCatalog.shaped(shape);
          final sample = pool.isEmpty ? null : pool[_random.nextInt(pool.length)];
          text = sample == null ? _r(ARExplorerText.hintLookAround) : _r(ARExplorerText.hintLike(sample.name(language)));
          emoji = sample?.emoji ?? emoji;
        case FindLetter(:final letter):
          final pool = ARExplorerCatalog.startingWith(letter, language);
          final sample = pool.isEmpty ? null : pool[_random.nextInt(pool.length)];
          text = sample == null ? _r(ARExplorerText.hintLookAround) : _r(ARExplorerText.hintLike(sample.name(language)));
          emoji = sample?.emoji ?? emoji;
        case MemoryRound(:final ask):
        case FindObject(id: final ask):
          text = _r(ARExplorerText.hintLike(objectName(ask)));
          emoji = ARExplorerCatalog.object(ask)?.emoji ?? emoji;
        case CountObjects():
          text = _r(ARExplorerText.hintCount);
          emoji = '👆👆👆';
        default:
          text = _r(ARExplorerText.hintDiscover);
          emoji = '☕📕🪑';
      }
    }
    hintText = text;
    hintEmoji = emoji;
    _say(text);
    _scheduleReminder();
    _changed();
  }

  // Taps

  Future<void> handleTap(Offset point) async {
    final goal = mission?.goal;
    if (phase is! PhasePlaying || isPaused || goal == null) return;
    _cancelReminders();
    // ChihChi's own content first: it is in front of whatever the camera sees.
    final hit = engine.stageHit(point);
    if (hit != null) {
      _handleStageHit(hit, goal);
      return;
    }
    if (goal.isVirtual) {
      _handleVirtualGroundTap(point, goal);
      return;
    }
    phase = const PhaseChecking();
    mood = ExplorerMood.thinking;
    _changed();
    final token = ++_tapToken;
    final crops = await engine.crops(point);
    if (_disposed || token != _tapToken) {
      await crops?.delete();
      return;
    }
    if (crops == null) {
      phase = const PhasePlaying();
      _showMessage('${_r(ARExplorerText.unsure)} ${_r(ARExplorerText.tryAnother)}', '🤔❓', ExplorerMood.curious);
      return;
    }
    final color = ARExplorerRecognitionRules.dominantColor(crops.colorPixels);
    final findTarget = goal is FindObject && !isMystery ? goal.id : null;
    // The tapped object on its own first, then squares from tight to wide; stop once one is clear.
    final images = [...crops.cutoutFiles, ...crops.objectFiles];
    final cropLabels = <Labels>[];
    for (final path in images) {
      final labels = await engine.recognizer.classify(path);
      cropLabels.add(labels);
      if (ARExplorerRecognitionRules.decideLabels(labels, _candidates).certainty == RecognitionCertainty.confident ||
          ARExplorerRecognitionRules.pointsElsewhere(labels, _candidates)) {
        break;
      }
    }
    await crops.delete();
    if (_disposed || token != _tapToken) return;
    final decision = ARExplorerRecognitionRules.decide(cropLabels, _candidates);
    final quizSeen = findTarget == null
        ? null
        : ARExplorerRecognitionRules.check(findTarget, cropLabels, _candidates, crops.cutoutFiles.length + 1);
    _lastTapPoint = engine.showMarker(
        point, decision.certainty == RecognitionCertainty.unsure ? const Color(0xFF9E9E9E) : const Color(0xFFFFD60A));
    _handle(decision.objectID, decision.certainty, color, quizSeen);
  }

  /// "Yes, it's a spoon" / "No".
  void confirm(bool isRight) {
    final p = phase;
    if (p is! PhaseConfirm) return;
    if (_openQuiz.$2) {
      final seen = _openQuiz.$1;
      _openQuiz = (null, false);
      _answerFindQuiz(p.objectID, seen, isRight);
      return;
    }
    if (isRight) {
      _evaluate(p.objectID, _pendingColor);
    } else {
      phase = const PhasePlaying();
      _showMessage(_r(ARExplorerText.okayTryAnother), '👍🔍', ExplorerMood.curious);
    }
  }

  void _handle(String? objectID, RecognitionCertainty certainty, ExplorerColor? color, String? quizSeen) {
    final goal = mission?.goal;
    if (goal == null) return;
    _openQuiz = (null, false);
    // Colour missions only need the colour under the finger.
    if (goal is FindColor) {
      _evaluate(certainty == RecognitionCertainty.confident ? objectID : null, color);
      return;
    }
    // Find Things: every tap becomes "Is this a cup?" — the child answers, then learns what it is.
    if (goal is FindObject && !isMystery) {
      _pendingColor = color;
      _openQuiz = (quizSeen, true);
      phase = PhaseConfirm(goal.id);
      mood = ExplorerMood.curious;
      _say(_r(ARExplorerText.isThisA(objectName(goal.id))));
      _changed();
      return;
    }
    if (certainty == RecognitionCertainty.confident) {
      _evaluate(objectID, color);
    } else if (certainty == RecognitionCertainty.probable && objectID != null) {
      _pendingColor = color;
      phase = PhaseConfirm(objectID);
      mood = ExplorerMood.curious;
      _say(_r(ARExplorerText.isThisA(objectName(objectID))));
      _changed();
    } else {
      if (goal is Scavenger && color != null) {
        _evaluate(null, color);
        return;
      }
      phase = const PhasePlaying();
      _showMessage('${_r(ARExplorerText.unsure)} ${_r(ARExplorerText.tryAnother)}', '🤔❓', ExplorerMood.curious);
    }
  }

  /// Praise or a gentle correction for the child's Yes / No, then "Next" either way.
  void _answerFindQuiz(String target, String? seen, bool saidYes) {
    final goal = FindObject(target);
    final outcome = ARExplorerJudge.quizOutcome(target, seen, saidYes);
    if (outcome.kind == QuizOutcomeKind.found) {
      _discovered.add(target);
      _store.recordDiscovery(target);
      _respond(ARExplorerJudgement.correct(target), goal, _pendingColor);
      return;
    }
    if (seen != null) {
      _discovered.add(seen);
      _store.recordDiscovery(seen);
    }
    String? shownID;
    String title;
    var praised = false;
    switch (outcome.kind) {
      case QuizOutcomeKind.rightNo:
        shownID = outcome.seen;
        title = _r(ARExplorerText.quizRightNo(objectName(outcome.seen!)));
        praised = true;
      case QuizOutcomeKind.wrongYes:
        shownID = outcome.seen;
        title = _r(ARExplorerText.quizWrongYes(objectName(outcome.seen!), objectName(target)));
      case QuizOutcomeKind.missed:
        shownID = target;
        title = _r(ARExplorerText.quizMissed(objectName(target)));
      case QuizOutcomeKind.skipped:
      case QuizOutcomeKind.found:
        shownID = null;
        title = _r(ARExplorerText.quizSkipped(objectName(target)));
    }
    final object = shownID == null ? null : ARExplorerCatalog.object(shownID);
    final card = ExplorerCard(
      emoji: object?.emoji ?? '🔍',
      title: title,
      lines: object == null ? [] : _teachingLines(object, goal),
      names: object?.names ?? {},
      stars: praised ? 1 : 0,
      objectID: shownID,
      word: object?.name(language),
      letter: object?.firstLetter(language),
      isPraise: praised,
    );
    _cancelReminders();
    _followUpTimer?.cancel();
    if (praised) {
      _correctMissions += 1;
      _reward(card.stars);
      _audio.playEffect(SoundEffect.correct);
      _play(FunSound.tada);
      engine.celebrate();
      mood = ExplorerMood.cheering;
    } else {
      if (outcome.kind != QuizOutcomeKind.skipped) {
        _wrongAnswers += 1;
        _streak = 0;
        _audio.playEffect(SoundEffect.wrong);
      }
      mood = ExplorerMood.curious;
    }
    _lastTapPoint = null;
    message = null;
    phase = PhaseDiscovery(card);
    _say([card.title, ...card.lines, _r(ARExplorerText.next)].join(' '));
    _changed();
  }

  void _evaluate(String? objectID, ExplorerColor? color) {
    final goal = mission?.goal;
    if (goal == null) return;
    if (objectID != null) {
      _discovered.add(objectID);
      _store.recordDiscovery(objectID);
    }
    switch (goal) {
      case CountObjects(:final count):
        _countTap(objectID, count);
      case Scavenger(:final items):
        _scavengerTap(items, objectID, color);
      default:
        _respond(ARExplorerJudge.judge(goal, objectID, color, language), goal, color);
    }
  }

  void _respond(ARExplorerJudgement judgement, MissionGoal goal, ExplorerColor? color) {
    switch (judgement.kind) {
      case JudgementKind.correct:
        final objectID = judgement.objectID;
        _lastTaughtObjectID = objectID;
        if (goal is MemoryRound) {
          _askMemoryFirst(goal.objects);
          return;
        }
        var title = _r(ARExplorerText.cheer(missionIndex));
        if (goal is FindColor) title = _r(ARExplorerText.foundColor(goal.color));
        if (isMystery && objectID != null) title = _r(ARExplorerText.mysterySolved(objectName(objectID).toUpperCase()));
        final object = objectID == null ? null : ARExplorerCatalog.object(objectID);
        final card = ExplorerCard(
          emoji: object?.emoji ?? color?.emoji ?? '⭐',
          title: title,
          lines: object == null ? [] : _teachingLines(object, goal),
          names: object?.names ?? {},
          stars: mission?.stars ?? 2,
          objectID: objectID,
          word: object?.name(language),
          letter: object?.firstLetter(language),
          offersLanguageChallenge: object != null && _store.progress.languageChallenge,
          color: goal is FindColor ? goal.color : null,
        );
        _completeMission(card);
      case JudgementKind.notQuite:
        _wrongAnswers += 1;
        _streak = 0;
        phase = const PhasePlaying();
        _showMessage(_notQuiteText(judgement.seen!, goal), _notQuiteEmoji(judgement.seen!), ExplorerMood.curious);
      case JudgementKind.unsure:
        phase = const PhasePlaying();
        _showMessage('${_r(ARExplorerText.unsure)} ${_r(ARExplorerText.tryAnother)}', '🤔❓', ExplorerMood.curious);
    }
  }

  String _notQuiteText(SeenThing seen, MissionGoal goal) {
    if (seen.noColor) return _r(ARExplorerText.noClearColor);
    final found = seen.color;
    if (found != null) {
      if (goal is FindColor) return _r(ARExplorerText.seenColor(found, goal.color));
      if (goal is FindColorAndShape) return _r(ARExplorerText.seenColor(found, goal.color));
      return _r(ARExplorerText.colorName(found));
    }
    final id = seen.objectID!;
    final object = ARExplorerCatalog.object(id);
    if ((goal is FindShape || goal is FindColorAndShape) && object?.shape != null) {
      return _r(ARExplorerText.seenShape(object!.name(language), object.shape!));
    }
    if (goal is FindLetter) return _r(ARExplorerText.seenLetter(objectName(id), object?.firstLetter(language) ?? '', goal.letter));
    return _r(ARExplorerText.seenObject(objectName(id)));
  }

  /// "That's a ball!", "B for Ball.", "Ball is round!"
  List<String> _teachingLines(ARExplorerObject object, MissionGoal goal) {
    final name = object.name(language);
    final lines = [_r(ARExplorerText.thatsA(name)), _r(ARExplorerText.letterFor(object.firstLetter(language), name))];
    if (object.shape != null && (goal is FindShape || goal is FindColorAndShape)) {
      lines.add(_r(ARExplorerText.shapeFact(name, object.shape!)));
    }
    return lines;
  }

  // ChihChi's own content (Animal Adventure, AR Adventure)

  void _setUpVirtualMission(MissionGoal goal) {
    if (!engine.hasStage) {
      _say(missionText);
      return;
    }
    switch (goal) {
      case MeetAnimal(:final id):
        final animal = ARExplorerWorldCatalog.animal(id);
        if (animal == null) return;
        engine.showAnimal(animal);
        mood = ExplorerMood.cheering;
        _say([_r(ARExplorerText.meetAnimal(animal.name(language))), animal.fact(language), _r(ARExplorerText.tapTheAnimal(animal.name(language)))]
            .join(' '));
      case OpenPortal():
        engine.showPortal();
        mood = ExplorerMood.cheering;
        _say(_r(ARExplorerText.portalAppeared));
      case CollectTreasure(:final treasure):
        engine.hideTreasure(treasure);
        _say(_r(ARExplorerText.findTreasure));
      default:
        break;
    }
  }

  /// A tap on the room (not on ChihChi's content) during a virtual mission: place ChihChi first.
  void _handleVirtualGroundTap(Offset point, MissionGoal goal) {
    if (engine.hasStage) {
      _showMessage(missionText, _virtualGoalEmoji(goal), ExplorerMood.curious);
      return;
    }
    if (!engine.placeStage(point, companionEmoji)) {
      _showMessage(_r(ARExplorerText.placeCloser), '👇📱', ExplorerMood.curious);
      return;
    }
    _play(FunSound.pop);
    _setUpVirtualMission(goal);
    _scheduleReminder();
    _changed();
  }

  void _handleStageHit(StageHit hit, MissionGoal goal) {
    if (hit is AnimalHit && goal is MeetAnimal && hit.id == goal.id) {
      _meetAnimalTapped(goal.id);
    } else if (hit is PortalHit && goal is OpenPortal) {
      engine.openPortal(goal.world);
      _play(FunSound.fanfare);
      _completeMission(ExplorerCard(
          emoji: goal.world.emoji,
          title: _r(ARExplorerText.welcomeWorld(goal.world)),
          lines: [_r(ARExplorerText.starsLost)],
          names: {},
          stars: mission?.stars ?? 2));
    } else if (hit is TreasureHit && goal is CollectTreasure) {
      _collect(goal.treasure);
    } else {
      // ChihChi (or something already done) was tapped: a happy giggle, nothing else.
      _play(FunSound.giggle);
      engine.celebrate();
    }
  }

  /// Tap the lion: it roars and jumps, then "What animal is this?".
  void _meetAnimalTapped(String id) {
    final animal = ARExplorerWorldCatalog.animal(id);
    if (animal == null) return;
    engine.reactAnimal();
    if (animal.call != null && _audio.voiceEnabled && _store.progress.voiceGuidance) {
      _speech.speakLine(animal.call!, AppLanguage.english);
    } else {
      _play(FunSound.boing);
    }
    final options = ARExplorerWorldCatalog.nameOptions(id, _random);
    final question = _r(ARExplorerText.whatAnimal);
    phase = PhaseQuiz(ExplorerQuiz(QuizKind.animalName, question, options, id));
    _followUpTimer?.cancel();
    _followUpTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!_disposed) _say('$question ${options.map(animalName).join(', ')}?');
    });
    _changed();
  }

  /// The treasure flies to ChihChi, stars pop, and the next challenge starts right away.
  void _collect(ARTreasure treasure) {
    engine.collectTreasure();
    final stars = mission?.stars ?? 3;
    _reward(stars);
    _correctMissions += 1;
    _play(FunSound.tada);
    _audio.playEffect(SoundEffect.rewardPop);
    _advance();
    _showMessage(_r(ARExplorerText.treasureFound), '${treasure.emoji} ⭐+$stars', ExplorerMood.cheering, speak: false);
    _say('${_r(ARExplorerText.treasureFound)} $missionText');
  }

  String _virtualGoalEmoji(MissionGoal goal) => switch (goal) {
        MeetAnimal(:final id) => '👆${ARExplorerWorldCatalog.animal(id)?.emoji ?? '🐾'}',
        OpenPortal() => '👆🌀',
        CollectTreasure(:final treasure) => '🔍${treasure.emoji}',
        _ => '👆',
      };

  // Counting

  void _countTap(String? objectID, int target) {
    if (objectID == null) {
      phase = const PhasePlaying();
      _showMessage('${_r(ARExplorerText.unsure)} ${_r(ARExplorerText.tryAnother)}', '🤔❓', ExplorerMood.curious);
      return;
    }
    if (countFound.contains(objectID)) {
      phase = const PhasePlaying();
      _showMessage(_r(ARExplorerText.alreadyFound(objectName(objectID))), '${emoji(objectID)} ✅', ExplorerMood.curious);
      return;
    }
    countFound = [...countFound, objectID];
    _play(FunSound.pop);
    if (countFound.length < target) {
      phase = const PhasePlaying();
      _showMessage('${_r(ARExplorerText.thatsA(objectName(objectID)))} ${countFound.length}!', '${emoji(objectID)} ${countFound.length}',
          ExplorerMood.cheering);
      return;
    }
    final options = ({math.max(1, target - 1), target, target + 1}.map((n) => '$n').toList())..shuffle(_random);
    phase = PhaseQuiz(ExplorerQuiz(QuizKind.count, _r(ARExplorerText.howMany), options, '$target'));
    _say(_r(ARExplorerText.howMany));
    _changed();
  }

  // Memory

  void _askMemoryFirst(List<String> objects) {
    _play(FunSound.pop);
    phase = PhaseQuiz(ExplorerQuiz(QuizKind.memoryFirst, _r(ARExplorerText.whichFirst), [...objects]..shuffle(_random), objects[0]));
    _say('${_r(ARExplorerText.cheer(missionIndex))} ${_r(ARExplorerText.whichFirst)}');
    _changed();
  }

  // Language challenge

  /// 🌐 on a discovery card: "What is this in Kannada?" (optional; a parent can turn it off).
  void startLanguageChallenge() {
    final p = phase;
    if (p is! PhaseDiscovery || !p.card.offersLanguageChallenge || p.card.objectID == null) return;
    final id = p.card.objectID!;
    final object = ARExplorerCatalog.object(id);
    if (object == null) return;
    final target = challengeLanguage == language ? (language == AppLanguage.english ? AppLanguage.kannada : AppLanguage.english) : challengeLanguage;
    final answer = object.name(target);
    final others = (ARExplorerCatalog.commonObjects.where((o) => o.id != id && o.name(target) != answer).toList()..shuffle(_random))
        .take(2)
        .map((o) => o.id);
    final question = _r(ARExplorerText.whatIsThisIn(target));
    phase = PhaseQuiz(ExplorerQuiz(QuizKind.language, question, [id, ...others]..shuffle(_random), id, target));
    _say(question);
    _changed();
  }

  /// The language challenge is optional: ▶ leaves it for the next challenge (no streak lost).
  void leaveLanguageChallenge() {
    final p = phase;
    if (p is! PhaseQuiz || p.quiz.kind != QuizKind.language) return;
    _followUpTimer?.cancel();
    _advance();
  }

  /// 🔊 next to a language-challenge option: hear the word in that language.
  void speakWord(String objectID, AppLanguage target) => _speech.speakLine(objectNameIn(objectID, target), target);

  void answerQuiz(String option) {
    final p = phase;
    final goal = mission?.goal;
    if (p is! PhaseQuiz || goal == null) return;
    final quiz = p.quiz;
    final isRight = option == quiz.answer;
    switch (quiz.kind) {
      case QuizKind.count:
        if (!isRight) {
          _wrongAnswers += 1;
          _streak = 0;
          _showMessage(_r(ARExplorerText.countAgain(countFound.length)), '🔢🔄', ExplorerMood.curious);
          return;
        }
        _completeMission(ExplorerCard(
          emoji: countFound.map((id) => ARExplorerCatalog.object(id)?.emoji ?? '').join(),
          title: _r(ARExplorerText.foundCount(countFound.length)),
          lines: countFound.map(objectName).toList(),
          names: {},
          stars: mission?.stars ?? 3,
          count: countFound.length,
        ));
      case QuizKind.memoryFirst:
        if (goal is! MemoryRound) return;
        final lines = <String>[];
        var stars = mission?.stars ?? 3;
        if (!isRight) {
          _wrongAnswers += 1;
          stars = math.max(1, stars - 1);
          lines.add(_r(ARExplorerText.itWas(objectName(quiz.answer))));
        }
        final object = ARExplorerCatalog.object(goal.ask);
        if (object != null) lines.addAll(_teachingLines(object, goal));
        _completeMission(ExplorerCard(
          emoji: goal.objects.map((id) => ARExplorerCatalog.object(id)?.emoji ?? '').join(),
          title: _r(ARExplorerText.cheer(missionIndex)),
          lines: lines,
          names: object?.names ?? {},
          stars: stars,
          objectID: goal.ask,
          word: object?.name(language),
          letter: object?.firstLetter(language),
        ));
      case QuizKind.animalName:
        final animal = ARExplorerWorldCatalog.animal(quiz.answer);
        if (!isRight || animal == null) {
          _wrongAnswers += 1;
          _streak = 0;
          _showMessage(_r(ARExplorerText.lookAgain), '🔍', ExplorerMood.curious);
          return;
        }
        final name = animal.name(language);
        _completeMission(ExplorerCard(
          emoji: animal.emoji,
          title: _r(ARExplorerText.cheer(missionIndex)),
          lines: [_r(ARExplorerText.thatsA(name)), animal.fact(language)],
          names: animal.names,
          stars: mission?.stars ?? 3,
          word: name,
          letter: firstLetter(name, language),
        ));
      case QuizKind.language:
        if (!isRight) {
          _showMessage(_r(ARExplorerText.lookAgain), '🔍', ExplorerMood.curious);
          return;
        }
        // A small bonus; then on to the next challenge.
        final target = quiz.language!;
        _reward(1);
        _play(FunSound.pop);
        _advance();
        final word = objectNameIn(quiz.answer, target);
        _showMessage(word, '🌐 ⭐+1', ExplorerMood.cheering, speak: false);
        _speech.speakLine(word, target);
        _followUpTimer?.cancel();
        _followUpTimer = Timer(const Duration(milliseconds: 1600), () {
          if (!_disposed && phase is PhasePlaying) _say(missionText);
        });
    }
  }

  // Scavenger

  void _scavengerTap(List<ScavengerItem> items, String? objectID, ExplorerColor? color) {
    phase = const PhasePlaying();
    final match = ARExplorerJudge.scavengerMatch(items, scavengerTicked, objectID, color, language);
    if (match == null) {
      final text = objectID == null
          ? '${_r(ARExplorerText.unsure)} ${_r(ARExplorerText.tryAnother)}'
          : _r(ARExplorerText.seenObject(objectName(objectID)));
      _showMessage(text, objectID == null ? '🤔❓' : '${emoji(objectID)} 🔍', ExplorerMood.curious);
      return;
    }
    scavengerTicked = {...scavengerTicked, match};
    _play(FunSound.pop);
    _audio.playEffect(SoundEffect.correct);
    if (scavengerTicked.length < items.length) {
      _showMessage('${_r(ARExplorerText.cheer(scavengerTicked.length))} ${scavengerLabel(match)}', '✅ ${scavengerEmoji(match)}',
          ExplorerMood.cheering);
      return;
    }
    _completeMission(ExplorerCard(
      emoji: '🎒',
      title: _r(ARExplorerText.scavengerDone),
      lines: items.map((i) => '✓ ${scavengerLabel(i)}').toList(),
      names: {},
      stars: mission?.stars ?? 10,
    ));
  }

  String scavengerLabel(ScavengerItem item) {
    if (item.color != null) return '${item.color!.emoji} ${_r(ARExplorerText.missionColor(item.color!))}';
    if (item.shape != null) return '${item.shape!.emoji} ${_r(ARExplorerText.missionShape(item.shape!))}';
    if (item.letter != null) return '🔤 ${_r(ARExplorerText.missionLetter(item.letter))}';
    return '${emoji(item.objectID!)} ${_r(ARExplorerText.missionFind(objectName(item.objectID!)))}';
  }

  String scavengerEmoji(ScavengerItem item) => item.color?.emoji ?? item.shape?.emoji ?? item.letter ?? emoji(item.objectID ?? '');

  // Completing

  void _completeMission(ExplorerCard card) {
    _cancelReminders();
    _followUpTimer?.cancel();
    _correctMissions += 1;
    _reward(card.stars);
    if (_isAdventure && mission?.restoresMagicStar == true) {
      magicStars += 1;
      card.lines = [...card.lines, _r(ARExplorerText.magicStarBack(magicStars))];
    }
    _audio.playEffect(SoundEffect.correct);
    _play(FunSound.tada);
    final tap = _lastTapPoint;
    if (tap != null && !(mission?.goal.isVirtual ?? false)) {
      engine.approach(tap);
    } else {
      engine.celebrate();
    }
    _lastTapPoint = null;
    mood = ExplorerMood.cheering;
    message = null;
    phase = PhaseDiscovery(card);
    _say([card.title, ...card.lines].join(' '));
    _changed();
  }

  /// Stars through the shared reward service, counted for this session and the parent's view.
  void _reward(int stars) {
    _streak += 1;
    _progress.applyRewards(_rewards.rewardsForExplorerMission(stars, _streak));
    _store.recordMission(stars);
    _starsEarned += stars;
  }

  /// "Next" on a discovery card.
  void next() {
    if (phase is PhaseDiscovery) _advance();
  }

  void _advance() {
    // Discover mode follows a discovery with "Can you find another …?" (skippable).
    final last = _lastTaughtObjectID;
    if (modes.length == 1 &&
        modes[0] == ARExplorerMode.discover &&
        phase is PhaseDiscovery &&
        last != null &&
        missionIndex + 1 < missions.length &&
        missionIndex.isEven) {
      missions[missionIndex + 1] = ARExplorerMission(FindObject(last), 3);
    }
    _lastTaughtObjectID = null;
    missionIndex += 1;
    _beginMission();
  }

  void _finish() {
    final total = missions.length;
    final bonus = _rewards.rewardsForExplorerSession(_correctMissions);
    if (bonus.isNotEmpty) {
      _progress.applyRewards(bonus);
      _starsEarned += bonus.where((g) => g.type == RewardType.star).fold(0, (s, g) => s + g.amount);
    }
    _progress.recordAnswers(_correctMissions, _wrongAnswers);
    for (final m in modes) {
      _store.recordFinishedSession(m);
    }
    engine.clearStagePieces();

    int? unlocked;
    String? newCollectible;
    final ratio = _correctMissions / math.max(total, 1);
    final stars = ratio >= 0.8 ? 3 : ratio >= 0.5 ? 2 : 1;
    // Single hunts count toward the level for that hunt, so the parent's Explorer Level grows.
    final huntLevel = modes.length == 1 ? ARExplorerLevel.level(modes[0].unlockLevel) : null;
    if (level == null && huntLevel != null && _correctMissions > 0) {
      _store.finishLevel(huntLevel.number, stars);
      newCollectible = _store.collectReward(huntLevel.number);
    }
    final lv = level;
    if (lv != null && _correctMissions > 0) {
      final next = ARExplorerLevel.next(lv.number);
      final wasLockedNext = next != null && !_store.progress.isLevelUnlocked(next);
      _store.finishLevel(lv.number, stars);
      newCollectible = _store.collectReward(lv.number);
      if (wasLockedNext) unlocked = next.number;
    }
    final storyComplete = _isAdventure && magicStarGoal > 0 && magicStars >= magicStarGoal;
    mood = ExplorerMood.cheering;
    phase = PhaseFinished(ExplorerSummary(
      discovered: _discovered.length,
      correct: _correctMissions,
      total: total,
      stars: _starsEarned,
      unlockedLevel: unlocked,
      newCollectible: newCollectible,
      storyComplete: storyComplete,
    ));
    engine.celebrate();
    _say(storyComplete
        ? '${_r(ARExplorerText.worldRestored)} ${_r(ARExplorerText.greatExploring)}'
        : _r(ARExplorerText.greatExploring));
    _changed();
  }

  // Helpers

  String objectName(String id) => objectNameIn(id, language);
  String objectNameIn(String id, AppLanguage l) => ARExplorerCatalog.object(id)?.name(l) ?? id;
  String animalName(String id) => ARExplorerWorldCatalog.animal(id)?.name(language) ?? id;
  String emoji(String id) => ARExplorerCatalog.object(id)?.emoji ?? '❓';

  static String firstLetter(String word, AppLanguage language) {
    if (word.isEmpty) return '';
    final letter = String.fromCharCode(word.runes.first);
    return language == AppLanguage.english ? letter.toUpperCase() : letter;
  }

  String _notQuiteEmoji(SeenThing seen) {
    if (seen.objectID != null) return '${emoji(seen.objectID!)} 🔍';
    if (seen.color != null) return '${seen.color!.emoji} 🔍';
    return '🌈❓';
  }

  void _showMessage(String text, String emojiText, ExplorerMood newMood, {bool speak = true}) {
    mood = newMood;
    message = text;
    messageEmoji = emojiText;
    _scheduleReminder();
    if (speak) _say(text);
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(seconds: 4), () {
      message = null;
      messageEmoji = null;
      if (mood != ExplorerMood.cheering) mood = ExplorerMood.idle;
      _changed();
    });
    _changed();
  }

  void _say(String text) => _speech.speakLine(text, language);

  void _play(FunSound sound) {
    if (_audio.soundEnabled) _sounds.play(sound);
  }
}
