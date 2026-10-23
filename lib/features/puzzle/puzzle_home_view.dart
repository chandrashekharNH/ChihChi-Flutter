import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/store/entitlement_manager.dart';
import '../../core/store/free_uses.dart';
import '../../core/store/premium_access.dart';
import '../../core/ui/kid_text.dart';
import '../../core/ui/palette.dart';
import '../../data/puzzle_content/puzzle_library.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/game_type.dart';
import '../../domain/models/home_game.dart';
import '../../domain/models/puzzle_models.dart';
import '../../domain/models/ui_text.dart';
import '../../services/audio/audio_service.dart';
import '../../services/progress/progress_service.dart';
import '../character/player_marker.dart';
import '../common/breathing_background.dart';
import '../common/play_session_tracking.dart';
import '../common/route_map/game_route_maps.dart';
import '../common/route_map/route_map_top_bar.dart';
import '../common/route_map/route_map_view.dart';
import '../settings/language_switch_button.dart';
import '../store/full_adventure_unlock_flow.dart';
import 'photo_puzzle_card.dart';
import 'puzzle_game_view.dart';

/// "Build the Picture" home: difficulty, the 100-level adventure (10 worlds) and free play.
class PuzzleHomeView extends StatefulWidget {
  const PuzzleHomeView({super.key});

  @override
  State<PuzzleHomeView> createState() => _PuzzleHomeViewState();
}

enum _Tab { adventure, freePlay }

const _purple = Color(0xFF5A33B3);

class _PuzzleHomeViewState extends State<PuzzleHomeView> {
  _Tab _tab = _Tab.adventure;
  PuzzleCategory _category = PuzzleCategory.animals;
  final _barKey = GlobalKey();
  double _barHeight = 260;

  AppState get _app => context.read<AppState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureBar();
      _offerIfDue();
    });
  }

  void _measureBar() {
    final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && mounted && (box.size.height - _barHeight).abs() > 1) setState(() => _barHeight = box.size.height);
  }

  void _offerIfDue() {
    if (!mounted) return;
    FullAdventureUnlockFlow.offerOnceIfDue(context, HomeGame.buildPicture, lastFreeLevelDone: _freeLevelsDone);
  }

  bool get _freeLevelsDone =>
      context.read<ProgressService>().puzzleLevelStars(PremiumAccess.lastFreeLevel(HomeGame.buildPicture) ?? 10) != null;

  void _showUnlock({required bool forFreeUses}) => FullAdventureUnlockFlow.show(context, HomeGame.buildPicture,
      freeLevelsDone: _freeLevelsDone, usedFreeUses: forFreeUses);

  Future<void> _play(PuzzleDefinition puzzle, int? level) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaySessionTracking(
        game: HomeGame.buildPicture,
        child: PuzzleGameView(startPuzzle: puzzle, startLevel: level),
      ),
    ));
    if (mounted) _offerIfDue();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final progress = context.watch<ProgressService>();
    final state = context.watch<EntitlementManager>().state;
    final uses = context.watch<FreeUses>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBar());

    final wide = MediaQuery.sizeOf(context).width >= 900;
    // My Photo Puzzle is free 10 times; after that it asks a grown-up first.
    final photoCard = PhotoPuzzleCard(
      isCompact: true,
      isLocked: !uses.allows(FreeFeature.photoPuzzle, state),
      onLocked: () => _showUnlock(forFreeUses: true),
      onPhoto: (photo) {
        final names = {for (final l in AppLanguage.values) l: UIText.myPhoto.resolve(l)};
        _play(PuzzleDefinition.photo(photo, names), null);
      },
    );

    final bar = RouteMapTopBar(
      key: _barKey,
      title: '🧩 ${UIText.gameTitle(GameType.buildPicture).resolve(language)}',
      onBack: () {
        _app.audioService.playEffect(SoundEffect.buttonTap);
        Navigator.of(context).pop();
      },
      trailing: const [LanguageSwitchButton()],
      accessory: Column(mainAxisSize: MainAxisSize.min, children: [
        // On wide screens (tablets in landscape) difficulty and photo share one row so the
        // header leaves more of the map visible.
        if (wide)
          Row(children: [
            SizedBox(width: 480, child: _difficultyPicker(progress, language)),
            const SizedBox(width: 12),
            Expanded(child: photoCard),
          ])
        else ...[
          _difficultyPicker(progress, language),
          const SizedBox(height: 8),
          photoCard,
        ],
        const SizedBox(height: 8),
        _tabPicker(uses.allows(FreeFeature.freePlay, state), language),
      ]),
    );

    final Widget body = _tab == _Tab.adventure
        ? _adventure(progress, state, language)
        : ListView(
            padding: EdgeInsets.fromLTRB(16, _barHeight + 12, 16, 30),
            children: [_freePlay(progress, uses.allows(FreeFeature.freePlay, state), language)],
          );

    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: BreathingBackground()),
        Positioned.fill(child: body),
        Positioned(left: 0, right: 0, top: 0, child: bar),
      ]),
    );
  }

  Widget _difficultyPicker(ProgressService progress, AppLanguage language) => SizedBox(
        height: 70,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final difficulty in PuzzleDifficulty.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: GestureDetector(
                onTap: () {
                  _app.audioService.playEffect(SoundEffect.buttonTap);
                  progress.setPuzzleDifficulty(difficulty);
                },
                child: () {
                  final selected = progress.puzzleDifficulty == difficulty;
                  final color = selected ? _purple : Colors.white;
                  return Container(
                    width: 88,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(difficulty.icon, style: const TextStyle(fontSize: 22)),
                      FittedBox(child: Text(UIText.difficultyName(difficulty).resolve(language), style: kid(12, weight: FontWeight.w700, color: color))),
                      Text('🧩 ${difficulty.grids.first.pieceCount}–${difficulty.grids.last.pieceCount}',
                          style: kid(10, weight: FontWeight.w600, color: color.withValues(alpha: 0.8))),
                    ]),
                  );
                }(),
              ),
            ),
        ]),
      );

  Widget _tabPicker(bool freePlayAllowed, AppLanguage language) {
    Widget tab(_Tab value, String title) => Expanded(
          child: GestureDetector(
            onTap: () {
              // Free Play is free a few times, then part of Full Adventure.
              if (value == _Tab.freePlay && !freePlayAllowed) {
                _showUnlock(forFreeUses: true);
                return;
              }
              setState(() => _tab = value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: _tab == value ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(30)),
              child: Text(title, textAlign: TextAlign.center, style: kid(15, color: _tab == value ? _purple : Colors.white)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(30)),
      child: Row(children: [
        tab(_Tab.adventure, '🗺 ${UIText.puzzleAdventure.resolve(language)}'),
        tab(_Tab.freePlay, '${freePlayAllowed ? '🎨 ' : '👑 '}${UIText.freePlay.resolve(language)}'),
      ]),
    );
  }

  Widget _adventure(ProgressService progress, EntitlementState state, AppLanguage language) {
    final content = GameRouteMaps.buildPicture(
      worlds: PuzzleLibrary.worlds(language),
      stars: progress.puzzleLevelStars,
      unlocked: progress.isPuzzleLevelUnlocked,
      hasPuzzle: (level) => PuzzleLibrary.adventure(level, language) != null,
      language: language,
    ).markingPremium((level) => PremiumAccess.allows(HomeGame.buildPicture, level, state));
    return RouteMapView(
      key: const ValueKey('buildPicture'),
      content: content,
      markerSpot: content.markerSpot,
      topInset: _barHeight,
      onSelectLevel: (level) {
        final puzzle = PuzzleLibrary.adventure(level, language)?.puzzle;
        if (puzzle == null) return;
        _app.audioService.playEffect(SoundEffect.buttonTap);
        if (!PremiumAccess.allows(HomeGame.buildPicture, level, state)) {
          _showUnlock(forFreeUses: false);
          return;
        }
        _play(puzzle, level);
      },
      marker: const PlayerMarker(fallback: '🧩'),
    );
  }

  Widget _freePlay(ProgressService progress, bool allowed, AppLanguage language) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(UIText.puzzleCount(PuzzleLibrary.all(language).length).resolve(language),
          style: kid(14, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
      const SizedBox(height: 12),
      SizedBox(
        height: 38,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final item in PuzzleCategory.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: GestureDetector(
                onTap: () => setState(() => _category = item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _category == item ? Colors.white : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text('${item.icon} ${UIText.categoryName(item).resolve(language)}',
                      style: kid(14, weight: FontWeight.w700, color: _category == item ? _purple : Colors.white)),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, box) {
        final columns = (box.maxWidth / 106).floor().clamp(2, 8);
        final width = (box.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final puzzle in PuzzleLibrary.puzzles(_category, language))
            GestureDetector(
              onTap: () {
                _app.audioService.playEffect(SoundEffect.buttonTap);
                if (!allowed) {
                  _showUnlock(forFreeUses: true);
                  return;
                }
                _play(puzzle, null);
              },
              child: Container(
                width: width,
                constraints: const BoxConstraints(minHeight: 108),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  PuzzleThumbnail(puzzle: puzzle, size: 40),
                  const SizedBox(height: 4),
                  Text(puzzle.name(language),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: kid(12, weight: FontWeight.w700, color: rgb(0.25, 0.2, 0.4))),
                  Text(progress.puzzleResult(puzzle.id) == null ? ' ' : '⭐${progress.puzzleResult(puzzle.id)!.stars}',
                      style: kid(10, weight: FontWeight.w700, color: Colors.orange)),
                ]),
              ),
            ),
        ]);
      }),
    ]);
  }
}

/// Small picture of a puzzle for maps and lists.
class PuzzleThumbnail extends StatelessWidget {
  const PuzzleThumbnail({super.key, required this.puzzle, required this.size});
  final PuzzleDefinition? puzzle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final subject = puzzle?.subject;
    if (subject is ColorSubject) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: subject.color.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(blurRadius: 1, color: Color(0x55000000))],
        ),
      );
    }
    return SizedBox(
      height: size * 1.15,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(puzzle?.thumbnail ?? '🧩', maxLines: 1, style: kid(size, color: _purple)),
      ),
    );
  }
}
