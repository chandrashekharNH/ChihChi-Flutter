import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/store/entitlement_manager.dart';
import '../../core/store/premium_access.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/catch_letter_level.dart';
import '../../domain/models/game_type.dart';
import '../../domain/models/home_game.dart';
import '../../domain/models/ui_text.dart';
import '../../services/audio/audio_service.dart';
import '../../services/progress/progress_service.dart';
import '../character/player_marker.dart';
import '../common/breathing_background.dart';
import '../common/route_map/game_route_maps.dart';
import '../common/route_map/route_map_content.dart';
import '../common/route_map/route_map_top_bar.dart';
import '../common/route_map/route_map_view.dart';
import '../settings/language_switch_button.dart';
import '../store/full_adventure_unlock_flow.dart';
import 'game_screens.dart';

enum CatchGame {
  catchLetter('🔤', Colors.blue),
  catchWorld('🌍', Colors.purple);

  const CatchGame(this.icon, this.accent);
  final String icon;
  final Color accent;

  String title(AppLanguage l) => (this == catchLetter ? UIText.catchLetter : UIText.catchWorld).resolve(l);
  String subtitle(AppLanguage l) => (this == catchLetter ? UIText.catchLetterSubtitle : UIText.catchWorldSubtitle).resolve(l);
}

/// Level select for the catch games and Learn Blaster: a chooser between Catch Letter and Catch
/// World (unless Home opened one directly), then that game's route map.
class LevelSelectionView extends StatefulWidget {
  const LevelSelectionView({super.key, required this.gameType, this.initialCatchGame});
  final GameType gameType;

  /// Set when Home opens Catch Letter / Catch World directly (skips the chooser).
  final CatchGame? initialCatchGame;

  /// Levels in Catch World and Learn Blaster (also read by the Parent Zone).
  static const totalLevels = 20;

  @override
  State<LevelSelectionView> createState() => _LevelSelectionViewState();
}

class _LevelSelectionViewState extends State<LevelSelectionView> {
  late CatchGame? _catchGame = widget.initialCatchGame;

  bool get _isCatch => widget.gameType == GameType.catchAndLearn;

  /// The game whose level map is shown (Catch World or Learn Blaster), for Full Adventure rules.
  HomeGame get _mapGame => widget.gameType == GameType.learnBlaster3D ? HomeGame.learnBlaster : HomeGame.catchWorld;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerIfDue());
  }

  void _offerIfDue() {
    if (!mounted) return;
    final progress = context.read<ProgressService>();
    if (_isCatch && _catchGame == CatchGame.catchLetter) {
      FullAdventureUnlockFlow.offerOnceIfDue(context, HomeGame.catchLetter,
          lastFreeLevelDone: progress.catchLetterStars(PremiumAccess.lastFreeLevel(HomeGame.catchLetter) ?? 10) != null);
    } else if (!_isCatch || _catchGame == CatchGame.catchWorld) {
      FullAdventureUnlockFlow.offerOnceIfDue(context, _mapGame,
          lastFreeLevelDone: progress.progress.completedLevels.contains(PremiumAccess.lastFreeLevel(_mapGame) ?? 10));
    }
  }

  void _back() {
    context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
    // From a chosen catch game back to the chooser, unless Home opened that game directly.
    if (_isCatch && _catchGame != null && widget.initialCatchGame == null) {
      setState(() => _catchGame = null);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _offerIfDue();
  }

  String _title(AppLanguage language) {
    final game = _catchGame;
    if (_isCatch && game != null) return '${game.icon} ${game.title(language)}';
    return '${widget.gameType.icon} ${UIText.gameTitle(widget.gameType).resolve(language)}';
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    context.watch<ProgressService>();
    context.watch<EntitlementManager>();
    final top = MediaQuery.of(context).padding.top + 76;
    Widget content;
    if (_isCatch && _catchGame == null) {
      content = ListView(padding: EdgeInsets.fromLTRB(20, top, 20, 20), children: [_chooser(language)]);
    } else if (_isCatch && _catchGame == CatchGame.catchLetter) {
      content = _catchLetterMap(language, top);
    } else {
      content = _sharedMap(language, top);
    }
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: BreathingBackground()),
        Positioned.fill(child: content),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: RouteMapTopBar(title: _title(language), onBack: _back, trailing: const [LanguageSwitchButton()]),
        ),
      ]),
    );
  }

  Widget _chooser(AppLanguage language) {
    final appState = context.read<AppState>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(UIText.chooseYourGame.resolve(language), style: kid(24, color: Colors.white)),
      const SizedBox(height: 8),
      Text(UIText.twoWaysToLearn.resolve(language),
          style: kid(15, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85))),
      const SizedBox(height: 14),
      for (final game in CatchGame.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Semantics(
            button: true,
            child: GestureDetector(
              onTap: () {
                appState.audioService.playEffect(SoundEffect.buttonTap);
                setState(() => _catchGame = game);
                WidgetsBinding.instance.addPostFrameCallback((_) => _offerIfDue());
              },
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: appState.theme.cardColor, borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  Container(
                    width: 66,
                    height: 66,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: game.accent.withValues(alpha: 0.16)),
                    child: Text(game.icon, style: const TextStyle(fontSize: 38)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(game.title(language), style: kid(21, color: Colors.black87)),
                      const SizedBox(height: 5),
                      Text(game.subtitle(language), style: kid(13, weight: FontWeight.w500, color: Colors.black54)),
                    ]),
                  ),
                  Icon(Icons.arrow_circle_right, size: 30, color: game.accent),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }

  /// Catch Letter: a route map through 10 worlds × 5 levels, with stars and locks. Tapping a
  /// reached world's landmark replays its introduction.
  Widget _catchLetterMap(AppLanguage language, double top) {
    final progress = context.read<ProgressService>();
    final state = context.read<EntitlementManager>().state;
    final content = GameRouteMaps.catchLetter(
      stars: progress.catchLetterStars,
      unlocked: progress.isCatchLetterLevelUnlocked,
      language: language,
    ).markingPremium((level) => PremiumAccess.allows(HomeGame.catchLetter, level, state));
    return RouteMapView(
      key: const ValueKey('catchLetter'),
      content: content,
      markerSpot: content.markerSpot,
      topInset: top,
      onSelectLevel: (level) {
        context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
        if (PremiumAccess.allows(HomeGame.catchLetter, level, state)) {
          _open(GameScreens.catchLetter(level));
        } else {
          FullAdventureUnlockFlow.show(context, HomeGame.catchLetter,
              freeLevelsDone: progress.catchLetterStars(PremiumAccess.lastFreeLevel(HomeGame.catchLetter) ?? 10) != null);
        }
      },
      onSelectLand: (id) {
        context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
        if (id < 1 || id > CatchLetterBatch.values.length) return;
        final batch = CatchLetterBatch.values[id - 1];
        Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => GameScreens.catchLetterIntro(batch, () {
            progress.markBatchIntroductionSeen(id);
            Navigator.of(context).pop();
          }),
        ));
      },
      marker: const PlayerMarker(fallback: '🐤'),
    );
  }

  /// Learn Blaster and Catch World share one record of opened and finished levels.
  Widget _sharedMap(AppLanguage language, double top) {
    final progress = context.read<ProgressService>().progress;
    final state = context.read<EntitlementManager>().state;
    final game = _mapGame;
    final RouteMapContent base = widget.gameType == GameType.learnBlaster3D
        ? GameRouteMaps.learnBlaster(
            totalLevels: LevelSelectionView.totalLevels,
            highestUnlocked: progress.highestUnlockedLevel,
            completed: progress.completedLevels,
            language: language)
        : GameRouteMaps.catchWorld(
            totalLevels: LevelSelectionView.totalLevels,
            highestUnlocked: progress.highestUnlockedLevel,
            completed: progress.completedLevels,
            language: language);
    final content = base.markingPremium((level) => PremiumAccess.allows(game, level, state));
    return RouteMapView(
      key: ValueKey(game),
      content: content,
      markerSpot: content.markerSpot,
      topInset: top,
      onSelectLevel: (level) {
        context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
        if (PremiumAccess.allows(game, level, state)) {
          _open(widget.gameType == GameType.learnBlaster3D ? GameScreens.learnBlaster(level) : GameScreens.catchWorld(level));
        } else {
          FullAdventureUnlockFlow.show(context, game,
              freeLevelsDone: progress.completedLevels.contains(PremiumAccess.lastFreeLevel(game) ?? 10));
        }
      },
      marker: PlayerMarker(fallback: widget.gameType == GameType.learnBlaster3D ? '🚀' : '🎈'),
    );
  }
}
