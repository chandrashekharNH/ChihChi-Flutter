import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/ui_text.dart';
import '../../game/engine/game_scene.dart';
import '../../services/progress/progress_service.dart';
import '../character/player_marker.dart';
import '../common/game_overlays.dart';
import '../common/play_boost_hud.dart';
import '../common/wrong_catch_card.dart';
import '../settings/language_switch_button.dart';
import 'learn_blaster_view_model.dart';

/// Learn Blaster: hold the blaster, aim at the balloon that matches the prompt, tap to fire.
class LearnBlasterView extends StatefulWidget {
  const LearnBlasterView({super.key, required this.level});
  final int level;

  @override
  State<LearnBlasterView> createState() => _LearnBlasterViewState();
}

class _LearnBlasterViewState extends State<LearnBlasterView> {
  LearnBlasterViewModel? _vm;
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
    _setup();
  }

  void _setup() {
    _language = _appState.language;
    final vm = LearnBlasterViewModel(
      level: widget.level,
      language: _appState.language,
      rewardService: _appState.rewardService,
      audioService: _appState.audioService,
      childName: context.read<ProgressService>().progress.childName,
    )..addListener(_changed);
    _vm = vm;
    vm.start();
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

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) return const Scaffold(backgroundColor: Color(0xFFC2E0FF));
    final language = _appState.language;
    return Scaffold(
      backgroundColor: const Color(0xFFC2E0FF),
      body: PlayerBuddyOverlay(
        correct: vm.correctAnswers,
        mistakes: vm.wrongShots,
        isComplete: vm.isLevelCompleted,
        bottomInset: 150,
        child: Stack(children: [
          // A fresh scene view whenever the level restarts in a new language.
          Positioned.fill(child: GameView(key: ObjectKey(vm), scene: vm.scene, handlesDrag: true)),
          Positioned.fill(
            child: PlayBoostHUD(
              boost: vm.boost,
              isSlowMotion: vm.isSlowMotion,
              level: vm.level,
              onSlowMotion: vm.useSlowMotion,
              child: SafeArea(child: _hud(vm, language)),
            ),
          ),
          if (vm.completedStars != null)
            LevelCompleteOverlay(
              language: language,
              theme: _appState.theme,
              stars: vm.completedStars!,
              lines: [UIText.score(vm.score).resolve(language)],
              rewards: vm.sessionRewards,
              extra: GestureDetector(
                onTap: () {
                  vm.saveResults(context.read<ProgressService>());
                  vm.start();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(40)),
                  child: Text('↻ ${UIText.playAgain.resolve(language)}', style: kid(18, color: Colors.white)),
                ),
              ),
              onContinue: () {
                vm.saveResults(context.read<ProgressService>());
                Navigator.of(context).pop();
              },
            ),
        ]),
      ),
    );
  }

  Widget _hud(LearnBlasterViewModel vm, AppLanguage language) {
    final feedback = vm.feedback;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(children: [
        _topBar(vm, language),
        const SizedBox(height: 10),
        if (vm.currentTarget != null) _promptCard(vm, language),
        const Spacer(),
        IgnorePointer(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: feedback != null
                ? KeyedSubtree(key: ValueKey(feedback), child: _feedback(feedback, language))
                : vm.showsShootTip
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(30)),
                        child: Text(UIText.blasterTip.resolve(language), textAlign: TextAlign.center, style: kid(17, weight: FontWeight.w700, color: Colors.white)),
                      )
                    : const SizedBox.shrink(),
          ),
        ),
        // Leave room so the blaster at the bottom stays touchable.
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
      ]),
    );
  }

  Widget _pill(Widget child) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(30)),
        child: child,
      );

  Widget _topBar(LearnBlasterViewModel vm, AppLanguage language) => Row(children: [
        Semantics(
          button: true,
          label: UIText.closeGame.resolve(language),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ),
        const Spacer(),
        Semantics(
          label: UIText.roundOf(vm.round, vm.totalRounds).resolve(language),
          child: _pill(Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 1; i <= vm.totalRounds; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == vm.round ? 12 : 9,
                height: i == vm.round ? 12 : 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < vm.round ? Colors.yellow : Colors.white.withValues(alpha: i == vm.round ? 0.95 : 0.4),
                ),
              ),
          ])),
        ),
        const Spacer(),
        const LanguageSwitchButton(),
        const SizedBox(width: 8),
        _pill(Text('⭐ ${vm.score}', style: kid(18, color: Colors.white))),
      ]);

  Widget _promptCard(LearnBlasterViewModel vm, AppLanguage language) => Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Row(children: [
          const Text('🎯', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(vm.promptText, maxLines: 1, style: kid(36, color: const Color(0xFF334080))),
              ),
              if (vm.promptHint != null) Text(vm.promptHint!, style: kid(15, weight: FontWeight.w600, color: Colors.black54)),
            ]),
          ),
          Semantics(
            button: true,
            label: UIText.sayItAgain.resolve(language),
            child: GestureDetector(
              onTap: vm.repeatInstruction,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                child: const Icon(Icons.volume_up, color: Colors.white),
              ),
            ),
          ),
        ]),
      );

  Widget _feedback(BlasterFeedback feedback, AppLanguage language) {
    Widget bubble(String text, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(40), boxShadow: const [BoxShadow(blurRadius: 6, color: Color(0x40000000))]),
          child: Text(text, textAlign: TextAlign.center, style: kid(26, color: Colors.white)),
        );
    String label(WrongCatchLabel l) => l.name == l.symbol ? l.symbol : '${l.symbol} ${l.name}';
    return switch (feedback) {
      BlasterCorrect(:final message) => bubble(message, Colors.green),
      BlasterTryAgain(:final message) => bubble(message, Colors.orange),
      BlasterFunny(:final message) => bubble(message, Colors.purple),
      // "🐶 Dog!" over "We're looking for 🍎 Apple" — compact, since the balloons keep flying.
      BlasterLearn(:final note) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(22)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${label(note.caught)}!', textAlign: TextAlign.center, style: kid(26, color: Colors.white)),
            const SizedBox(height: 4),
            Text('${UIText.lookingFor.resolve(language)} ${label(note.target)}', textAlign: TextAlign.center, style: kid(18, weight: FontWeight.w700, color: Colors.yellow)),
          ]),
        ),
    };
  }
}
