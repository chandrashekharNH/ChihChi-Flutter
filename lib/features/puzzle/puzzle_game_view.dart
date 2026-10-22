import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/store/entitlement_manager.dart';
import '../../core/store/free_uses.dart';
import '../../core/store/premium_access.dart';
import '../../core/ui/emoji_text.dart';
import '../../core/ui/kid_text.dart';
import '../../core/ui/palette.dart';
import '../../data/puzzle_content/puzzle_library.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/home_game.dart';
import '../../domain/models/puzzle_models.dart';
import '../../domain/models/ui_text.dart';
import '../../game/engine/game_scene.dart';
import '../../services/progress/progress_service.dart';
import '../character/player_marker.dart';
import '../common/game_overlays.dart';
import '../settings/language_switch_button.dart';
import '../store/full_adventure_unlock_flow.dart';
import 'puzzle_game_view_model.dart';

String formatPuzzleTime(double seconds) {
  final total = seconds.floor();
  final h = total ~/ 3600, m = (total % 3600) ~/ 60, s = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// Plays one puzzle, then offers the next one without leaving the screen.
class PuzzleGameView extends StatefulWidget {
  const PuzzleGameView({super.key, required this.startPuzzle, this.startLevel});
  final PuzzleDefinition startPuzzle;
  final int? startLevel;

  @override
  State<PuzzleGameView> createState() => _PuzzleGameViewState();
}

class _PuzzleGameViewState extends State<PuzzleGameView> {
  PuzzleDefinition? _puzzle;
  int? _level;
  PuzzleGameViewModel? _vm;
  bool _isNewBest = false;
  bool _grandFinale = false;
  bool _peeking = false;
  bool _saved = false;
  late final AppState _appState = context.read<AppState>();
  AppLanguage? _language;

  @override
  void initState() {
    super.initState();
    _language = _appState.language;
    _appState.addListener(_languageChanged);
    // The home screen already checked the free uses; count this one.
    final feature = FreeFeature.forPuzzle(widget.startPuzzle, widget.startLevel);
    if (feature != null) context.read<FreeUses>().recordUse(feature, context.read<EntitlementManager>().state);
    _load(widget.startPuzzle, widget.startLevel);
    _appState.audioService.startBackgroundMusic();
  }

  @override
  void dispose() {
    _appState.removeListener(_languageChanged);
    _appState.audioService.stopBackgroundMusic();
    _vm?.removeListener(_changed);
    _vm?.dispose();
    super.dispose();
  }

  void _changed() {
    final vm = _vm;
    if (vm != null && vm.phase == PuzzlePhase.completed && !_saved) {
      _saved = true;
      final saved = vm.saveResult(context.read<ProgressService>());
      if (saved != null) {
        _isNewBest = saved.isNewBest;
        if (saved.isGrandFinale) {
          _grandFinale = true;
          vm.celebrateGrandFinale(context.read<ProgressService>().progress.childName);
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _load(PuzzleDefinition puzzle, int? level) {
    _vm?.removeListener(_changed);
    _vm?.dispose();
    _isNewBest = false;
    _grandFinale = false;
    _saved = false;
    _puzzle = puzzle;
    _level = level;
    final progress = context.read<ProgressService>();
    final vm = PuzzleGameViewModel(
      puzzle: puzzle,
      level: level,
      difficulty: progress.puzzleDifficulty,
      language: _appState.language,
      audioService: _appState.audioService,
      childName: progress.progress.childName,
      hapticsEnabled: progress.progress.hapticsEnabled,
      reduceMotion: progress.progress.reducedMotion,
      theme: _appState.theme,
    )..addListener(_changed);
    _vm = vm;
    vm.start();
    if (mounted) setState(() {});
  }

  (PuzzleDefinition, int?)? get _next {
    final p = _puzzle;
    if (p == null) return null;
    return PuzzleLibrary.next(p, _level, _appState.language);
  }

  /// Starts another puzzle from this screen ("Next" or "Play again"), checking Full Adventure:
  /// levels past the free ones, and Free Play / My Photo once their free uses are used up.
  void _start(PuzzleDefinition puzzle, int? level) {
    final state = context.read<EntitlementManager>().state;
    final progress = context.read<ProgressService>();
    final lastFree = PremiumAccess.lastFreeLevel(HomeGame.buildPicture) ?? 10;
    if (level != null && !PremiumAccess.allows(HomeGame.buildPicture, level, state)) {
      FullAdventureUnlockFlow.show(context, HomeGame.buildPicture, freeLevelsDone: progress.puzzleLevelStars(lastFree) != null);
      return;
    }
    final feature = FreeFeature.forPuzzle(puzzle, level);
    if (feature != null) {
      final uses = context.read<FreeUses>();
      if (!uses.allows(feature, state)) {
        FullAdventureUnlockFlow.show(context, HomeGame.buildPicture, freeLevelsDone: false, usedFreeUses: true);
        return;
      }
      uses.recordUse(feature, state);
    }
    _load(puzzle, level);
  }

  /// Names and voice follow the new language at once. Letter puzzles are different per alphabet,
  /// so those start again with the matching letter.
  void _languageChanged() {
    final language = _appState.language;
    if (language == _language) return;
    _language = language;
    final vm = _vm, puzzle = _puzzle;
    if (vm == null || puzzle == null) return;
    if (puzzle.category == PuzzleCategory.letters && vm.phase != PuzzlePhase.completed) {
      final replacement = (_level == null ? null : PuzzleLibrary.adventure(_level!, language)?.puzzle) ??
          PuzzleLibrary.equivalent(puzzle, language);
      if (replacement != null) _load(replacement, _level);
    } else {
      vm.setLanguage(language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    final language = _appState.language;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [rgb(0.42, 0.72, 1), rgb(0.68, 0.52, 0.98)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: vm == null
            ? const SizedBox.shrink()
            : PlayerBuddyOverlay(
                correct: vm.stats.piecesPlaced,
                mistakes: vm.stats.wrongPlacements,
                isComplete: vm.phase == PuzzlePhase.completed,
                bottomInset: 96,
                child: Stack(children: [
                  Positioned.fill(child: GameView(key: ObjectKey(vm), scene: vm.scene, handlesDrag: true)),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(children: [
                        _topBar(vm, language),
                        const Spacer(),
                        if (vm.phase == PuzzlePhase.playing) _controls(vm, language),
                      ]),
                    ),
                  ),
                  if (vm.phase == PuzzlePhase.loading) const Center(child: CircularProgressIndicator(color: Colors.white)),
                  if (_peeking && vm.art != null)
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 300),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: const [BoxShadow(blurRadius: 12, color: Color(0x66000000))],
                          ),
                          child: ClipRRect(borderRadius: BorderRadius.circular(16), child: RawImage(image: vm.art!.full, fit: BoxFit.contain)),
                        ),
                      ),
                    ),
                  if (vm.phase == PuzzlePhase.completed && vm.completion != null)
                    _grandFinale ? _finale(language) : _completionCard(vm, vm.completion!, language),
                ]),
              ),
      ),
    );
  }

  Widget _topBar(PuzzleGameViewModel vm, AppLanguage language) => Row(children: [
        Semantics(
          button: true,
          label: UIText.closeGame.resolve(language),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🧩 ${vm.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: kid(19, color: Colors.white)),
            Text('✔︎ ${vm.stats.piecesPlaced}/${vm.grid.pieceCount}',
                style: kid(13, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(30)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('⏱ ${formatPuzzleTime(vm.stats.time)}',
                style: kid(15, color: Colors.white).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            if (vm.difficulty.showsTimeChallenge)
              Text('${UIText.timeGoal.resolve(language)} ${formatPuzzleTime(vm.targetTime)}',
                  style: kid(11, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8))),
          ]),
        ),
        const SizedBox(width: 10),
        const LanguageSwitchButton(),
      ]);

  Widget _controls(PuzzleGameViewModel vm, AppLanguage language) {
    Widget button(String icon, String title, Color color, {VoidCallback? onTap, bool hold = false}) => Semantics(
          button: true,
          label: title,
          child: GestureDetector(
            onTap: onTap,
            onTapDown: hold ? (_) => setState(() => _peeking = true) : null,
            onTapUp: hold ? (_) => setState(() => _peeking = false) : null,
            onTapCancel: hold ? () => setState(() => _peeking = false) : null,
            child: Container(
              width: 82,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.2)!, color], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 3))],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(icon, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                Text(title, style: kid(12, weight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        button('💡', UIText.hint.resolve(language), Colors.orange, onTap: vm.hint),
        if (vm.canRotate) ...[const SizedBox(width: 14), button('↻', UIText.rotate.resolve(language), Colors.purple, onTap: vm.rotate)],
        const SizedBox(width: 14),
        button('👁', UIText.peek.resolve(language), Colors.teal, hold: true),
      ]),
    );
  }

  Widget _completionCard(PuzzleGameViewModel vm, PuzzleCompletion c, AppLanguage language) {
    final next = _next;
    Widget stat(String icon, String title, String value) => Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            Text(value, style: kid(18, color: Colors.white)),
            FittedBox(child: Text(title, style: kid(11, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.75)))),
          ]),
        );
    Widget pill(String title, Color color, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30)),
            child: Text(title, style: kid(17, color: Colors.white)),
          ),
        );
    final stats = [
      if (vm.difficulty.scoresMistakes) stat('⭐', UIText.scoreTitle.resolve(language), '${c.score}'),
      stat('⏱', UIText.time.resolve(language), formatPuzzleTime(c.stats.time)),
      stat('🧩', UIText.pieces.resolve(language), '${c.stats.piecesPlaced}/${c.stats.pieces}'),
      if (vm.difficulty.scoresMistakes) ...[
        stat('🎯', UIText.moves.resolve(language), '${c.stats.moves}'),
        stat('🔁', UIText.tryAgains.resolve(language), '${c.stats.wrongPlacements}'),
        stat('💡', UIText.hintsUsed.resolve(language), '${c.stats.hints}'),
      ],
    ];
    final columns = vm.difficulty.scoresMistakes ? 3 : 2;
    return Positioned.fill(
      child: Center(
        child: SingleChildScrollView(
          child: SpringIn(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(28)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('🎉 ${UIText.puzzleComplete.resolve(language)}', textAlign: TextAlign.center, style: kid(26, color: Colors.white)),
                const SizedBox(height: 14),
                if (vm.art != null)
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white, width: 3)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(15), child: RawImage(image: vm.art!.full, fit: BoxFit.cover)),
                  ),
                const SizedBox(height: 14),
                Text(vm.name, style: kid(22, color: Colors.yellow)),
                const SizedBox(height: 10),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < 5; i++) Text(i < c.stars ? '⭐' : '☆', style: TextStyle(fontSize: 28, color: i < c.stars ? null : Colors.white.withValues(alpha: 0.6))),
                ]),
                if (_isNewBest) ...[const SizedBox(height: 10), Text(UIText.newBest.resolve(language), style: kid(16, color: Colors.yellow))],
                const SizedBox(height: 14),
                for (var r = 0; r < stats.length; r += columns)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      for (var i = r; i < r + columns; i++) ...[
                        if (i > r) const SizedBox(width: 10),
                        Expanded(child: i < stats.length ? stats[i] : const SizedBox()),
                      ],
                    ]),
                  ),
                Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.center, children: [
                  pill('↻ ${UIText.playAgain.resolve(language)}', Colors.orange, () => _start(vm.puzzle, vm.level)),
                  if (next != null) pill('${UIText.nextPuzzle.resolve(language)} ▶', Colors.green, () => _start(next.$1, next.$2)),
                ]),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('🏠 ${UIText.home.resolve(language)}', style: kid(16, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// Every adventure puzzle done.
  Widget _finale(AppLanguage language) {
    final progress = context.read<ProgressService>();
    final name = progress.progress.childName;
    final totals = progress.puzzleTotals;
    final amazing = UIText.amazing.resolve(language);
    Widget row(String icon, String title, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text('$icon $title', style: kid(16, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9)))),
            Text(value, style: kid(18, color: Colors.white)),
          ]),
        );
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Stack(children: [
          const Positioned.fill(child: _FallingConfetti()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const EmojiText('🏆', size: 90),
                  const SizedBox(height: 12),
                  Text(name.isEmpty ? amazing : '${amazing.substring(0, amazing.length - 1)}, $name!',
                      textAlign: TextAlign.center, style: kid(28, color: Colors.yellow)),
                  Text(UIText.allPuzzlesDone.resolve(language), textAlign: TextAlign.center, style: kid(18, weight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                    child: Column(children: [
                      row('⭐', UIText.totalStars.resolve(language), '${totals.stars}'),
                      row('🧩', UIText.levelsPassed.resolve(language), '${totals.levelsDone}/${PuzzleLibrary.totalLevels}'),
                      row('🎯', UIText.moves.resolve(language), '${totals.moves}'),
                      row('🔁', UIText.tryAgains.resolve(language), '${totals.wrong}'),
                      row('💡', UIText.hintsUsed.resolve(language), '${totals.hints}'),
                      row('⏱', UIText.time.resolve(language), formatPuzzleTime(totals.time)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Text('🎉 ${UIText.congratulations.resolve(language)}', style: kid(22, color: Colors.white)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(30)),
                      child: Text('🏠 ${UIText.home.resolve(language)}', style: kid(18, color: Colors.white)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FallingConfetti extends StatefulWidget {
  const _FallingConfetti();

  @override
  State<_FallingConfetti> createState() => _FallingConfettiState();
}

class _FallingConfettiState extends State<_FallingConfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: LayoutBuilder(
          builder: (context, box) => AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Stack(children: [
              for (var i = 0; i < 18; i++)
                () {
                  final period = 2.0 + i % 4;
                  final t = ((_c.value * 20 - i * 0.15) / period) % 1;
                  return Positioned(
                    left: box.maxWidth / 2 + ((i * 53) % 320) - 160,
                    top: -40 + (box.maxHeight + 80) * math.max(0, t),
                    child: EmojiText(const ['🎉', '🎈', '⭐', '✨', '🎊', '🌟'][i % 6], size: 30),
                  );
                }(),
            ]),
          ),
        ),
      );
}
