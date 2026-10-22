import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_state.dart';
import '../../core/store/entitlement_manager.dart';
import '../../core/store/premium_access.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/home_game.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/kids_speech_service.dart';
import '../../services/progress/progress_service.dart';
import '../common/play_session_tracking.dart';
import '../store/full_adventure_unlock_flow.dart';
import 'ar_explorer_engine.dart';
import 'ar_explorer_mission.dart';
import 'ar_explorer_play_view.dart';
import 'ar_explorer_progress_store.dart';
import 'ar_explorer_text.dart';
import 'ar_explorer_view_model.dart';
import 'ar_explorer_world_content.dart';
import 'ar_explorer_world_view.dart';

const _ink = Color(0xFF403380);
const _explorerGradient = LinearGradient(
  colors: [Color(0xFF5C4DE6), Color(0xFF339EE6), Color(0xFF40C79E)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

class ExplorerStart {
  const ExplorerStart({this.level, this.mode, this.introOnly = false, this.myWorld = false});
  final ARExplorerLevel? level;
  final ARExplorerMode? mode;
  final bool introOnly;

  /// "Place in my room": the child's collection, no missions.
  final bool myWorld;
}

/// Entry to ChihChi AR Explorer. Shows the Explorer home; each level, hunt or "My AR World" opens
/// full screen through a short flow: ChihChi intro (first time) → camera explanation (first time)
/// → play. The camera only runs inside that play screen.
class ARExplorerView extends StatefulWidget {
  const ARExplorerView({super.key});

  @override
  State<ARExplorerView> createState() => _ARExplorerViewState();
}

class _ARExplorerViewState extends State<ARExplorerView> {
  final _store = ARExplorerProgressStore();

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  bool get _freeLevelsDone => _store.progress.levelStars[PremiumAccess.lastFreeLevel(HomeGame.arHunt) ?? 10] != null;

  /// Explorer Levels past the free ones, and the hunts those levels open, are Full Adventure.
  bool _allows(ExplorerStart request) {
    final state = context.read<EntitlementManager>().state;
    if (request.level != null && !request.introOnly) return PremiumAccess.allows(HomeGame.arHunt, request.level!.number, state);
    if (request.mode != null) return PremiumAccess.allows(HomeGame.arHunt, request.mode!.unlockLevel, state);
    return true;
  }

  Future<void> _start(ExplorerStart request) async {
    if (!_allows(request)) {
      FullAdventureUnlockFlow.show(context, HomeGame.arHunt, freeLevelsDone: _freeLevelsDone);
      return;
    }
    final next = await Navigator.of(context).push<ARExplorerLevel?>(MaterialPageRoute(
      builder: (_) => PlaySessionTracking(game: HomeGame.arHunt, child: ARExplorerSessionFlow(request: request, store: _store)),
    ));
    if (!mounted) return;
    setState(() {});
    if (next != null) _start(ExplorerStart(level: next));
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    context.watch<EntitlementManager>();
    if (!_store.progress.isAllowed) {
      return ARExplorerNoticeView(
        icon: '🔒',
        title: ARExplorerText.title.resolve(language),
        message: ARExplorerText.notAllowed.resolve(language),
        language: language,
        onBack: () => Navigator.of(context).pop(),
      );
    }
    return _ExplorerHome(
      store: _store,
      onStart: _start,
      onOpenCollection: () async {
        final place = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ARExplorerCollectionView(store: _store)));
        if (place == true && mounted) _start(const ExplorerStart(myWorld: true));
      },
    );
  }
}

// Home

/// ChihChi, the Explorer Levels (opened one by one), every hunt as a big picture tile, and "My AR World".
class _ExplorerHome extends StatefulWidget {
  const _ExplorerHome({required this.store, required this.onStart, required this.onOpenCollection});
  final ARExplorerProgressStore store;
  final void Function(ExplorerStart) onStart;
  final VoidCallback onOpenCollection;

  @override
  State<_ExplorerHome> createState() => _ExplorerHomeState();
}

class _ExplorerHomeState extends State<_ExplorerHome> {
  late final KidsSpeechService _speech;

  static const _tiles = [
    (ARExplorerMode.discover, [Color(0xFF33BF80), Color(0xFF1A8CB3)]),
    (ARExplorerMode.mystery, [Color(0xFF4D4D80), Color(0xFF262659)]),
    (ARExplorerMode.color, [Color(0xFFFF7380), Color(0xFFF24099)]),
    (ARExplorerMode.shape, [Color(0xFF5999FF), Color(0xFF4D59E6)]),
    (ARExplorerMode.letter, [Color(0xFFFFB333), Color(0xFFFF7333)]),
    (ARExplorerMode.number, [Color(0xFF9973FF), Color(0xFF7340D9)]),
    (ARExplorerMode.scavenger, [Color(0xFF8CCC40), Color(0xFF4D9933)]),
    (ARExplorerMode.memory, [Color(0xFFFF80BF), Color(0xFFCC4DB3)]),
    (ARExplorerMode.animal, [Color(0xFFF2A640), Color(0xFFBF7326)]),
    (ARExplorerMode.adventure, [Color(0xFF40CCD9), Color(0xFF6659F2)]),
  ];

  @override
  void initState() {
    super.initState();
    final audio = context.read<AppState>().audioService;
    _speech = KidsSpeechService(isEnabled: () => audio.voiceEnabled && widget.store.progress.voiceGuidance);
    final language = context.read<AppState>().language;
    _speech.speakLine('${ARExplorerText.letsExplore.resolve(language)} ${ARExplorerText.pickAGame.resolve(language)}', language);
  }

  @override
  void dispose() {
    _speech.dispose();
    super.dispose();
  }

  void _tap() {
    context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
    _speech.stop();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final language = appState.language;
    final state = context.watch<EntitlementManager>().state;
    final progress = widget.store.progress;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _explorerGradient),
        child: SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
            Row(children: [
              IconButton(
                tooltip: ARExplorerText.back.resolve(language),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 28),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('🌎 ${ARExplorerText.title.resolve(language)}', style: kid(22, color: Colors.white)),
                ),
              ),
              IconButton(
                tooltip: ARExplorerText.replayIntro.resolve(language),
                onPressed: () => widget.onStart(ExplorerStart(level: ARExplorerLevel.level(1), introOnly: true)),
                icon: const Icon(Icons.info, color: Colors.white, size: 28),
              ),
            ]),
            const SizedBox(height: 12),
            _whiteCard(Row(children: [
              Text(appState.theme.characterEmoji, style: const TextStyle(fontSize: 54)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('“${ARExplorerText.letsExplore.resolve(language)}”', style: kid(20, color: _ink)),
                  Text(ARExplorerText.explorerLevel(progress.explorerLevel).resolve(language),
                      style: kid(14, weight: FontWeight.w600, color: _ink.withValues(alpha: 0.85))),
                ]),
              ),
              Text('⭐ ${progress.starsEarned}', style: kid(18, color: Colors.orange)),
            ])),
            const SizedBox(height: 16),
            _section(ARExplorerText.explorerLevels.resolve(language)),
            SizedBox(
              height: 130,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final level in ARExplorerLevel.all) _levelBadge(level, language, state),
              ]),
            ),
            const SizedBox(height: 12),
            _section(ARExplorerText.playAMode.resolve(language)),
            const SizedBox(height: 4),
            LayoutBuilder(builder: (context, box) {
              final width = (box.maxWidth - 14) / 2;
              return Wrap(spacing: 14, runSpacing: 14, children: [
                for (final (mode, colors) in _tiles) SizedBox(width: width, child: _tile(mode, colors, language, state)),
              ]);
            }),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                _tap();
                widget.onOpenCollection();
              },
              child: _whiteCard(Row(children: [
                const Text('🏡', style: TextStyle(fontSize: 48)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ARExplorerText.myARWorld.resolve(language), style: kid(20, color: _ink)),
                    Text(
                      ARExplorerWorldCatalog.collectibleIDs
                          .where(progress.collection.contains)
                          .map((id) => ARExplorerWorldCatalog.emoji(id) ?? '')
                          .join(),
                      maxLines: 1,
                      style: const TextStyle(fontSize: 22),
                    ),
                    Text(ARExplorerText.itemsCollected(progress.collection.length, ARExplorerWorldCatalog.collectibleIDs.length).resolve(language),
                        style: kid(13, weight: FontWeight.w600, color: _ink.withValues(alpha: 0.85))),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: _ink),
              ])),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _whiteCard(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(24)),
        child: child,
      );

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(header: true, child: Text(text, style: kid(18, color: Colors.white))),
      );

  /// Finished levels show their stars, the next one is open, later ones are locked.
  Widget _levelBadge(ARExplorerLevel level, AppLanguage language, EntitlementState state) {
    final progress = widget.store.progress;
    final unlocked = progress.isLevelUnlocked(level);
    final stars = progress.levelStars[level.number];
    final premium = !PremiumAccess.allows(HomeGame.arHunt, level.number, state);
    return Semantics(
      button: true,
      label: '${ARExplorerText.explorerLevel(level.number).resolve(language)}. ${ARExplorerText.levelName(level.number).resolve(language)}',
      child: GestureDetector(
        onTap: () {
          if (unlocked) {
            _tap();
            widget.onStart(ExplorerStart(level: level));
          } else {
            _speech.speakLine(ARExplorerText.levelLocked.resolve(language), language);
          }
        },
        child: SizedBox(
          width: 84,
          child: Column(children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: unlocked ? 0.95 : 0.35)),
                child: Opacity(opacity: unlocked ? 1 : 0.5, child: Text(level.icon, style: const TextStyle(fontSize: 40))),
              ),
              if (premium)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Color(0xFFF2B226), shape: BoxShape.circle),
                    child: const Text('👑', style: TextStyle(fontSize: 16)),
                  ),
                )
              else if (!unlocked)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                    child: const Icon(Icons.lock, size: 16, color: Colors.white),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            Text('${level.number}', style: kid(14, color: Colors.white)),
            Text(stars == null ? (unlocked ? '▶️' : ' ') : '⭐' * stars, style: const TextStyle(fontSize: 11)),
          ]),
        ),
      ),
    );
  }

  Widget _tile(ARExplorerMode mode, List<Color> colors, AppLanguage language, EntitlementState state) {
    final title = ARExplorerText.modeName(mode).resolve(language);
    final subtitle = ARExplorerText.modeHint(mode).resolve(language);
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: GestureDetector(
        onTap: () {
          _tap();
          widget.onStart(ExplorerStart(mode: mode));
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 190),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 2),
            boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                ),
                child: Text(mode.icon, style: const TextStyle(fontSize: 48)),
              ),
              if (!PremiumAccess.allows(HomeGame.arHunt, mode.unlockLevel, state))
                const Positioned(right: -4, top: -4, child: Text('👑', style: TextStyle(fontSize: 22))),
            ]),
            const SizedBox(height: 8),
            Text(title, maxLines: 2, textAlign: TextAlign.center, style: kid(18, color: Colors.white)),
            const SizedBox(height: 4),
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: kid(12, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.92))),
          ]),
        ),
      ),
    );
  }
}

// Start flow

enum _Step { intro, cameraExplanation, play }

/// Intro (first time for a level) → camera explanation (first time ever) → play.
/// Pops with the next level when the child chose "Next Adventure".
class ARExplorerSessionFlow extends StatefulWidget {
  const ARExplorerSessionFlow({super.key, required this.request, required this.store});
  final ExplorerStart request;
  final ARExplorerProgressStore store;

  @override
  State<ARExplorerSessionFlow> createState() => _ARExplorerSessionFlowState();
}

class _ARExplorerSessionFlowState extends State<ARExplorerSessionFlow> {
  _Step? _step;
  static const _explainedKey = 'arExplorerCameraExplained';

  int get _introLevel => widget.request.level?.number ?? widget.request.mode?.unlockLevel ?? 1;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    final p = widget.store.progress;
    final needsIntro = r.introOnly || !p.hasSeenSafety || (!r.myWorld && !p.seenIntros.contains(_introLevel));
    if (needsIntro) {
      _step = _Step.intro;
    } else {
      _continueAfterIntro();
    }
  }

  Future<void> _continueAfterIntro() async {
    // Explain why the camera is needed once, before Android or iOS asks.
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _step = prefs.getBool(_explainedKey) == true ? _Step.play : _Step.cameraExplanation);
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    switch (_step) {
      case _Step.intro:
        return ARExplorerIntroView(
          levelNumber: _introLevel,
          showSafety: !widget.store.progress.hasSeenSafety || widget.request.introOnly,
          subtitle: widget.request.myWorld ? ARExplorerText.myARWorld.resolve(language) : null,
          onDone: () {
            if (!widget.request.myWorld) widget.store.markIntroSeen(_introLevel);
            widget.store.markSafetySeen();
            if (widget.request.introOnly) {
              Navigator.of(context).pop();
            } else {
              _continueAfterIntro();
            }
          },
        );
      case _Step.cameraExplanation:
        return ARExplorerNoticeView(
          icon: '📷',
          title: ARExplorerText.cameraWhyTitle.resolve(language),
          message: ARExplorerText.cameraWhy.resolve(language),
          language: language,
          primaryTitle: ARExplorerText.continueButton.resolve(language),
          onPrimary: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool(_explainedKey, true);
            if (mounted) setState(() => _step = _Step.play);
          },
          onBack: () => Navigator.of(context).pop(),
        );
      case _Step.play:
        return widget.request.myWorld ? ARExplorerWorldPlaceView(store: widget.store) : _PlayHost(request: widget.request, store: widget.store);
      case null:
        return const Scaffold(backgroundColor: Colors.black);
    }
  }
}

/// Makes the engine and ViewModel for one play session.
class _PlayHost extends StatefulWidget {
  const _PlayHost({required this.request, required this.store});
  final ExplorerStart request;
  final ARExplorerProgressStore store;

  @override
  State<_PlayHost> createState() => _PlayHostState();
}

class _PlayHostState extends State<_PlayHost> {
  late final ARExplorerViewModel _vm;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final progress = context.read<ProgressService>();
    final engine = ARExplorerEngine(showsVirtualContent: ARExplorerViewModel.showsVirtualContent(widget.request.level, widget.request.mode));
    _vm = ARExplorerViewModel(
      level: widget.request.level,
      mode: widget.request.mode,
      language: appState.language,
      engine: engine,
      progressService: progress,
      store: widget.store,
      audioService: appState.audioService,
      childName: progress.progress.childName,
      companionEmoji: appState.theme.characterEmoji,
    )..challengeLanguage = appState.languageOrder.bestOther(appState.language);
  }

  @override
  void dispose() {
    _vm.dispose();
    _vm.engine.disposeScene();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ARExplorerPlayView(viewModel: _vm, store: widget.store);
}

// Friendly notices

/// Full-screen friendly message with a Back button (and an optional primary action).
class ARExplorerNoticeView extends StatelessWidget {
  const ARExplorerNoticeView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.language,
    this.primaryTitle,
    this.onPrimary,
    required this.onBack,
  });
  final String icon, title, message;
  final AppLanguage language;
  final String? primaryTitle;
  final VoidCallback? onPrimary;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF5C4DE6), Color(0xFF339EE6)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(children: [
                    Text(icon, style: const TextStyle(fontSize: 80)),
                    const SizedBox(height: 20),
                    Text(title, textAlign: TextAlign.center, style: kid(26, color: Colors.white)),
                    const SizedBox(height: 20),
                    Text(message, textAlign: TextAlign.center, style: kid(18, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.95))),
                    const SizedBox(height: 20),
                    if (primaryTitle != null && onPrimary != null) ...[
                      _pill(primaryTitle!, Colors.white, const Color(0xFF4D33B3), onPrimary!),
                      const SizedBox(height: 14),
                    ],
                    _pill(ARExplorerText.back.resolve(language), Colors.white.withValues(alpha: 0.2), Colors.white, onBack),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _pill(String text, Color background, Color foreground, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(40)),
          child: Text(text, textAlign: TextAlign.center, style: kid(20, color: foreground)),
        ),
      );
}

// Intro

/// ChihChi's short welcome for an Explorer Level (first time only, replayable from ⓘ). The very
/// first time it also shows the safety note and the four how-to steps.
class ARExplorerIntroView extends StatefulWidget {
  const ARExplorerIntroView({super.key, required this.levelNumber, required this.showSafety, this.subtitle, required this.onDone});
  final int levelNumber;
  final bool showSafety;
  final String? subtitle;
  final VoidCallback onDone;

  @override
  State<ARExplorerIntroView> createState() => _ARExplorerIntroViewState();
}

class _ARExplorerIntroViewState extends State<ARExplorerIntroView> with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  late final KidsSpeechService _speech;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final language = appState.language;
    _speech = KidsSpeechService(isEnabled: () => appState.audioService.voiceEnabled && ARExplorerProgressStore.snapshot().voiceGuidance);
    final lines = [ARExplorerText.welcomeExplorer.resolve(language), _introLine(language)];
    if (widget.showSafety) {
      lines.addAll([
        ARExplorerText.safetyText.resolve(language),
        ARExplorerText.howToMove.resolve(language),
        ARExplorerText.howToPoint.resolve(language),
        ARExplorerText.howToTap.resolve(language),
        ARExplorerText.howToListen.resolve(language),
      ]);
    }
    _speech.speakLine(lines.join(' '), language);
  }

  String _introLine(AppLanguage language) => widget.subtitle ?? ARExplorerText.levelIntro(widget.levelNumber).resolve(language);

  @override
  void dispose() {
    _bounce.dispose();
    _speech.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final language = appState.language;
    final steps = [
      ('👨‍👩‍👧', ARExplorerText.safetyText),
      ('🐢📱', ARExplorerText.howToMove),
      ('👉📦', ARExplorerText.howToPoint),
      ('👆', ARExplorerText.howToTap),
      ('👂🎉', ARExplorerText.howToListen),
    ];
    final icon = widget.subtitle == null ? ARExplorerLevel.level(widget.levelNumber)?.icon ?? '🌎' : '🏡';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF5C4DE6), Color(0xFF339EE6)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(children: [
                  AnimatedBuilder(
                    animation: _bounce,
                    builder: (context, child) => Transform.translate(offset: Offset(0, -12 * _bounce.value), child: child),
                    child: Text(appState.theme.characterEmoji, style: const TextStyle(fontSize: 96)),
                  ),
                  const SizedBox(height: 18),
                  Text(ARExplorerText.welcomeExplorer.resolve(language), textAlign: TextAlign.center, style: kid(30, color: Colors.white)),
                  const SizedBox(height: 12),
                  Text('$icon ${_introLine(language)}', textAlign: TextAlign.center, style: kid(20, weight: FontWeight.w700, color: Colors.white)),
                  if (widget.showSafety) ...[
                    const SizedBox(height: 18),
                    LayoutBuilder(builder: (context, box) {
                      final columns = (box.maxWidth / 150).floor().clamp(1, 4);
                      final width = (box.maxWidth - (columns - 1) * 12) / columns;
                      return Wrap(spacing: 12, runSpacing: 12, children: [
                        for (final (picture, text) in steps)
                          Container(
                            width: width,
                            constraints: const BoxConstraints(minHeight: 110),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(20)),
                            child: Column(children: [
                              Text(picture, style: const TextStyle(fontSize: 46)),
                              const SizedBox(height: 6),
                              Text(text.resolve(language),
                                  textAlign: TextAlign.center, style: kid(12, weight: FontWeight.w600, color: _ink.withValues(alpha: 0.8))),
                            ]),
                          ),
                      ]);
                    }),
                  ],
                  const SizedBox(height: 24),
                  Semantics(
                    button: true,
                    label: ARExplorerText.letsGo.resolve(language),
                    child: GestureDetector(
                      onTap: widget.onDone,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 60),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
