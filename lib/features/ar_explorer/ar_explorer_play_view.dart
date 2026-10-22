import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/app_language.dart';
import '../../game/engine/game_scene.dart';
import '../../services/progress/progress_service.dart';
import 'ar_explorer_content.dart';
import 'ar_explorer_engine.dart';
import 'ar_explorer_mission.dart';
import 'ar_explorer_progress_store.dart';
import 'ar_explorer_text.dart';
import 'ar_explorer_view_model.dart';
import 'ar_explorer_world_content.dart';

const _ink = Color(0xFF403380);
const _soft = Color(0xFFEDE8FF);
const _purple = Color(0xFF664DE6);

extension ExplorerColorSwatch on ExplorerColor {
  /// The colour itself, for picture prompts.
  Color get swatch => switch (this) {
        ExplorerColor.red => const Color(0xFFEB3338),
        ExplorerColor.orange => const Color(0xFFFF8C1A),
        ExplorerColor.yellow => const Color(0xFFFFD91A),
        ExplorerColor.green => const Color(0xFF33B84D),
        ExplorerColor.blue => const Color(0xFF2673F2),
        ExplorerColor.purple => const Color(0xFF994DE0),
        ExplorerColor.pink => const Color(0xFFFF80BF),
      };
}

/// The live camera screen, made for children who can't read yet: every task is a big picture (a
/// colour, a shape, a letter, empty counting slots…) and ChihChi says it aloud. Buttons are icons,
/// and small captions are only there for grown-ups. The camera starts with this screen and stops
/// when it goes away.
class ARExplorerPlayView extends StatefulWidget {
  const ARExplorerPlayView({super.key, required this.viewModel, required this.store});
  final ARExplorerViewModel viewModel;
  final ARExplorerProgressStore store;

  @override
  State<ARExplorerPlayView> createState() => _ARExplorerPlayViewState();
}

class _ARExplorerPlayViewState extends State<ARExplorerPlayView> with WidgetsBindingObserver {
  ARExplorerViewModel get vm => widget.viewModel;
  ARExplorerEngine get engine => vm.engine;
  late final AppState _appState = context.read<AppState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    vm.addListener(_changed);
    engine.state.addListener(_changed);
    _appState.addListener(_languageChanged);
    engine.reduceMotion = context.read<ProgressService>().progress.reducedMotion;
    engine.start().then((_) {
      if (mounted) vm.start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appState.removeListener(_languageChanged);
    vm.removeListener(_changed);
    engine.state.removeListener(_changed);
    vm.stop();
    engine.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      vm.sceneBecameActive();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      vm.sceneBecameInactive();
    }
  }

  void _languageChanged() => vm.setLanguage(_appState.language);

  void _changed() {
    if (mounted) setState(() {});
  }

  void _close([ARExplorerLevel? next]) => Navigator.of(context).pop(next);

  void _checkMiddle() {
    final size = MediaQuery.sizeOf(context);
    vm.handleTap(Offset(size.width / 2, size.height / 2));
  }

  @override
  Widget build(BuildContext context) {
    final language = vm.language;
    final controller = engine.controller;
    final running = engine.state.value == CameraState.running && controller != null && controller.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // The camera, aspect-filled, with ChihChi's pictures over it. Taps go to the ViewModel.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => vm.handleTap(d.localPosition),
            child: Semantics(
              label: ARExplorerText.cameraAccessibility.resolve(language),
              child: Stack(fit: StackFit.expand, children: [
                if (running) ARExplorerCameraFill(controller: controller),
                IgnorePointer(child: GameView(scene: engine)),
              ]),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Column(children: [
              _topBar(language),
              _statusBanner(language),
              const Spacer(),
              if (vm.phase is PhaseChecking) const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(color: Colors.white)),
              const Spacer(),
              _companionRow(),
              _missionPanel(language),
            ]),
          ),
        ),
        ..._overlay(language),
      ]),
    );
  }

  // Top

  Widget _topBar(AppLanguage language) => Row(children: [
        _iconButton(Icons.close, ARExplorerText.explorerHome.resolve(language), 44, dark: true, onTap: _close),
        const Spacer(),
        if (vm.magicStarGoal > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(30)),
            child: Text([for (var i = 0; i < vm.magicStarGoal; i++) i < vm.magicStars ? '🌟' : '✩'].join(),
                style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.7))),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(30)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < vm.missions.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: i < vm.missionIndex
                    ? const Icon(Icons.star, size: 14, color: Colors.yellow)
                    : Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: i == vm.missionIndex ? Colors.white : Colors.white.withValues(alpha: 0.35)),
                      ),
              ),
          ]),
        ),
      ]);

  Widget _statusBanner(AppLanguage language) {
    switch (engine.state.value) {
      case CameraState.failed:
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('📷❗', style: TextStyle(fontSize: 34)),
            const SizedBox(width: 12),
            _iconButton(Icons.refresh, ARExplorerText.tryAgain.resolve(language), 50, onTap: engine.restartAfterFailure),
          ]),
        );
      case CameraState.denied:
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            const Text('📷', style: TextStyle(fontSize: 40)),
            Text(ARExplorerText.cameraNeededTitle.resolve(language), style: kid(18, color: Colors.white)),
            Text(ARExplorerText.cameraNeeded.resolve(language), textAlign: TextAlign.center, style: kid(14, weight: FontWeight.w600, color: Colors.white)),
          ]),
        );
      case CameraState.starting:
      case CameraState.running:
        return const SizedBox.shrink();
    }
  }

  // Companion

  Widget _companionRow() {
    final picture = vm.messageEmoji ?? vm.hintEmoji;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        AnimatedSlide(
          offset: vm.mood == ExplorerMood.cheering && !engine.reduceMotion ? const Offset(0, -0.15) : Offset.zero,
          duration: const Duration(milliseconds: 300),
          curve: Curves.elasticOut,
          child: Text(_appState.theme.characterEmoji, style: const TextStyle(fontSize: 56)),
        ),
        const SizedBox(width: 8),
        if (picture != null)
          Flexible(
            child: Semantics(
              label: vm.message ?? vm.hintText ?? '',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(22)),
                child: FittedBox(fit: BoxFit.scaleDown, child: Text(picture, maxLines: 1, style: const TextStyle(fontSize: 42))),
              ),
            ),
          ),
      ]),
    );
  }

  // Mission panel

  // Taps on the panel itself never reach the camera.
  Widget _missionPanel(AppLanguage language) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: _missionCard(language),
      );

  Widget _missionCard(AppLanguage language) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(26)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 96), child: Center(child: _missionPicture()))),
            const SizedBox(width: 12),
            _iconButton(Icons.volume_up, ARExplorerText.listen.resolve(language), 60, onTap: vm.repeatMission),
          ]),
          const SizedBox(height: 8),
          Text(vm.missionText, maxLines: 2, textAlign: TextAlign.center, style: kid(13, weight: FontWeight.w600, color: _ink.withValues(alpha: 0.65))),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (vm.hintsEnabled) ...[
              _iconButton(Icons.lightbulb, ARExplorerText.hint.resolve(language), 54, tint: Colors.orange, onTap: vm.showHint),
              const SizedBox(width: 14),
            ],
            _iconButton(Icons.fast_forward, ARExplorerText.skip.resolve(language), 54, tint: Colors.blue, onTap: vm.skip),
            const SizedBox(width: 14),
            _iconButton(Icons.center_focus_strong, ARExplorerText.checkMiddle.resolve(language), 54, tint: Colors.green, onTap: _checkMiddle),
            const SizedBox(width: 14),
            _iconButton(Icons.pause, ARExplorerText.pause.resolve(language), 54, tint: Colors.grey, onTap: vm.togglePause),
          ]),
        ]),
      );

  Widget _missionPicture() {
    final goal = vm.mission?.goal;
    switch (goal) {
      case null:
        return const SizedBox.shrink();
      case DiscoverAnything():
        return const Text('👆🔎', style: TextStyle(fontSize: 60));
      case FindObject(:final id):
        if (vm.isMystery) {
          return Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🕵️❓', style: TextStyle(fontSize: 54)),
            const SizedBox(width: 10),
            for (var i = 0; i < 3; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 16,
                height: 16,
                decoration: BoxDecoration(shape: BoxShape.circle, color: i <= vm.mysteryClue ? Colors.orange : _ink.withValues(alpha: 0.2)),
              ),
          ]);
        }
        return Text(vm.emoji(id), style: const TextStyle(fontSize: 72));
      case MemoryRound(:final ask):
        return Text(vm.emoji(ask), style: const TextStyle(fontSize: 72));
      case FindColor(:final color):
        return _swatch(color, 86);
      case FindShape(:final shape):
        return _ShapeSwatch(shape: shape);
      case FindLetter(:final letter):
        return _letterTile(letter, 96, 66);
      case CountObjects(:final count):
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(children: [
            for (var i = 0; i < count; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 66,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _ink.withValues(alpha: 0.5), width: 3)),
                child: i < vm.countFound.length
                    ? Text(vm.emoji(vm.countFound[i]), style: const TextStyle(fontSize: 36))
                    : Text('${i + 1}', style: kid(24, color: _ink.withValues(alpha: 0.4))),
              ),
          ]),
        );
      case FindColorAndShape(:final color, :final shape):
        return Row(mainAxisSize: MainAxisSize.min, children: [
          _swatch(color, 70),
          const SizedBox(width: 14),
          Text('+', style: kid(34, color: _ink.withValues(alpha: 0.5))),
          const SizedBox(width: 14),
          _ShapeSwatch(shape: shape, scale: 0.75),
        ]);
      case MeetAnimal(:final id):
        final animal = ARExplorerWorldCatalog.animal(id)?.emoji ?? '🐾';
        return Text(engine.hasStage ? '👆$animal' : '👇📱$animal', style: const TextStyle(fontSize: 60));
      case OpenPortal(:final world):
        return FittedBox(child: Text(engine.hasStage ? '👆🌀' : '👇📱🌀${world.emoji}', style: const TextStyle(fontSize: 56)));
      case CollectTreasure(:final treasure):
        return Text('🔍${treasure.emoji}', style: const TextStyle(fontSize: 64));
      case Scavenger(:final items):
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Stack(clipBehavior: Clip.none, children: [
                  Opacity(opacity: vm.scavengerTicked.contains(item) ? 0.45 : 1, child: _scavengerChip(item)),
                  if (vm.scavengerTicked.contains(item)) const Positioned(right: -6, top: -6, child: Text('✅', style: TextStyle(fontSize: 20))),
                ]),
              ),
          ]),
        );
    }
  }

  Widget _swatch(ExplorerColor color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.swatch,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
      );

  Widget _letterTile(String letter, double size, double font) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFFF8C33), borderRadius: BorderRadius.circular(size * 0.23)),
        child: FittedBox(child: Text(letter, style: kid(font, color: Colors.white))),
      );

  Widget _scavengerChip(ScavengerItem item) {
    if (item.color != null) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: item.color!.swatch, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
      );
    }
    if (item.shape != null) return _ShapeSwatch(shape: item.shape!, scale: 0.5);
    if (item.letter != null) return _letterTile(item.letter!, 46, 30);
    return Text(vm.emoji(item.objectID!), style: const TextStyle(fontSize: 38));
  }

  // Cards over the camera

  List<Widget> _overlay(AppLanguage language) {
    if (vm.isPaused) {
      return [
        _dimmed(_card([
          const Text('⏸', style: TextStyle(fontSize: 60)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _iconButton(Icons.home, ARExplorerText.explorerHome.resolve(language), 70, tint: Colors.grey, onTap: _close),
            const SizedBox(width: 20),
            _iconButton(Icons.play_arrow, ARExplorerText.resume.resolve(language), 90, tint: Colors.green, onTap: vm.togglePause),
          ]),
        ])),
      ];
    }
    final p = vm.phase;
    switch (p) {
      case PhaseConfirm(:final objectID):
        return [
          _dimmed(Semantics(
            label: ARExplorerText.isThisA(vm.objectName(objectID)).resolve(language),
            child: _card([
              Text(vm.emoji(objectID), style: const TextStyle(fontSize: 100)),
              const Text('❓', style: TextStyle(fontSize: 40)),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _iconButton(Icons.thumb_up, ARExplorerText.yes.resolve(language), 84, tint: Colors.green, onTap: () => vm.confirm(true)),
                const SizedBox(width: 28),
                _iconButton(Icons.thumb_down, ARExplorerText.no.resolve(language), 84, tint: Colors.orange, onTap: () => vm.confirm(false)),
              ]),
            ]),
          )),
        ];
      case PhaseDiscovery(:final card):
        return [_dimmed(_discoveryCard(card, language))];
      case PhaseMemoryShow(:final objectIDs):
        return [
          _dimmed(_card([
            const Text('🧠👀', style: TextStyle(fontSize: 44)),
            Wrap(spacing: 16, alignment: WrapAlignment.center, children: [
              for (final id in objectIDs) Semantics(label: vm.objectName(id), child: Text(vm.emoji(id), style: const TextStyle(fontSize: 64))),
            ]),
            _iconButton(Icons.play_arrow, ARExplorerText.imReady.resolve(language), 84, tint: Colors.green, onTap: vm.memoryReady),
          ])),
        ];
      case PhaseQuiz(:final quiz):
        return [_dimmed(_quizCard(quiz, language))];
      case PhaseFinished(:final summary):
        return [_dimmed(_summaryCard(summary, language))];
      case PhasePlaying():
      case PhaseChecking():
        return const [];
    }
  }

  Widget _discoveryCard(ExplorerCard d, AppLanguage language) {
    final object = d.objectID == null ? null : ARExplorerCatalog.object(d.objectID!);
    final others = _appState.languageOrder.languages.where((l) => l != language).take(2);
    return _card([
      Text(d.isPraise ? '🎉' : '🔍', style: const TextStyle(fontSize: 36)),
      if (d.color != null && d.word == null)
        _swatch(d.color!, 110)
      else if (d.count != null) ...[
        FittedBox(child: Text(d.emoji, maxLines: 1, style: const TextStyle(fontSize: 54))),
        Text('${d.count}', style: kid(80, color: _ink)),
      ] else
        FittedBox(child: Text(object?.emoji ?? d.emoji, maxLines: 1, style: const TextStyle(fontSize: 100))),
      if (d.word != null && d.letter != null) ...[
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 70,
            height: 70,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFFFF8C33), shape: BoxShape.circle),
            child: Text(d.letter!, style: kid(44, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text(d.word!, maxLines: 1, style: kid(36, color: _ink)))),
        ]),
        Wrap(spacing: 10, alignment: WrapAlignment.center, children: [
          for (final l in others)
            if (d.names[l] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(30)),
                child: Text(d.names[l]!, style: kid(15, weight: FontWeight.w700, color: _ink)),
              ),
        ]),
      ],
      Semantics(
        label: ARExplorerText.starsPlus(d.stars).resolve(language),
        child: Text('${'⭐' * (d.stars > 5 ? 5 : d.stars)}${d.stars > 5 ? ' +${d.stars}' : ''}', style: const TextStyle(fontSize: 30)),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _iconButton(Icons.volume_up, ARExplorerText.listen.resolve(language), 64, tint: Colors.purple, onTap: vm.repeatCard),
        if (d.offersLanguageChallenge) ...[
          const SizedBox(width: 22),
          _iconButton(Icons.language, ARExplorerText.languageChallenge.resolve(language), 64, tint: Colors.teal, onTap: vm.startLanguageChallenge),
        ],
        const SizedBox(width: 22),
        _iconButton(Icons.play_arrow, ARExplorerText.next.resolve(language), 84, tint: Colors.green, onTap: vm.next),
      ]),
    ]);
  }

  Widget _quizCard(ExplorerQuiz quiz, AppLanguage language) {
    Widget bigButton(String text, VoidCallback onTap, {Color color = _purple}) => GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 62),
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(40)),
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, style: kid(26, color: Colors.white))),
          ),
        );
    final children = <Widget>[];
    switch (quiz.kind) {
      case QuizKind.count:
        children.addAll([
          FittedBox(child: Text(vm.countFound.map(vm.emoji).join(' '), style: const TextStyle(fontSize: 44))),
          const Text('🔢❓', style: TextStyle(fontSize: 36)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final option in quiz.options)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: GestureDetector(
                  onTap: () => vm.answerQuiz(option),
                  child: Container(
                    width: 84,
                    height: 84,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: _purple, shape: BoxShape.circle),
                    child: Text(option, style: kid(44, color: Colors.white)),
                  ),
                ),
              ),
          ]),
        ]);
      case QuizKind.animalName:
        children.addAll([
          const Text('🐾❓', style: TextStyle(fontSize: 40)),
          for (final option in quiz.options) ...[
            bigButton(vm.animalName(option), () => vm.answerQuiz(option)),
            const SizedBox(height: 4),
          ],
        ]);
      case QuizKind.language:
        final target = quiz.language!;
        final answer = ARExplorerCatalog.object(quiz.answer);
        children.addAll([
          if (answer != null) Text(answer.emoji, style: const TextStyle(fontSize: 72)),
          Text('🌐 ${target.displayName}', style: kid(22, color: _ink)),
          for (final option in quiz.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: bigButton(vm.objectNameIn(option, target), () => vm.answerQuiz(option), color: Colors.teal)),
                const SizedBox(width: 10),
                _iconButton(Icons.volume_up, ARExplorerText.listen.resolve(language), 50, tint: Colors.purple, onTap: () => vm.speakWord(option, target)),
              ]),
            ),
          _iconButton(Icons.fast_forward, ARExplorerText.next.resolve(language), 54, tint: Colors.blue, onTap: vm.leaveLanguageChallenge),
        ]);
      case QuizKind.memoryFirst:
        children.addAll([
          const Text('🧠 1️⃣❓', style: TextStyle(fontSize: 40)),
          Wrap(spacing: 14, runSpacing: 14, alignment: WrapAlignment.center, children: [
            for (final option in quiz.options)
              Semantics(
                button: true,
                label: vm.objectName(option),
                child: GestureDetector(
                  onTap: () => vm.answerQuiz(option),
                  child: Container(
                    width: 88,
                    height: 88,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(22)),
                    child: Text(vm.emoji(option), style: const TextStyle(fontSize: 50)),
                  ),
                ),
              ),
          ]),
        ]);
    }
    if (vm.messageEmoji != null) children.add(Text(vm.messageEmoji!, style: const TextStyle(fontSize: 34)));
    return Semantics(label: quiz.question, child: _card(children));
  }

  Widget _summaryCard(ExplorerSummary s, AppLanguage language) {
    final lv = vm.level;
    final next = lv == null ? null : ARExplorerLevel.next(lv.number);
    final nextLevel = next != null && widget.store.progress.isLevelUnlocked(next) ? next : null;
    final item = s.newCollectible;
    final itemEmoji = item == null ? null : ARExplorerWorldCatalog.emoji(item);
    return _card([
      const Text('🎉🏆🎉', style: TextStyle(fontSize: 50)),
      Text(_appState.theme.characterEmoji, style: const TextStyle(fontSize: 64)),
      if (s.storyComplete) Text(ARExplorerText.worldRestored.resolve(language), textAlign: TextAlign.center, style: kid(24, color: _ink)),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.travel_explore, size: 34, color: _ink),
        const SizedBox(width: 6),
        Text('${s.discovered}', style: kid(34, color: _ink)),
        const SizedBox(width: 18),
        const Icon(Icons.star, size: 34, color: Colors.orange),
        const SizedBox(width: 6),
        Text('${s.stars}', style: kid(34, color: Colors.orange)),
      ]),
      Text(ARExplorerText.correctOf(s.correct, s.total).resolve(language), style: kid(15, weight: FontWeight.w700, color: _ink.withValues(alpha: 0.7))),
      if (itemEmoji != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            Text(itemEmoji, style: const TextStyle(fontSize: 56)),
            Text(ARExplorerText.newForWorld.resolve(language), style: kid(15, weight: FontWeight.w700, color: _ink)),
          ]),
        ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _iconButton(Icons.home, ARExplorerText.explorerHome.resolve(language), 70, tint: Colors.grey, onTap: _close),
        if (nextLevel != null) ...[
          const SizedBox(width: 22),
          _iconButton(Icons.play_arrow, ARExplorerText.nextAdventure.resolve(language), 84, tint: Colors.green, onTap: () => _close(nextLevel)),
        ],
      ]),
    ]);
  }

  // Building blocks

  Widget _dimmed(Widget child) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.35),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: child),
              ),
            ),
          ),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 16), children[i]],
        ]),
      );

  /// Round icon button; the label is for screen readers only.
  Widget _iconButton(IconData icon, String label, double size, {Color tint = _purple, bool dark = false, required VoidCallback onTap}) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? Colors.black.withValues(alpha: 0.35) : null,
              gradient: dark ? null : LinearGradient(colors: [Color.lerp(tint, Colors.white, 0.18)!, tint], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              boxShadow: dark ? null : const [BoxShadow(color: Color(0x26000000), blurRadius: 3, offset: Offset(0, 2))],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.46),
          ),
        ),
      );
}

/// The camera picture filling the screen (aspect-fill, like ARKit's view), so taps map to the photo.
class ARExplorerCameraFill extends StatelessWidget {
  const ARExplorerCameraFill({super.key, required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final preview = controller.value.previewSize;
    if (preview == null) return CameraPreview(controller);
    // The preview size is reported in the sensor's landscape orientation.
    final portraitW = preview.height < preview.width ? preview.height : preview.width;
    final portraitH = preview.height < preview.width ? preview.width : preview.height;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: portraitW, height: portraitH, child: CameraPreview(controller)),
      ),
    );
  }
}

/// A shape drawn as a picture: round, rectangle, or long and thin.
class _ShapeSwatch extends StatelessWidget {
  const _ShapeSwatch({required this.shape, this.scale = 1});
  final ExplorerShape shape;
  final double scale;

  @override
  Widget build(BuildContext context) {
    const fill = LinearGradient(colors: [Color(0xFF73A6FF), Color(0xFF5959F2)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    final border = Border.all(color: Colors.white, width: 3);
    return switch (shape) {
      ExplorerShape.round => Container(width: 86 * scale, height: 86 * scale, decoration: BoxDecoration(gradient: fill, shape: BoxShape.circle, border: border)),
      ExplorerShape.rectangle => Container(
          width: 110 * scale, height: 70 * scale, decoration: BoxDecoration(gradient: fill, borderRadius: BorderRadius.circular(6 * scale), border: border)),
      ExplorerShape.long => Container(
          width: 130 * scale, height: 26 * scale, decoration: BoxDecoration(gradient: fill, borderRadius: BorderRadius.circular(20), border: border)),
    };
  }
}
