import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/catch_letter_level.dart';
import '../../domain/models/catch_letter_strings.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/reward_type.dart';
import '../../domain/models/ui_text.dart';
import '../../game/engine/game_scene.dart';
import '../../services/audio/audio_service.dart';
import '../../services/progress/progress_service.dart';
import '../character/player_marker.dart';
import '../common/game_overlays.dart';
import '../common/play_boost_hud.dart';
import '../common/wrong_catch_card.dart';
import '../settings/language_switch_button.dart';
import 'catch_learn_view_model.dart';
import 'catch_letter_intro_view.dart';

/// Catch Letter: catch the bubble with the letter (or colour, shape, object) asked for.
class CatchLearnView extends StatefulWidget {
  const CatchLearnView({super.key, required this.level});
  final int level;

  @override
  State<CatchLearnView> createState() => _CatchLearnViewState();
}

class _CatchLearnViewState extends State<CatchLearnView> {
  CatchLearnViewModel? _vm;
  bool _showPause = false;
  bool _pausedForLanguage = false;

  /// World introduction shown before the first level of a world is played.
  CatchLetterBatch? _introBatch;
  AppLanguage? _language;
  late final AppState _appState = context.read<AppState>();

  @override
  void initState() {
    super.initState();
    _appState.audioService.startBackgroundMusic();
    _appState.addListener(_languageChanged);
    _setup();
  }

  /// New language: restart this level from the beginning in that language.
  void _languageChanged() {
    if (_appState.language == _language) return;
    _vm?.removeListener(_vmChanged);
    _vm?.dispose();
    setState(() {
      _vm = null;
      _introBatch = null;
    });
    _setup();
  }

  void _setup() {
    final progress = context.read<ProgressService>();
    _language = _appState.language;
    final batch = CatchLetterBatch.containing(widget.level);
    final vm = CatchLearnViewModel(
      level: widget.level,
      contentProvider: _appState.contentProvider,
      rewardService: _appState.rewardService,
      audioService: _appState.audioService,
      language: _appState.language,
      childName: progress.progress.childName,
      retryTutorialSeen: progress.hasSeenRetryTutorial(CatchLearnViewModel.retryTutorialKeyFor(batch)),
    );
    vm.addListener(_vmChanged);
    _vm = vm;
    // First time in this world: play its introduction, then start.
    if (progress.hasSeenBatchIntroduction(batch.rawValue)) {
      vm.startGame();
    } else {
      _introBatch = batch;
    }
    if (mounted) setState(() {});
  }

  void _vmChanged() {
    final vm = _vm;
    if (vm != null && vm.didShowRetryTutorial) context.read<ProgressService>().markRetryTutorialSeen(vm.retryTutorialKey);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appState.removeListener(_languageChanged);
    _appState.audioService.stopBackgroundMusic();
    _vm?.removeListener(_vmChanged);
    _vm?.dispose();
    super.dispose();
  }

  void _tap() => _appState.audioService.playEffect(SoundEffect.buttonTap);

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (vm != null) Positioned.fill(child: _game(vm)) else const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (_introBatch != null)
          Positioned.fill(
            child: CatchLetterIntroView(
              batch: _introBatch!,
              onFinish: () {
                context.read<ProgressService>().markBatchIntroductionSeen(_introBatch!.rawValue);
                setState(() => _introBatch = null);
                _vm?.startGame();
              },
            ),
          ),
      ]),
    );
  }

  Widget _game(CatchLearnViewModel vm) {
    final language = _appState.language;
    final limit = vm.levelConfig.timeLimit;
    final state = vm.gameState;
    return PlayerBuddyOverlay(
      correct: vm.correctAnswers,
      mistakes: vm.questionsAnswered - vm.correctAnswers,
      isComplete: vm.isLevelCompleted,
      bottomInset: limit == null ? 24 : 48,
      // ChihChi the chick stands bottom-left here.
      alignment: AlignmentDirectional.bottomEnd,
      child: Stack(children: [
        Positioned.fill(child: GameView(scene: vm.scene)),
        Positioned.fill(
          child: PlayBoostHUD(
            boost: vm.boost,
            isSlowMotion: vm.isSlowMotion,
            level: vm.level,
            onSlowMotion: vm.useSlowMotion,
            child: IgnorePointer(ignoring: false, child: SafeArea(child: _hud(vm, language, limit))),
          ),
        ),
        if (state is GameInstruction) _instruction(vm, language),
        if (state is GameAnswerCorrect) CorrectOverlay(message: vm.feedbackMessage, grants: vm.pendingRewardGrants),
        if (state is GameAnswerWrong)
          vm.wrongCatch != null
              ? Center(child: SpringIn(child: WrongCatchCard(note: vm.wrongCatch!, language: language)))
              : OopsOverlay(message: vm.feedbackMessage),
        if (state is GameLevelCompleted) _complete(vm, state, language),
        if (state is GamePaused && _showPause)
          PauseOverlay(
            language: language,
            color: _appState.theme.primaryColor,
            onResume: () {
              _tap();
              setState(() => _showPause = false);
              vm.resumeGame();
            },
            onExit: () {
              _tap();
              Navigator.of(context).pop();
            },
          ),
      ]),
    );
  }

  Widget _hud(CatchLearnViewModel vm, AppLanguage language, double? limit) {
    final stars = vm.sessionRewards.where((g) => g.type == RewardType.star).fold<int>(0, (a, g) => a + g.amount);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          GestureDetector(
            onTap: () {
              _tap();
              vm.pauseGame();
              setState(() => _showPause = true);
            },
            child: const Icon(Icons.pause_circle_filled, size: 32, color: Colors.white, shadows: [Shadow(blurRadius: 2)]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_appState.levelLabel} ${vm.level}', style: kid(13, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
            Text('${vm.questionsAnswered}/${vm.levelConfig.questionsPerLevel}',
                style: kid(11, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.7))),
          ]),
          const Spacer(),
          if (vm.streak >= 2) ...[
            HudChip(child: Row(children: [const Text('🔥', style: TextStyle(fontSize: 16)), Text('${vm.streak}', style: kid(15, weight: FontWeight.w700, color: Colors.orange))])),
            const SizedBox(width: 8),
          ],
          HudChip(child: Row(children: [const Text('⭐', style: TextStyle(fontSize: 14)), const SizedBox(width: 4), Text('$stars', style: kid(13, weight: FontWeight.w700, color: Colors.yellow))])),
          const SizedBox(width: 8),
          LanguageSwitchButton(
            // The clock stops while the language list is open. Picking a language restarts the
            // level, and that new level isn't paused, so resuming then does nothing.
            onOpen: () {
              _pausedForLanguage = _vm?.gameState is GamePlaying;
              _vm?.pauseGame();
            },
            onClose: () {
              if (_pausedForLanguage && !_showPause) _vm?.resumeGame();
              _pausedForLanguage = false;
            },
          ),
        ]),
      ),
      if (vm.prompt != null) IgnorePointer(child: _letterDisplay(vm.prompt!, language)),
      const Spacer(),
      if (limit != null)
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: TimerBar(remaining: vm.timeRemaining, limit: limit)),
    ]);
  }

  Widget _letterDisplay(CatchPrompt prompt, AppLanguage language) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(children: [
          _promptSymbol(prompt, 72),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(30)),
            child: _promptLine(prompt, 20, language),
          ),
        ]),
      );

  /// The big letter — tinted for colour questions, framed for shape questions, "?" while remembering.
  Widget _promptSymbol(CatchPrompt prompt, double size) => Row(mainAxisSize: MainAxisSize.min, children: [
        if (prompt.shape != null && !prompt.isHidden) ...[Text(prompt.shape!.icon, style: TextStyle(fontSize: size * 0.55)), const SizedBox(width: 10)],
        Text(prompt.isHidden ? '❓' : prompt.symbol,
            style: kid(size, color: prompt.color?.color ?? Colors.white, shadows: const [Shadow(color: Color(0x59000000), blurRadius: 4, offset: Offset(0, 2))])),
        if (prompt.color != null && !prompt.isHidden) ...[const SizedBox(width: 10), Text(prompt.color!.swatch, style: TextStyle(fontSize: size * 0.45))],
      ]);

  /// "Catch the letter", "Catch Apple", "Catch the red one", "Remember this letter!" …
  Widget _promptLine(CatchPrompt prompt, double fontSize, AppLanguage language) {
    if (prompt.highlight != null) {
      return Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
        Text(_appState.catchInstruction, style: kid(fontSize, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
        Text(prompt.highlight!, style: kid(fontSize, color: Colors.yellow)),
      ]);
    }
    final subtitle = prompt.subtitle;
    if (subtitle == null) return const SizedBox.shrink();
    return Text(prompt.isHidden ? CatchLetterStrings.catchTheOneYouRemember(language) : subtitle,
        textAlign: TextAlign.center, maxLines: 2, style: kid(fontSize, weight: FontWeight.w700, color: Colors.white));
  }

  Widget _instruction(CatchLearnViewModel vm, AppLanguage language) {
    final prompt = vm.prompt, lesson = vm.currentLesson;
    if (prompt == null || lesson == null) return const SizedBox.shrink();
    final showsHint = lesson.symbolPhoneticHint != lesson.symbol && prompt.symbol == lesson.symbol && !prompt.isHidden;
    return IgnorePointer(
      child: Center(
        child: GameCard(
          padding: 32,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _promptSymbol(prompt, 100),
            const SizedBox(height: 20),
            if (showsHint) Text('[${lesson.symbolPhoneticHint}]', style: kid(22, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8))),
            _promptLine(prompt, 26, language),
          ]),
        ),
      ),
    );
  }

  Widget _complete(CatchLearnViewModel vm, GameLevelCompleted state, AppLanguage language) {
    final next = vm.definition.batch.next;
    Widget? extra;
    if (vm.level == CatchLetterLevels.totalLevels) {
      extra = Text('🏆 ${CatchLetterStrings.masterTitle(language)}', textAlign: TextAlign.center, style: kid(20, color: Colors.yellow));
    } else if (vm.definition.isBatchFinale && next != null) {
      extra = Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: next.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(children: [
          Text('🎉 ${CatchLetterStrings.adventureComplete(language)}', style: kid(20, color: Colors.yellow)),
          Text(CatchLetterStrings.youUnlocked(language), style: kid(14, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85))),
          Text('${next.icon} ${CatchLetterStrings.batchTitle(next, language)}', style: kid(22, color: Colors.white)),
        ]),
      );
    }
    return LevelCompleteOverlay(
      language: language,
      theme: _appState.theme,
      stars: state.stars,
      lines: [
        UIText.accuracyPercent((vm.accuracy * 100).round()).resolve(language),
        [
          CatchLetterStrings.correctCount(vm.correctAnswers, vm.questionsAnswered, language),
          if (vm.bestStreak >= 2) CatchLetterStrings.bestStreak(vm.bestStreak, language),
        ].join('   '),
      ],
      rewards: state.rewards,
      extra: extra,
      onContinue: () {
        _tap();
        vm.saveResults(state.stars, state.rewards, context.read<ProgressService>());
        Navigator.of(context).pop();
      },
    );
  }
}
