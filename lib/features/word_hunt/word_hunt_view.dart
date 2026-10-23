import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/ui_text.dart';
import '../../game/engine/game_scene.dart';
import '../../services/audio/audio_service.dart';
import '../../services/progress/progress_service.dart';
import '../character/player_marker.dart';
import '../common/game_overlays.dart';
import '../common/play_boost_hud.dart';
import '../common/wrong_catch_card.dart';
import '../settings/language_switch_button.dart';
import 'word_hunt_view_model.dart';

/// Catch World: find the named object among the drifting pictures.
class WordHuntView extends StatefulWidget {
  const WordHuntView({super.key, required this.level});
  final int level;

  @override
  State<WordHuntView> createState() => _WordHuntViewState();
}

class _WordHuntViewState extends State<WordHuntView> {
  WordHuntViewModel? _vm;
  bool _showPause = false;
  bool _pausedForLanguage = false;
  late final AppState _appState = context.read<AppState>();
  AppLanguage? _language;

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
    _vm?.removeListener(_changed);
    _vm?.dispose();
    _showPause = false;
    _setup();
  }

  void _setup() {
    _language = _appState.language;
    final vm = WordHuntViewModel(
      level: widget.level,
      language: _appState.language,
      audioService: _appState.audioService,
      rewardService: _appState.rewardService,
      childName: context.read<ProgressService>().progress.childName,
      theme: _appState.theme,
    )..addListener(_changed);
    _vm = vm;
    vm.startGame();
    if (mounted) setState(() {});
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appState.removeListener(_languageChanged);
    _appState.audioService.stopBackgroundMusic();
    _vm?.removeListener(_changed);
    _vm?.dispose();
    super.dispose();
  }

  void _tap() => _appState.audioService.playEffect(SoundEffect.buttonTap);

  void _finish(WordHuntViewModel vm) {
    _tap();
    final progress = context.read<ProgressService>();
    progress.applyRewards(vm.sessionRewards);
    progress.completeLevel(widget.level);
    progress.recordAnswers(vm.correctAnswers, vm.questionsAnswered - vm.correctAnswers);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) return const Scaffold(backgroundColor: Colors.black);
    final language = _appState.language;
    final theme = _appState.theme;
    final state = vm.gameState;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [theme.gradientTop, theme.gradientBottom], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: PlayerBuddyOverlay(
          correct: vm.correctAnswers,
          mistakes: vm.questionsAnswered - vm.correctAnswers,
          isComplete: vm.isLevelCompleted,
          bottomInset: 50,
          child: Stack(children: [
            Positioned.fill(child: GameView(scene: vm.scene..topInset = MediaQuery.paddingOf(context).top)),
            Positioned.fill(
              child: PlayBoostHUD(
                boost: vm.boost,
                isSlowMotion: vm.isSlowMotion,
                level: vm.level,
                onSlowMotion: vm.useSlowMotion,
                child: SafeArea(child: _hud(vm, language)),
              ),
            ),
            if (state is GameInstruction)
              IgnorePointer(
                child: Center(
                  child: GameCard(
                    opacity: 0.62,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('👀', style: TextStyle(fontSize: 52)),
                      const SizedBox(height: 12),
                      Text(UIText.getReady.resolve(language), style: kid(27, color: Colors.white)),
                      if (vm.currentTarget != null)
                        Text(vm.currentTarget!.localizedName(language), style: kid(21, weight: FontWeight.w700, color: Colors.yellow)),
                    ]),
                  ),
                ),
              ),
            if (state is GameAnswerCorrect)
              IgnorePointer(
                child: Center(
                  child: GameCard(
                    opacity: 0.66,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🎉', style: TextStyle(fontSize: 58)),
                      const SizedBox(height: 10),
                      Text(UIText.greatJob.resolve(language), style: kid(28, color: Colors.white)),
                      Text(state.objectName, style: kid(19, weight: FontWeight.w700, color: Colors.yellow)),
                      Text(UIText.plusPoints.resolve(language), style: kid(16, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85))),
                    ]),
                  ),
                ),
              ),
            if (state is GameAnswerWrong)
              vm.wrongCatch != null
                  ? Center(child: SpringIn(child: WrongCatchCard(note: vm.wrongCatch!, language: language)))
                  : IgnorePointer(
                      child: Center(
                        child: GameCard(
                          opacity: 0.62,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('💪', style: TextStyle(fontSize: 50)),
                            const SizedBox(height: 10),
                            Text(UIText.tryAgainExclaim.resolve(language), style: kid(26, color: Colors.white)),
                            Text(UIText.keepGoing.resolve(language), style: kid(17, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
                          ]),
                        ),
                      ),
                    ),
            if (state is GameLevelCompleted)
              LevelCompleteOverlay(
                language: language,
                theme: theme,
                stars: state.stars,
                lines: [UIText.score(vm.score).resolve(language)],
                rewards: state.rewards,
                onContinue: () => _finish(vm),
              ),
            if (state is GameOver) _gameOver(vm, language),
            if (_showPause)
              PauseOverlay(
                language: language,
                color: theme.primaryColor,
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
        ),
      ),
    );
  }

  Widget _hud(WordHuntViewModel vm, AppLanguage language) {
    final target = vm.currentTarget;
    final ratio = (vm.timeRemaining / vm.roundTime).clamp(0.0, 1.0);
    final timerColor = ratio > 0.5 ? Colors.green : (ratio > 0.25 ? Colors.orange : Colors.red);
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
            child: const Icon(Icons.pause_circle_filled, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(UIText.catchWorld.resolve(language), style: kid(20, color: Colors.white)),
              Text(UIText.level(widget.level).resolve(language),
                  style: kid(13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75))),
            ]),
          ),
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
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('⭐ ${vm.score}', style: kid(18, color: Colors.yellow)),
            Text(UIText.round(vm.roundNumber, WordHuntViewModel.totalRounds).resolve(language),
                style: kid(12, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75))),
          ]),
        ]),
      ),
      if (target != null)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.34), borderRadius: BorderRadius.circular(22)),
          child: Column(children: [
            Text(UIText.findThis.resolve(language), style: kid(13, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.75))),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (vm.showEmojiInTarget) ...[Text(target.emoji, style: const TextStyle(fontSize: 36)), const SizedBox(width: 10)],
              Flexible(
                child: Text(target.localizedName(language), maxLines: 2, textAlign: TextAlign.center, style: kid(25, color: Colors.white)),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: UIText.sayItAgain.resolve(language),
                child: GestureDetector(
                  onTap: vm.repeatInstruction,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: const Icon(Icons.volume_up, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      const Spacer(),
      if (vm.gameState is GamePlaying)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: IgnorePointer(
            child: Column(children: [
              Row(children: [
                Text('❤️' * vm.lives.clamp(0, 3), style: const TextStyle(fontSize: 16)),
                const Spacer(),
                Text('${vm.timeRemaining.ceil()}s', style: kid(14, color: Colors.white)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: ratio, minHeight: 8, color: timerColor, backgroundColor: Colors.white.withValues(alpha: 0.22)),
              ),
            ]),
          ),
        ),
    ]);
  }

  Widget _gameOver(WordHuntViewModel vm, AppLanguage language) => Positioned.fill(
        child: Center(
          child: SpringIn(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(28)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('💪', style: TextStyle(fontSize: 58)),
                const SizedBox(height: 16),
                Text(UIText.keepPracticing.resolve(language), textAlign: TextAlign.center, style: kid(27, color: Colors.white)),
                const SizedBox(height: 16),
                Text(UIText.score(vm.score).resolve(language), style: kid(19, weight: FontWeight.w700, color: Colors.yellow)),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                  GestureDetector(
                    onTap: () {
                      _tap();
                      setState(() => _showPause = false);
                      vm.startGame();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(color: _appState.theme.primaryColor, borderRadius: BorderRadius.circular(30)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.refresh, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(UIText.tryAgain.resolve(language), style: kid(16, weight: FontWeight.w700, color: Colors.white)),
                      ]),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _finish(vm),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(30)),
                      child: Text(UIText.exit.resolve(language), style: kid(16, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      );
}
