import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/store/entitlement_manager.dart';
import '../../core/store/premium_access.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/home_game.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/kids_speech_service.dart';
import '../../services/progress/progress_service.dart';
import '../character/player_marker.dart';
import '../common/play_session_tracking.dart';
import '../common/route_map/route_map_content.dart';
import '../common/route_map/route_map_top_bar.dart';
import '../common/route_map/route_map_view.dart';
import '../settings/language_switch_button.dart';
import '../store/full_adventure_unlock_flow.dart';
import 'turbo_race_content.dart';
import 'turbo_race_progress_store.dart';
import 'turbo_race_text.dart';
import 'turbo_race_view.dart';

extension TurboRouteMap on TurboRaceProgress {
  /// The world journey as a route map: Home at the bottom, one land per destination with its five races.
  RouteMapContent routeMapContent(AppLanguage language) {
    final home = TurboDestination.home;
    return RouteMapContent(
      start: RouteMapHub(home.landmark, home.name(language)),
      startColors: home.mapColors,
      startDecorations: home.mapDecorations,
      lands: [
        for (final d in TurboDestination.values.skip(1))
          RouteMapLand(
            id: d.index,
            hub: RouteMapHub(d.landmark, d.name(language)),
            colors: d.mapColors,
            decorations: d.mapDecorations,
            isReached: d.index <= currentDestination.index,
            stops: [for (final n in d.raceNumbers) _stop(n, language)],
          ),
      ],
      openColor: const Color.fromRGBO(255, 128, 38, 1),
    );
  }

  /// Where ChihChi's car waits: the next race, or the furthest destination once every built race is done.
  RouteMapSpot get mapSpot {
    if (!isCompleted(nextRace)) return RouteMapSpot.level(nextRace);
    return currentDestination == TurboDestination.home ? RouteMapSpot.start : RouteMapSpot.hub(currentDestination.index);
  }

  RouteMapStop _stop(int number, AppLanguage language) {
    final race = TurboRaceCatalog.race(number);
    final result = results[number];
    final state = result != null
        ? RouteMapStopState.completed(result.stars)
        : (isUnlocked(number) ? RouteMapStopState.open : RouteMapStopState.locked);
    final name = race?.name(language) ?? TurboRaceText.comingSoon.resolve(language);
    final stars = result == null ? '' : ' ${result.stars} ⭐';
    return RouteMapStop(
      level: number,
      icon: race?.icon ?? '🏁',
      state: state,
      title: race?.name(language),
      lockedCaption: race == null ? TurboRaceText.comingSoon.resolve(language) : null,
      accessibilityLabel: '${TurboRaceText.raceNumber(number).resolve(language)}, $name$stars',
    );
  }
}

/// The world journey: one tall map from ChihChi Home (bottom) to the Magic Kingdom (top). ChihChi's
/// car waits at the next race and drives on after each finish. The world is the level select.
class TurboWorldMapView extends StatefulWidget {
  const TurboWorldMapView({super.key});

  @override
  State<TurboWorldMapView> createState() => _TurboWorldMapViewState();
}

class _TurboWorldMapViewState extends State<TurboWorldMapView> {
  final _store = TurboRaceProgressStore();
  late final KidsSpeechService _speech;
  late RouteMapSpot _carStop = _store.progress.mapSpot;
  TurboDestination? _arrival;

  @override
  void initState() {
    super.initState();
    final audio = context.read<AppState>().audioService;
    _speech = KidsSpeechService(childName: context.read<ProgressService>().progress.childName, isEnabled: () => audio.voiceEnabled);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FullAdventureUnlockFlow.offerOnceIfDue(context, HomeGame.turboRace, lastFreeLevelDone: _freeLevelsDone);
    });
  }

  @override
  void dispose() {
    _speech.dispose();
    _store.dispose();
    super.dispose();
  }

  bool get _freeLevelsDone => _store.progress.isCompleted(PremiumAccess.lastFreeLevel(HomeGame.turboRace) ?? 10);

  Future<void> _race(TurboRaceDefinition race) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaySessionTracking(game: HomeGame.turboRace, child: TurboRaceView(race: race, store: _store)),
    ));
    if (mounted) _journeyAfterRace();
  }

  /// Back on the map: move the car to its new stop, and celebrate a new destination.
  void _journeyAfterRace() {
    final newStop = _store.progress.mapSpot;
    if (newStop == _carStop) {
      setState(() {});
      return;
    }
    final wasAt = _carStop;
    final reached = _store.progress.currentDestination;
    setState(() => _carStop = newStop);
    if (wasAt.isLevel && TurboRaceCatalog.race(wasAt.value)?.arrivesAtDestination == true && _store.progress.isCompleted(wasAt.value)) {
      final language = context.read<AppState>().language;
      _speech.speakLine(TurboRaceText.sayWeMadeIt(reached.name(language)).resolve(language), language, usingName: true);
      setState(() => _arrival = reached);
      Future<void>.delayed(const Duration(milliseconds: 3500), () {
        if (mounted) setState(() => _arrival = null);
      });
    }
  }

  void _select(int number) {
    final race = TurboRaceCatalog.race(number);
    if (race == null) return;
    context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
    if (!PremiumAccess.allows(HomeGame.turboRace, number, context.read<EntitlementManager>().state)) {
      FullAdventureUnlockFlow.show(context, HomeGame.turboRace, freeLevelsDone: _freeLevelsDone);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => _RaceDetailSheet(
        race: race,
        result: _store.progress.results[number],
        language: context.read<AppState>().language,
        onStart: () {
          Navigator.of(sheet).pop();
          _race(race);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final state = context.watch<EntitlementManager>().state;
    final content = _store.progress.routeMapContent(language).markingPremium((level) => PremiumAccess.allows(HomeGame.turboRace, level, state));
    final top = MediaQuery.of(context).padding.top + 92;
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF73B8FF), Color(0xFFBFE6FF)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
          ),
        ),
        Positioned.fill(
          child: RouteMapView(
            key: const ValueKey('turbo'),
            content: content,
            markerSpot: _carStop,
            topInset: top,
            onSelectLevel: _select,
            marker: const _MapCar(),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: RouteMapTopBar(
            title: '🏎️ ${TurboRaceText.title.resolve(language)}',
            subtitle: TurboRaceText.worldJourney.resolve(language),
            onBack: () {
              context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
              Navigator.of(context).pop();
            },
            trailing: [
              const LanguageSwitchButton(),
              const SizedBox(width: 8),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(30)),
                child: Text('⭐ ${_store.progress.totalStars}', style: kid(18, color: Colors.white)),
              ),
            ],
          ),
        ),
        if (_arrival != null)
          Positioned(
            top: top,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.orange, Colors.pink]),
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 10, offset: Offset(0, 5))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_arrival!.landmark, style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 12),
                  Flexible(child: Text(TurboRaceText.welcomeTo(_arrival!.name(language)).resolve(language), style: kid(22, color: Colors.white))),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// ChihChi's car on the map, driven by the child's character when they made one.
class _MapCar extends StatelessWidget {
  const _MapCar();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox(
          width: 60,
          height: 60,
          child: Stack(alignment: Alignment.center, children: [
            Transform.flip(flipX: true, child: const Text('🏎️', style: TextStyle(fontSize: 46))),
            const Positioned(top: 0, child: PlayerMarker(fallback: '🐼', size: 24)),
          ]),
        ),
      );
}

/// Before a race: its name, what it teaches, the star goals and the best result so far.
class _RaceDetailSheet extends StatelessWidget {
  const _RaceDetailSheet({required this.race, required this.result, required this.language, required this.onStart});
  final TurboRaceDefinition race;
  final TurboRaceResult? result;
  final AppLanguage language;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(18)),
              child: Text(race.icon, style: const TextStyle(fontSize: 44)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(TurboRaceText.raceNumber(race.number).resolve(language).toUpperCase(), style: kid(13, weight: FontWeight.w800, color: Colors.orange)),
                Text(race.name(language), style: kid(24, color: Colors.black87)),
                Text('🏠 → ${race.destination.landmark} ${race.destination.name(language)}',
                    style: kid(14, weight: FontWeight.w600, color: Colors.black54)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1F244D), borderRadius: BorderRadius.circular(16)),
            child: TurboRaceGoalList(race: race, language: language, achieved: r == null ? null : [for (var i = 0; i < 3; i++) i < r.stars]),
          ),
          if (r != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.timer, color: Colors.black54, size: 18),
              const SizedBox(width: 4),
              Text(formatRaceTime(r.bestTime), style: kid(15, weight: FontWeight.w700, color: Colors.black54)),
              const Spacer(),
              const Icon(Icons.flag, color: Colors.black54, size: 18),
              const SizedBox(width: 4),
              Text(TurboRaceText.place(r.bestPosition).resolve(language), style: kid(15, weight: FontWeight.w700, color: Colors.black54)),
            ]),
          ],
          const SizedBox(height: 18),
          TurboRaceButton(title: TurboRaceText.startRace.resolve(language), icon: Icons.flag, primary: true, onTap: onStart),
        ]),
      ),
    );
  }
}
