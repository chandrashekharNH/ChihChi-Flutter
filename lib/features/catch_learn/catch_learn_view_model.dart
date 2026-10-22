import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../../data/game_content/game_content_provider.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/catch_letter_level.dart';
import '../../domain/models/catch_letter_strings.dart';
import '../../domain/models/game_engagement.dart';
import '../../domain/models/game_object.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/letter_lesson.dart';
import '../../domain/models/level_configuration.dart';
import '../../domain/models/reward_type.dart';
import '../../game/engine/bubble.dart';
import '../../game/engine/living_backdrop.dart';
import '../../game/scenes/alphabet_catch_scene.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/kids_speech_service.dart';
import '../../services/progress/progress_service.dart';
import '../../services/reward/reward_service.dart';
import '../common/wrong_catch_card.dart';

/// What the HUD shows for the current question.
class CatchPrompt {
  CatchPrompt({required this.symbol, this.subtitle, this.highlight, this.color, this.shape, this.isHidden = false});
  final String symbol;

  /// Localized instruction line; null means "Catch" + the highlight using the app's catch word.
  final String? subtitle;

  /// Object or animal name shown in yellow.
  final String? highlight;
  final CatchLetterColor? color;
  final CatchLetterShape? shape;

  /// Memory questions hide the letter while playing.
  bool isHidden;
}

class _Question {
  _Question(this.lesson, this.mode, this.prompt, this.items, {this.color, required this.correctWord});
  final LetterLesson lesson;
  final CatchLetterMode mode;
  final CatchPrompt prompt;
  final List<CatchItem> items;

  /// Target colour of a plain-colour question.
  final CatchLetterColor? color;

  /// Spoken on success.
  final String correctWord;
}

class CatchLearnViewModel extends ChangeNotifier {
  CatchLearnViewModel({
    required this.level,
    required GameContentProviding contentProvider,
    required RewardService rewardService,
    required AudioService audioService,
    required this.language,
    String childName = '',
    bool retryTutorialSeen = false,
  })  : definition = CatchLetterLevels.definition(level),
        _content = contentProvider,
        _rewards = rewardService,
        _audio = audioService,
        _retryTutorialAlreadySeen = retryTutorialSeen,
        _speech = KidsSpeechService(childName: childName, isEnabled: () => audioService.voiceEnabled) {
    levelConfig = definition.levelConfiguration;
  }

  static const _maxAttempts = 2;

  /// Fewest different targets a level rotates through, so no level asks for one letter over and over.
  static const _minimumTargetVariety = 4;

  final int level;
  final CatchLetterLevelDefinition definition;
  late LevelConfiguration levelConfig;
  final AppLanguage language;
  final GameContentProviding _content;
  final RewardService _rewards;
  final AudioService _audio;
  final KidsSpeechService _speech;
  final bool _retryTutorialAlreadySeen;
  final _random = math.Random();

  final scene = AlphabetCatchScene();

  GameState gameState = const GameLoading();
  bool get isLevelCompleted => gameState is GameLevelCompleted;
  LetterLesson? currentLesson;
  int currentLessonIndex = 0;
  int questionsAnswered = 0;
  int correctAnswers = 0;
  int streak = 0;
  PlayBoost boost = PlayBoost();
  bool isSlowMotion = false;
  int bestStreak = 0;
  List<RewardGrant> sessionRewards = [];
  List<RewardGrant> pendingRewardGrants = [];
  String feedbackMessage = '';

  /// Set after a wrong catch: what was caught and what the child is looking for.
  WrongCatchNote? wrongCatch;
  double timeRemaining = 45;
  bool isTimerActive = false;
  int levelCompleteStars = 0;
  CatchPrompt? prompt;

  /// Set when the first-failure demonstration was shown, so the view can remember it.
  bool didShowRetryTutorial = false;

  List<LetterLesson> _alphabet = [];
  List<LetterLesson> _animalLessons = [];
  List<LetterLesson> _targets = [];
  List<CatchLetterMode> _modes = [];
  List<CatchLetterColor?> _colors = [];
  _Question? _current;
  int _attempts = 0;
  Timer? _timer;
  Timer? _flow;
  Timer? _slowTimer;
  bool _disposed = false;

  /// Persistence key for the first-failure demonstration (one per world).
  String get retryTutorialKey => retryTutorialKeyFor(definition.batch);
  static String retryTutorialKeyFor(CatchLetterBatch batch) => 'catchLetter.batch${batch.rawValue}';

  /// Target symbols of the whole level, in order (used by tests).
  List<String> get plannedTargetSymbols =>
      [for (var i = 0; i < _targets.length; i++) _colors[i]?.name ?? _targets[i].symbol];
  List<CatchLetterMode> get plannedModes => _modes;
  List<CatchItem> get currentItems => _current?.items ?? const [];

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _after(double seconds, VoidCallback f) {
    _flow?.cancel();
    _flow = Timer(Duration(milliseconds: (seconds * 1000).round()), () {
      if (!_disposed) f();
    });
  }

  // Game flow

  void startGame() {
    // Letters come from the selected language's alphabet, in teaching order.
    _alphabet = _content.letterLessons;
    if (_alphabet.isEmpty) return;
    _animalLessons = _alphabet.where((l) => _content.object(l.targetObjectID)?.category == ObjectCategory.animal).toList();
    _buildQuestionPlan();
    currentLessonIndex = 0;
    questionsAnswered = 0;
    correctAnswers = 0;
    streak = 0;
    bestStreak = 0;
    boost = PlayBoost();
    _endSlowMotion();
    timeRemaining = levelConfig.timeLimit ?? 45;
    sessionRewards = [];
    scene.onObjectCaught = (id, correct) => _handleCatch(id, correct);
    scene.onRoundExpired = _handleRoundExpired;
    _loadNextLesson();
  }

  void stop() {
    _flow?.cancel();
    _stopTimer();
    _slowTimer?.cancel();
    _speech.stop();
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    _speech.dispose();
    scene.disposeScene();
    super.dispose();
  }

  void _loadNextLesson() {
    if (currentLessonIndex >= _targets.length) {
      _finishLevel();
      return;
    }
    _attempts = 0;
    final q = _makeQuestion(_targets[currentLessonIndex], _modes[currentLessonIndex], _colors[currentLessonIndex]);
    _current = q;
    currentLesson = q.lesson;
    _present(q, isRetry: false, showsHint: false);
  }

  /// Shows the instruction, spawns the bubbles and starts play after a short pause.
  void _present(_Question q, {required bool isRetry, required bool showsHint}) {
    scene.resetChihChi();
    prompt = q.prompt..isHidden = false;
    gameState = const GameInstruction();
    scene.configure(CatchConfig(
      levelConfig: levelConfig,
      items: q.items,
      backdrop: BackdropStyle(
        color: definition.batch.sceneColor,
        setting: _backdropSetting(definition.batch),
        floaters: definition.batch.ambientEmojis,
      ),
      showsHint: showsHint,
      barrierEmojis: definition.batch.barrierEmojis,
      barrierCount: definition.barrierCount,
      barrierCrossingTime: definition.barrierCrossingTime,
    ));
    // The instruction is spoken once per question; a retry only gets the "Oops, try again" line.
    if (showsHint) {
      _speech.speakLine(CatchLetterStrings.sayLookHere(language), language);
    } else if (!isRetry) {
      _speakInstruction(q);
    }
    final isMemory = q.mode == CatchLetterMode.memory;
    final pause = isMemory ? (isRetry ? 1.6 : definition.memorizeSeconds) : 1.5;
    _changed();
    _after(pause, () {
      if (gameState is! GameInstruction) return;
      if (isMemory) {
        prompt?.isHidden = true;
        _speech.speakLine(CatchLetterStrings.sayNowCatchIt(language), language);
      }
      _beginPlaying();
    });
  }

  void _beginPlaying() {
    gameState = const GamePlaying();
    timeRemaining = levelConfig.timeLimit ?? 45;
    scene.startRound();
    _startTimer();
    _changed();
  }

  // Catch handling

  void _handleCatch(String id, bool isCorrect) {
    _stopTimer();
    _flow?.cancel();
    final q = _current;
    if (q == null) return;
    if (isCorrect) {
      questionsAnswered += 1;
      correctAnswers += 1;
      streak += 1;
      bestStreak = math.max(bestStreak, streak);
      boost.correct();
      final grants = [..._rewards.rewardsForCorrectAnswer(streak), ..._rewards.rewardsForBoost(boost)];
      pendingRewardGrants = grants;
      sessionRewards.addAll(grants);
      feedbackMessage = _rewards.celebrationMessage(streak, language);
      gameState = GameAnswerCorrect(q.correctWord);
      _speech.speakCorrect(q.correctWord, language);
      _audio.playCorrectFeedback();
      _changed();
      _after(1.8, _moveToNextQuestion);
    } else {
      final caught = q.items.where((i) => i.id == id).firstOrNull?.label;
      _handleMiss(q, caught);
    }
  }

  void _handleRoundExpired() {
    final q = _current;
    if (gameState is! GamePlaying || q == null) return;
    _stopTimer();
    _handleMiss(q, null);
  }

  /// Wrong catch or the target floated away: a friendly "Oops!", then one more try (with a
  /// demonstration the first time in each world) before moving on.
  void _handleMiss(_Question q, WrongCatchLabel? caught) {
    streak = 0;
    boost.wrong();
    _attempts += 1;
    feedbackMessage = '${CatchLetterStrings.oops(language)} ${_rewards.encouragementMessage(language)}';
    final target = q.items.where((i) => i.isTarget).firstOrNull?.label;
    if (caught != null && target != null) {
      // Name what was caught and what we want, while the scene lights up the right one.
      final note = WrongCatchNote(caught, target);
      wrongCatch = note;
      _speech.speakLine(note.spokenLine(language), language);
    } else {
      wrongCatch = null;
      _speech.speakLine(CatchLetterStrings.sayOopsTryAgain(language), language);
    }
    gameState = const GameAnswerWrong();
    _audio.playWrongFeedback();
    _changed();
    // Leave time to hear the names and look at the highlighted answer.
    final pause = wrongCatch == null ? 1.8 : 3.0;
    if (_attempts >= _maxAttempts) {
      questionsAnswered += 1;
      _after(pause, _moveToNextQuestion);
      return;
    }
    final showsHint = !_retryTutorialAlreadySeen && !didShowRetryTutorial;
    _after(pause, () {
      scene.resetRound();
      if (showsHint) didShowRetryTutorial = true;
      _present(q, isRetry: true, showsHint: showsHint);
    });
  }

  void _moveToNextQuestion() {
    scene.resetRound();
    currentLessonIndex += 1;
    if (questionsAnswered >= levelConfig.questionsPerLevel || currentLessonIndex >= _targets.length) {
      _finishLevel();
    } else {
      _loadNextLesson();
    }
  }

  // Streaks and slow motion

  /// Slows everything down for a few seconds, if a power-up has been earned.
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

  // Level completion

  void _finishLevel() {
    _stopTimer();
    final acc = accuracy;
    final stars = _rewards.starsForAccuracy(acc);
    _endSlowMotion();
    sessionRewards.addAll([..._rewards.rewardsForLevelCompletion(level, acc, streak), ..._rewards.rewardsForBossLevel(level)]);
    levelCompleteStars = stars;
    final next = definition.batch.next;
    if (level == CatchLetterLevels.totalLevels) {
      _speech.speakLine(CatchLetterStrings.masterTitle(language), language, usingName: true);
    } else if (definition.isBatchFinale && next != null) {
      _speech.speakLine(CatchLetterStrings.sayUnlocked(next, language), language, usingName: true);
    } else {
      _speech.speakLevelComplete(language);
    }
    _audio.playEffect(SoundEffect.levelComplete);
    gameState = GameLevelCompleted(stars, sessionRewards);
    _changed();
  }

  /// Saves this level's rewards, stars and answers.
  void saveResults(int stars, List<RewardGrant> rewards, CatchLetterProgressStoring store) {
    store.applyRewards(rewards);
    store.completeLevel(level);
    store.completeCatchLetterLevel(level, stars);
    store.recordAnswers(correctAnswers, math.max(0, questionsAnswered - correctAnswers));
  }

  // Timer

  void _startTimer() {
    final limit = levelConfig.timeLimit;
    if (limit == null) return;
    isTimerActive = true;
    timeRemaining = limit;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      timeRemaining -= 0.1;
      if (timeRemaining <= 0) {
        timeRemaining = 0;
        t.cancel();
        _handleRoundExpired();
      }
      _changed();
    });
  }

  void _stopTimer() {
    isTimerActive = false;
    _timer?.cancel();
    _timer = null;
  }

  // Pause

  void pauseGame() {
    if (gameState is! GamePlaying) return;
    gameState = const GamePaused();
    _stopTimer();
    scene.pauseRound();
    _changed();
  }

  void resumeGame() {
    if (gameState is! GamePaused) return;
    gameState = const GamePlaying();
    scene.resumeRound();
    final left = timeRemaining;
    _startTimer();
    timeRemaining = left;
    _changed();
  }

  double get accuracy => questionsAnswered > 0 ? correctAnswers / questionsAnswered : 0;

  // Question plan

  void _buildQuestionPlan() {
    final count = definition.questionCount;
    List<CatchLetterMode> modes;
    if (definition.mode == CatchLetterMode.mixedMastery) {
      final mix = [
        CatchLetterMode.letterNumber, CatchLetterMode.letterObject, CatchLetterMode.animal, CatchLetterMode.color,
        CatchLetterMode.shape, CatchLetterMode.memory, CatchLetterMode.space, CatchLetterMode.city,
        CatchLetterMode.plainColor,
      ]..shuffle(_random);
      modes = [for (var i = 0; i < count; i++) mix[i % mix.length]];
    } else {
      // Every level mixes: its own letter question → catch a colour → catch an object, and round again.
      final objectMode = definition.mode == CatchLetterMode.letterObject ? CatchLetterMode.singleLetter : CatchLetterMode.letterObject;
      modes = [
        for (var i = 0; i < count; i++)
          switch (i % 3) {
            0 => definition.mode != CatchLetterMode.colorShape
                ? definition.mode
                : (i.isEven ? CatchLetterMode.color : CatchLetterMode.shape),
            1 => CatchLetterMode.plainColor,
            _ => objectMode,
          },
      ];
    }
    // Letter questions share one bag (animals have their own), so letters spread across the level.
    final bags = <CatchLetterMode, List<LetterLesson>>{};
    var colorBag = <CatchLetterColor>[];
    final targets = <LetterLesson>[];
    final colors = <CatchLetterColor?>[];
    final planned = <CatchLetterMode>[];
    CatchLetterColor? lastColor;
    for (final mode in modes) {
      if (mode == CatchLetterMode.plainColor) {
        if (colorBag.every((c) => c == lastColor)) colorBag = [...colorBag, ...([...CatchLetterColor.values]..shuffle(_random))];
        final pick = colorBag.indexWhere((c) => c != lastColor);
        if (pick < 0) continue;
        lastColor = colorBag.removeAt(pick);
        // The lesson is unused by colour questions; repeat the previous one so letter spacing is kept.
        final lesson = targets.isNotEmpty ? targets.last : (_alphabet.isNotEmpty ? _alphabet.first : null);
        if (lesson == null) continue;
        targets.add(lesson);
        colors.add(lastColor);
        planned.add(mode);
        continue;
      }
      final key = mode == CatchLetterMode.animal ? CatchLetterMode.animal : CatchLetterMode.singleLetter;
      final bag = bags[key] ?? [];
      final lastSymbol = targets.isNotEmpty ? targets.last.symbol : null;
      // Never the same letter twice in a row: top the bag up when everything left matches.
      if (bag.every((l) => l.symbol == lastSymbol)) bag.addAll([..._targetPool(mode)]..shuffle(_random));
      var pick = bag.indexWhere((l) => l.symbol != lastSymbol);
      if (pick < 0) pick = bag.isEmpty ? -1 : 0;
      if (pick < 0) continue;
      targets.add(bag.removeAt(pick));
      colors.add(null);
      planned.add(mode);
      bags[key] = bag;
    }
    _modes = planned;
    _colors = colors;
    _targets = targets;
  }

  List<LetterLesson> _targetPool(CatchLetterMode mode) {
    if (mode == CatchLetterMode.animal) {
      final start = definition.animalStart ?? 0;
      final end = definition.animalEnd ?? _animalLessons.length;
      final lower = math.min(start, math.max(0, _animalLessons.length - 1));
      final upper = math.min(math.max(end, lower + _minimumTargetVariety), _animalLessons.length);
      if (lower < upper) return _animalLessons.sublist(lower, upper);
      if (_animalLessons.isNotEmpty) return _animalLessons.take(2).toList();
    }
    // Levels that focus on one or two letters also review earlier letters (then the next new
    // ones), so questions vary instead of repeating.
    var indices = [...definition.letterIndices];
    if (indices.isNotEmpty && indices.toSet().length < _minimumTargetVariety) {
      final highest = indices.reduce(math.max);
      indices = [
        ...indices,
        for (var i = highest - 1; i >= 0; i--) i,
        for (var i = highest + 1; i < highest + _minimumTargetVariety; i++) i,
      ];
    }
    final seen = <String>{};
    final letters = indices
        .map((i) => _alphabet[i % _alphabet.length])
        .where((l) => seen.add(l.symbol))
        .take(math.max(_minimumTargetVariety, definition.letterIndices.toSet().length))
        .toList();
    return letters.isEmpty ? _alphabet.take(3).toList() : letters;
  }

  // Building a question

  _Question _makeQuestion(LetterLesson lesson, CatchLetterMode mode, CatchLetterColor? color) {
    final symbol = lesson.symbol;
    final objectName = _content.localizedName(lesson.targetObjectID);
    final distractors = definition.distractorCount;
    List<T> shuffled<T>(Iterable<T> x) => [...x]..shuffle(_random);

    switch (mode) {
      case CatchLetterMode.plainColor:
        final target = color ?? CatchLetterColor.blue;
        final others = shuffled(CatchLetterColor.values.where((c) => c != target));
        final items = [
          _colorItem('target', target, true),
          for (var i = 0; i < distractors; i++) _colorItem('p$i', others[i % others.length], false),
        ];
        final name = CatchLetterStrings.colorName(target, language);
        return _Question(lesson, mode, CatchPrompt(symbol: target.swatch, subtitle: CatchLetterStrings.colorPrompt(target, language)),
            items,
            color: target, correctWord: name);

      case CatchLetterMode.letterObject:
        final items = [_objectItem('target', lesson.targetObjectID, true)];
        final candidates = [...lesson.distractorObjectIDs, ...shuffled(_content.allObjects.map((o) => o.id))]
            .where((id) => id != lesson.targetObjectID);
        final used = <String>{};
        for (final id in candidates) {
          if (used.length >= distractors) break;
          if (used.add(id)) items.add(_objectItem('d${used.length}', id, false));
        }
        return _Question(lesson, mode, CatchPrompt(symbol: symbol, highlight: objectName), items, correctWord: objectName);

      case CatchLetterMode.animal:
        final items = [_animalItem('target', lesson, true)];
        final others = [...shuffled(_animalLessons), ...shuffled(_alphabet)].where((l) => l.symbol != symbol);
        final used = <String>{};
        for (final other in others) {
          if (used.length >= distractors) break;
          if (used.add(other.symbol)) items.add(_animalItem('d${used.length}', other, false));
        }
        return _Question(lesson, mode, CatchPrompt(symbol: symbol, highlight: objectName), items, correctWord: objectName);

      case CatchLetterMode.color:
        final colors = shuffled(CatchLetterColor.values);
        final targetColor = colors[0];
        String colored(String letter, CatchLetterColor c) => '${CatchLetterStrings.colorName(c, language)} $letter';
        final items = [
          _letterItem('target', symbol, true, style: BubbleStyle(symbol: symbol, fillColor: targetColor.color), name: colored(symbol, targetColor)),
        ];
        // Same letter in other colours, and other letters in the target colour, so the child has to
        // look at both letter and colour.
        final sameLetter = math.min(math.max(1, distractors ~/ 2), colors.length - 1);
        for (var i = 0; i < sameLetter; i++) {
          items.add(_letterItem('c$i', symbol, false,
              style: BubbleStyle(symbol: symbol, fillColor: colors[i + 1].color), name: colored(symbol, colors[i + 1])));
        }
        final others = _otherLetters(symbol, distractors - sameLetter);
        for (var i = 0; i < others.length; i++) {
          final c = i == 0 ? targetColor : colors[_random.nextInt(colors.length)];
          items.add(_letterItem('l$i', others[i], false, style: BubbleStyle(symbol: others[i], fillColor: c.color), name: colored(others[i], c)));
        }
        return _Question(lesson, mode,
            CatchPrompt(symbol: symbol, subtitle: CatchLetterStrings.colorPrompt(targetColor, language), color: targetColor), items,
            correctWord: symbol);

      case CatchLetterMode.shape:
        final shapes = shuffled(CatchLetterShape.values);
        final targetShape = shapes[0];
        Color fill() => CatchLetterColor.values[_random.nextInt(CatchLetterColor.values.length)].color;
        String shaped(String letter, CatchLetterShape s) => '${CatchLetterStrings.shapeName(s, language)} $letter';
        final items = [
          _letterItem('target', symbol, true,
              style: BubbleStyle(symbol: symbol, fillColor: fill(), shape: targetShape), name: shaped(symbol, targetShape)),
        ];
        final sameLetter = math.min(math.max(1, distractors ~/ 2), shapes.length - 1);
        for (var i = 0; i < sameLetter; i++) {
          items.add(_letterItem('s$i', symbol, false,
              style: BubbleStyle(symbol: symbol, fillColor: fill(), shape: shapes[i + 1]), name: shaped(symbol, shapes[i + 1])));
        }
        final others = _otherLetters(symbol, distractors - sameLetter);
        for (var i = 0; i < others.length; i++) {
          final s = i == 0 ? targetShape : shapes[_random.nextInt(shapes.length)];
          items.add(_letterItem('l$i', others[i], false,
              style: BubbleStyle(symbol: others[i], fillColor: fill(), shape: s), name: shaped(others[i], s)));
        }
        return _Question(lesson, mode,
            CatchPrompt(symbol: symbol, subtitle: CatchLetterStrings.shapePrompt(targetShape, language), shape: targetShape), items,
            correctWord: symbol);

      case CatchLetterMode.letterNumber:
        final numbers = shuffled((definition.numbers ?? const IntRange(1, 9)).toList());
        final numberCount = math.min((distractors + 1) ~/ 2, numbers.length);
        final items = [
          _letterItem('target', symbol, true),
          for (final n in numbers.take(numberCount)) _letterItem('n$n', '$n', false),
        ];
        final others = _otherLetters(symbol, distractors - numberCount);
        for (var i = 0; i < others.length; i++) {
          items.add(_letterItem('l$i', others[i], false));
        }
        return _letterQuestion(lesson, mode, items);

      case CatchLetterMode.nature:
      case CatchLetterMode.space:
      case CatchLetterMode.city:
        final decoys = shuffled(_themedBatch(mode).decoyEmojis);
        final letterCount = math.max(1, distractors ~/ 3);
        final decoyCount = math.min(distractors - letterCount, decoys.length);
        final items = [
          _letterItem('target', symbol, true),
          for (var i = 0; i < decoyCount; i++) _decoyItem('e$i', decoys[i]),
        ];
        final others = _otherLetters(symbol, distractors - decoyCount);
        for (var i = 0; i < others.length; i++) {
          items.add(_letterItem('l$i', others[i], false));
        }
        return _letterQuestion(lesson, mode, items);

      default:
        // singleLetter, letterGroup, memory — a few non-letter decoys mixed in with the letters.
        final decoys = shuffled(definition.batch.decoyEmojis).take(distractors ~/ 3).toList();
        final items = [
          _letterItem('target', symbol, true),
          for (var i = 0; i < decoys.length; i++) _decoyItem('e$i', decoys[i]),
        ];
        final others = _otherLetters(symbol, distractors - decoys.length);
        for (var i = 0; i < others.length; i++) {
          items.add(_letterItem('l$i', others[i], false));
        }
        return _letterQuestion(lesson, mode, items);
    }
  }

  _Question _letterQuestion(LetterLesson lesson, CatchLetterMode mode, List<CatchItem> items) {
    final subtitle = mode == CatchLetterMode.memory
        ? CatchLetterStrings.rememberThisLetter(language)
        : CatchLetterStrings.catchTheLetter(language);
    return _Question(lesson, mode, CatchPrompt(symbol: lesson.symbol, subtitle: subtitle), items, correctWord: lesson.symbol);
  }

  /// Other letters to use as distractors — letters from this level first (so similar ones are
  /// compared), then nearby letters of the alphabet.
  List<String> _otherLetters(String symbol, int count) {
    if (count <= 0) return const [];
    final levelLetters = (_targetPool(CatchLetterMode.singleLetter).map((l) => l.symbol).toList()..shuffle(_random));
    final highest = definition.letterIndices.isEmpty ? 0 : definition.letterIndices.reduce(math.max);
    final nearby = (_alphabet.take(math.max(highest + 6, 8)).map((l) => l.symbol).toList()..shuffle(_random));
    final rest = (_alphabet.map((l) => l.symbol).toList()..shuffle(_random));
    final seen = <String>{symbol};
    return [...levelLetters, ...nearby, ...rest].where(seen.add).take(count).toList();
  }

  CatchLetterBatch _themedBatch(CatchLetterMode mode) => switch (mode) {
        CatchLetterMode.nature => CatchLetterBatch.natureWorld,
        CatchLetterMode.space => CatchLetterBatch.spaceWorld,
        CatchLetterMode.city => CatchLetterBatch.cityAdventure,
        _ => definition.batch,
      };

  double _distractorScale() =>
      definition.distractorScaleMin + _random.nextDouble() * (definition.distractorScaleMax - definition.distractorScaleMin);

  CatchItem _letterItem(String id, String symbol, bool isTarget, {BubbleStyle? style, String? name}) => CatchItem(
        id: id,
        caption: '',
        emoji: symbol,
        isTarget: isTarget,
        scale: isTarget ? definition.targetScale : _distractorScale(),
        style: style ?? BubbleStyle(symbol: symbol),
        label: WrongCatchLabel(symbol, name ?? symbol),
      );

  CatchItem _decoyItem(String id, String emoji) =>
      CatchItem(id: id, caption: '', emoji: emoji, isTarget: false, scale: _distractorScale(), label: WrongCatchLabel(emoji, ''));

  /// A letter-less bubble in one colour; the shape is random so only the colour matters.
  CatchItem _colorItem(String id, CatchLetterColor color, bool isTarget) => CatchItem(
        id: id,
        caption: '',
        emoji: '',
        isTarget: isTarget,
        scale: isTarget ? definition.targetScale : _distractorScale(),
        style: BubbleStyle(fillColor: color.color, shape: CatchLetterShape.values[_random.nextInt(CatchLetterShape.values.length)]),
        label: WrongCatchLabel(color.swatch, CatchLetterStrings.colorName(color, language)),
      );

  CatchItem _objectItem(String id, String objectID, bool isTarget) {
    final name = _content.localizedName(objectID);
    final emoji = _content.object(objectID)?.emoji ?? '⭐';
    return CatchItem(
      id: id,
      caption: name,
      emoji: emoji,
      isTarget: isTarget,
      scale: isTarget ? definition.targetScale : _distractorScale(),
      label: WrongCatchLabel(emoji, name),
    );
  }

  CatchItem _animalItem(String id, LetterLesson lesson, bool isTarget) {
    final emoji = _content.object(lesson.targetObjectID)?.emoji ?? '⭐';
    final name = _content.localizedName(lesson.targetObjectID);
    return CatchItem(
      id: id,
      caption: name,
      emoji: lesson.symbol,
      isTarget: isTarget,
      scale: isTarget ? definition.targetScale : _distractorScale(),
      style: BubbleStyle(symbol: lesson.symbol, badgeEmoji: emoji),
      label: WrongCatchLabel(emoji, name),
    );
  }

  /// The living world behind each Catch Letter world.
  static BackdropSetting _backdropSetting(CatchLetterBatch batch) => switch (batch) {
        CatchLetterBatch.spaceWorld || CatchLetterBatch.memoryChallenge => BackdropSetting.night,
        CatchLetterBatch.cityAdventure => BackdropSetting.city,
        _ => BackdropSetting.meadow,
      };

  /// Spoken once per question, without the child's name, so it stays short and never doubles up.
  void _speakInstruction(_Question q) {
    final symbol = q.lesson.symbol;
    switch (q.mode) {
      case CatchLetterMode.letterObject:
      case CatchLetterMode.animal:
        _speech.speakLetterInstruction(symbol, q.correctWord, language);
      case CatchLetterMode.color:
        final c = q.prompt.color;
        if (c != null) _speech.speakLine(CatchLetterStrings.sayCatchColor(symbol, c, language), language);
      case CatchLetterMode.shape:
        final s = q.prompt.shape;
        if (s != null) _speech.speakLine(CatchLetterStrings.sayCatchShape(symbol, s, language), language);
      case CatchLetterMode.plainColor:
        final c = q.color;
        if (c != null) _speech.speakLine(CatchLetterStrings.sayCatchPlainColor(c, language), language);
      case CatchLetterMode.memory:
        _speech.speakLine(CatchLetterStrings.sayRemember(symbol, language), language);
      default:
        _speech.speakLine(CatchLetterStrings.sayCatchLetter(symbol, language), language);
    }
  }
}
