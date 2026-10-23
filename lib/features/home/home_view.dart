import 'dart:math' as math;

import 'package:chihchi/core/ui/emoji_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/game_type.dart';
import '../../domain/models/home_game.dart';
import '../../domain/models/ui_text.dart';
import '../../domain/models/world_theme.dart';
import '../../data/storage/player_progress.dart';
import '../../services/audio/audio_service.dart';
import '../../services/progress/progress_service.dart';
import '../../services/update/app_update_service.dart';
import '../character/character_text.dart';
import '../character/character_view.dart';
import '../character/player_character_store.dart';
import '../common/breathing_background.dart';
import '../levels/game_screens.dart';
import '../levels/level_selection_view.dart';
import '../parent/parent_settings_view.dart';
import '../parent/parent_text.dart';
import '../parent/parent_zone_view.dart';
import '../progress/progress_view.dart';
import '../rewards/rewards_view.dart';
import '../settings/language_switch_button.dart';
import '../settings/settings_view.dart';
import 'home_game_text.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 12));
  final Map<HomeGame, double> _cardScale = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || MediaQuery.of(context).disableAnimations) return;
      _float.repeat(reverse: true);
      _breath.repeat(reverse: true);
      _ambient.repeat();
    });
  }

  @override
  void dispose() {
    _float.dispose();
    _breath.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _tap() => context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _openGame(HomeGame game) async {
    _tap();
    setState(() => _cardScale[game] = 0.94);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() => _cardScale[game] = 1);
    switch (game) {
      case HomeGame.catchLetter:
        _push(const LevelSelectionView(gameType: GameType.catchAndLearn, initialCatchGame: CatchGame.catchLetter));
      case HomeGame.catchWorld:
        _push(const LevelSelectionView(gameType: GameType.catchAndLearn, initialCatchGame: CatchGame.catchWorld));
      case HomeGame.learnBlaster:
        _push(const LevelSelectionView(gameType: GameType.learnBlaster3D));
      case HomeGame.buildPicture:
        _push(GameScreens.buildPicture());
      case HomeGame.arHunt:
        _push(GameScreens.arExplorer());
      case HomeGame.turboRace:
        _push(GameScreens.turboRace());
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final progress = context.watch<ProgressService>();
    final update = context.watch<AppUpdateService>().availableUpdate;
    final language = appState.language;
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: BreathingBackground()),
        Positioned.fill(child: _ambientLayer(appState.theme)),
        SafeArea(
          bottom: false,
          child: Column(children: [
            _topBar(language),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                // A new language refreshes the whole screen with a quick fade.
                child: ListView(
                  key: ValueKey(language),
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    _characterSection(appState, progress),
                    const SizedBox(height: 20),
                    _worldBadge(appState, progress),
                    const SizedBox(height: 20),
                    _rewardsMiniBar(appState, progress.progress),
                    const SizedBox(height: 20),
                    _gameCards(appState),
                    const SizedBox(height: 20),
                    _bottomActions(appState),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ParentZoneEntryButton(
                        language: language,
                        showsUpdateBadge: update != null,
                        onTap: () => ParentZoneView.open(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  /// Positions are fractions of the screen, so the emojis spread out on any phone or tablet.
  Widget _ambientLayer(WorldTheme theme) {
    const sizes = [36.0, 28.0, 44.0, 24.0, 32.0];
    const xs = [0.15, 0.82, 0.46, 0.9, 0.26];
    const ys = [0.14, 0.24, 0.47, 0.59, 0.77];
    const swings = [-15.0, 12.0, -18.0, 10.0, -12.0];
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, c) => AnimatedBuilder(
            animation: _ambient,
            builder: (context, _) => Stack(children: [
              for (var i = 0; i < theme.ambientEmojis.length; i++)
                Positioned(
                  left: c.maxWidth * xs[i % 5] - sizes[i % 5] / 2,
                  top: c.maxHeight * ys[i % 5] +
                      swings[i % 5] * math.sin(2 * math.pi * _ambient.value * (12 / (3 + 0.3 * i)) + i),
                  child: Opacity(
                    opacity: 0.18,
                    child: Text(theme.ambientEmojis[i], style: TextStyle(fontSize: sizes[i % 5])),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _topBar(dynamic language) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Row(children: [
          const Text('🌈', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(UIText.appName.resolve(language), style: kid(18, color: Colors.white, shadows: softTextShadow)),
          ),
          const LanguageSwitchButton(),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: UIText.settings.resolve(language),
            child: GestureDetector(
              onTap: () {
                _tap();
                _push(const SettingsView());
              },
              child: Icon(Icons.settings, size: 24, color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
        ]),
      );

  /// The child's own character when they made one (tap to change it), else ChihChi's world emoji
  /// with a small invitation to make one.
  Widget _characterSection(AppState appState, ProgressService progress) {
    final store = context.watch<PlayerCharacterStore>();
    final language = appState.language;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: [
        if (progress.profiles.length > 1) ...[_playerSwitch(progress, language), const SizedBox(height: 8)],
        if (store.isEnabled)
          Semantics(
            button: true,
            label: CharacterText.myCharacter.resolve(language),
            child: GestureDetector(
              onTap: () {
                _tap();
                openCharacterStudio(context);
              },
              child: SizedBox(
                width: 170,
                height: 190,
                child: CharacterSceneView(
                  appearance: store.appearance,
                  animation: CharacterAnimation.wave,
                  allowsTurning: false,
                ),
              ),
            ),
          )
        else ...[
          AnimatedBuilder(
            animation: _float,
            builder: (context, child) => Transform.translate(offset: Offset(0, -10 * _float.value), child: child),
            child: Text(appState.theme.characterEmoji,
                style: const TextStyle(fontSize: 70, shadows: [Shadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 4))])),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              _tap();
              openCharacterStudio(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              // Dark see-through pill: the background shifts colour, white text needs contrast on all of them.
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(30)),
              child: Text('✨ ${CharacterText.createMyCharacter.resolve(language)}', style: kid(14, color: Colors.white)),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(30)),
          child: Text(UIText.world(appState.theme.id).resolve(language),
              style: kid(16, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
        ),
      ]),
    );
  }

  /// Who is playing, with a quick switch — shown once a second child has been added.
  Widget _playerSwitch(ProgressService progress, dynamic language) {
    String nameOf(PlayerProgress child) =>
        child.childName.isEmpty ? ParentText.nicknamePlaceholder.resolve(language) : child.childName;
    final current = progress.progress;
    return PopupMenuButton<String>(
      onSelected: progress.switchProfile,
      itemBuilder: (context) => [
        for (final child in progress.profiles)
          PopupMenuItem(
            value: child.profileID,
            child: Row(children: [
              Icon(child.profileID == progress.activeProfileID ? Icons.check : Icons.person, size: 18),
              const SizedBox(width: 8),
              Text(nameOf(child)),
            ]),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(current.childAvatar.isEmpty ? '🐼' : current.childAvatar, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Flexible(child: Text(nameOf(current), maxLines: 1, overflow: TextOverflow.ellipsis, style: kid(15, color: Colors.white))),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white),
        ]),
      ),
    );
  }

  Widget _worldBadge(AppState appState, ProgressService progress) => ExcludeSemantics(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final theme in WorldTheme.all.take(3))
            () {
              final active = appState.theme.id == theme.id;
              final unlocked = progress.progress.highestUnlockedLevel > theme.id.requiredLevel;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: AnimatedScale(
                  scale: active ? 1.15 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: Opacity(
                    opacity: active ? 1 : (unlocked ? 0.6 : 0.25),
                    child: EmojiText(theme.characterEmoji, size: active ? 26 : 18),
                  ),
                ),
              );
            }(),
        ]),
      );

  Widget _rewardsMiniBar(AppState appState, PlayerProgress p) {
    final theme = appState.theme;
    Widget mini(String emoji, int count) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 3),
            Text('$count', style: kid(14, weight: FontWeight.w700, color: theme.primaryColor)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: () {
            _tap();
            _push(const RewardsView());
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 3))],
            ),
            child: Row(children: [
              mini('⭐', p.stars),
              mini('🍭', p.candy),
              mini('🍦', p.iceCream),
              mini('🍫', p.chocolate),
              const Spacer(),
              Text(UIText.seeAll.resolve(appState.language), style: kid(13, weight: FontWeight.w700, color: theme.primaryColor)),
              Icon(Icons.chevron_right, size: 16, color: theme.primaryColor),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _gameCards(AppState appState) {
    final games = HomeGame.values;
    final paired = games.length - games.length % 2;
    final rows = <Widget>[];
    for (var i = 0; i < paired; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _gameTile(games[i], i, appState)),
            const SizedBox(width: 14),
            Expanded(child: _gameTile(games[i + 1], i + 1, appState)),
          ]),
        ),
      ));
    }
    // An odd last game gets a full-width tile instead of leaving a gap.
    if (paired < games.length) rows.add(_gameTile(games.last, paired, appState));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(UIText.games.resolve(appState.language), style: kid(18, color: Colors.white)),
        const SizedBox(height: 12),
        ...rows,
      ]),
    );
  }

  Widget _gameTile(HomeGame game, int index, AppState appState) {
    final language = appState.language;
    return Semantics(
      button: true,
      label: '${game.title(language)}. ${game.subtitle(language)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _openGame(game),
        child: AnimatedOpacity(
          opacity: (_cardScale[game] ?? 1) < 1 ? 0.75 : 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            constraints: const BoxConstraints(minHeight: 210),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: game.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 2),
              boxShadow: [BoxShadow(color: game.colors.last.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 6))],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedBuilder(
                animation: _breath,
                builder: (context, child) {
                  final phase = (_breath.value + index * 0.15) % 1;
                  return Transform.scale(scale: 0.96 + 0.1 * (0.5 - 0.5 * math.cos(phase * 2 * math.pi)), child: child);
                },
                child: Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                  ),
                  child: EmojiText(game.icon, size: 44),
                ),
              ),
              const SizedBox(height: 8),
              Text(game.title(language), textAlign: TextAlign.center, maxLines: 2, style: kid(16, color: Colors.white)),
              const SizedBox(height: 8),
              Text(game.subtitle(language),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: kid(11, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
              const SizedBox(height: 8),
              const Icon(Icons.play_circle_fill, size: 28, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bottomActions(AppState appState) {
    Widget action(String emoji, String title, Widget page) => Expanded(
          child: Semantics(
            button: true,
            child: GestureDetector(
              onTap: () {
                _tap();
                _push(page);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: appState.theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 5)],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Flexible(child: Text(title, style: kid(15, weight: FontWeight.w700, color: appState.theme.primaryColor))),
                ]),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(children: [
        action('📈', UIText.progress.resolve(appState.language), const ProgressView()),
        const SizedBox(width: 14),
        action('🎁', UIText.rewards.resolve(appState.language), const RewardsView()),
      ]),
    );
  }
}
