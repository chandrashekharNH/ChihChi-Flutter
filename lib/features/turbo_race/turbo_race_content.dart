import 'dart:ui';

import '../../core/localization/localized.dart';
import '../../core/ui/palette.dart';
import '../../domain/models/app_language.dart';
import 'turbo_track.dart';

// World journey

/// A stop on ChihChi's world journey. Races run on the route *to* a destination: races 1–5 drive
/// from Home to Sunny City, races 6–10 on to Forest Town, and so on.
enum TurboDestination {
  home('🏠', 'ChihChi Home'),
  sunnyCity('🏙️', 'Sunny City'),
  forestTown('🌲', 'Forest Town'),
  undergroundCity('🚇', 'Underground City'),
  coastalCity('⛵', 'Coastal City'),
  desertKingdom('🏜️', 'Desert Kingdom'),
  snowCity('❄️', 'Snow City'),
  mountainKingdom('🏔️', 'Mountain Kingdom'),
  dinoValley('🦖', 'Dino Valley'),
  futureCity('🚀', 'Future City'),
  magicKingdom('🏰', 'Magic Kingdom');

  const TurboDestination(this.landmark, this._name);

  /// The destination's landmark, shown on the route map.
  final String landmark;
  final String _name;

  String name(AppLanguage language) => L(_name).resolve(language);

  /// Colours of the destination's land on the route map.
  List<Color> get mapColors => switch (this) {
        home => [rgb(0.55, 0.8, 0.45), rgb(0.4, 0.7, 0.35)],
        sunnyCity => [rgb(0.62, 0.78, 0.95), rgb(0.45, 0.6, 0.85)],
        forestTown => [rgb(0.3, 0.62, 0.3), rgb(0.18, 0.45, 0.22)],
        undergroundCity => [rgb(0.45, 0.4, 0.5), rgb(0.3, 0.26, 0.36)],
        coastalCity => [rgb(0.35, 0.72, 0.9), rgb(0.2, 0.52, 0.8)],
        desertKingdom => [rgb(0.95, 0.8, 0.5), rgb(0.85, 0.62, 0.35)],
        snowCity => [rgb(0.9, 0.95, 1.0), rgb(0.72, 0.84, 0.95)],
        mountainKingdom => [rgb(0.6, 0.62, 0.58), rgb(0.42, 0.45, 0.42)],
        dinoValley => [rgb(0.55, 0.7, 0.3), rgb(0.4, 0.52, 0.2)],
        futureCity => [rgb(0.35, 0.3, 0.7), rgb(0.2, 0.15, 0.5)],
        magicKingdom => [rgb(0.85, 0.6, 0.95), rgb(0.65, 0.4, 0.85)],
      };

  /// Little scenery for each land: trees, houses, boats, cacti, snowmen, dinosaurs…
  List<String> get mapDecorations => switch (this) {
        home => ['🏡', '🌳', '🌷', '🐕'],
        sunnyCity => ['🏢', '🏬', '🚌', '🚦', '🌳', '🚕'],
        forestTown => ['🌲', '🌳', '🦊', '🍄', '🦌'],
        undergroundCity => ['🚇', '💡', '⚡', '🛤️'],
        coastalCity => ['🌊', '⛵', '🐚', '🌴', '🐬'],
        desertKingdom => ['🌵', '🐪', '🏺', '☀️'],
        snowCity => ['⛄', '🌨️', '🏔️', '🐧'],
        mountainKingdom => ['⛰️', '🌉', '🦅', '🌲'],
        dinoValley => ['🦕', '🌋', '🌿', '🥚'],
        futureCity => ['🛸', '🌃', '🤖', '🛰️'],
        magicKingdom => ['🏰', '🌈', '🐉', '✨'],
      };

  /// The five race numbers on the route that ends here (none for Home).
  List<int> get raceNumbers {
    if (index == 0) return const [];
    final first = (index - 1) * TurboRaceCatalog.racesPerRoute + 1;
    return [for (var n = first; n < first + TurboRaceCatalog.racesPerRoute; n++) n];
  }
}

// Race definitions

/// What the scenery along a track looks like.
enum TurboEnvironment { suburbs, downtown, busyCity, cityBridge, sunsetCity }

/// Light and weather for a race.
enum TurboSky { sunny, bright, cloudy, sunset }

/// What the learning gates ask about. `mixed` mixes them all, plus "Which letter starts…?".
enum TurboChallengeKind { letters, colors, numbers, shapes, mixed }

/// The third star: an optional extra goal for each race.
sealed class TurboBonusGoal {
  const TurboBonusGoal();
}

class BonusCollectStars extends TurboBonusGoal {
  const BonusCollectStars(this.count);
  final int count;
}

class BonusFinishTopThree extends TurboBonusGoal {
  const BonusFinishTopThree();
}

class BonusUseBoost extends TurboBonusGoal {
  const BonusUseBoost(this.count);
  final int count;
}

class BonusNoWrongGates extends TurboBonusGoal {
  const BonusNoWrongGates();
}

class BonusWin extends TurboBonusGoal {
  const BonusWin();
}

class TurboRaceDefinition {
  const TurboRaceDefinition({
    required this.number,
    required this.icon,
    required this.names,
    required this.environment,
    required this.sky,
    required this.controlPoints,
    required this.laps,
    required this.learning,
    required this.gatesPerLap,
    required this.gateChoices,
    required this.bonus,
    required this.rivals,
    required this.rivalPace,
    required this.topSpeed,
    required this.starPickups,
    required this.boostPads,
  });

  final int number;
  final String icon;
  final Localized names;
  final TurboEnvironment environment;
  final TurboSky sky;

  /// Closed centre line: control points (x, y, z) in metres.
  final List<V3> controlPoints;
  final int laps;
  final TurboChallengeKind learning;
  final int gatesPerLap;

  /// Choices per gate: 2 for the very first race, then 3.
  final int gateChoices;
  final TurboBonusGoal bonus;
  final int rivals;

  /// Rivals' cruising speed as a share of the player's top speed.
  final double rivalPace;

  /// Player's top speed in m/s.
  final double topSpeed;
  final int starPickups;
  final int boostPads;

  /// The destination this race's route leads to.
  TurboDestination get destination {
    final i = (number - 1) ~/ TurboRaceCatalog.racesPerRoute + 1;
    return i < TurboDestination.values.length ? TurboDestination.values[i] : TurboDestination.magicKingdom;
  }

  /// The last race of a route brings ChihChi to the destination.
  bool get arrivesAtDestination => number % TurboRaceCatalog.racesPerRoute == 0;

  int get totalGates => laps * gatesPerLap;

  /// Correct gates needed for the learning star.
  int get learningGoal => (totalGates * 0.6).ceil();

  String name(AppLanguage language) => names.resolve(language);
}

List<V3> _points(List<List<double>> p) => [for (final v in p) V3(v[0], v[1], v[2])];

class TurboRaceCatalog {
  static const racesPerRoute = 5;
  static const totalRaces = 50;

  /// The races built so far (the route from Home to Sunny City).
  static final List<TurboRaceDefinition> races = _sunnyCityRoute;

  static TurboRaceDefinition? race(int number) => races.where((r) => r.number == number).firstOrNull;

  /// Route 1 — ChihChi Home → Sunny City
  static final _sunnyCityRoute = [
    TurboRaceDefinition(
      number: 1,
      icon: '🏁',
      names: L("ChihChi's First Drive"),
      environment: TurboEnvironment.suburbs,
      sky: TurboSky.sunny,
      controlPoints: _points([
        [0, 0, 0], [80, 0, -10], [150, 0, 10], [190, 0, 70], [170, 0, 140], //
        [100, 0, 170], [20, 0, 160], [-40, 0, 120], [-50, 0, 50],
      ]),
      laps: 2,
      learning: TurboChallengeKind.letters,
      gatesPerLap: 2,
      gateChoices: 2,
      bonus: const BonusCollectStars(5),
      rivals: 3,
      rivalPace: 0.985,
      topSpeed: 22,
      starPickups: 4,
      boostPads: 2,
    ),
    TurboRaceDefinition(
      number: 2,
      icon: '🏙️',
      names: L('Downtown Dash'),
      environment: TurboEnvironment.downtown,
      sky: TurboSky.bright,
      controlPoints: _points([
        [0, 0, 0], [120, 0, 0], [170, 0, 20], [180, 0, 80], [160, 0, 150], //
        [90, 0, 160], [60, 0, 120], [10, 0, 140], [-40, 0, 110], [-50, 0, 40],
      ]),
      laps: 2,
      learning: TurboChallengeKind.colors,
      gatesPerLap: 3,
      gateChoices: 3,
      bonus: const BonusFinishTopThree(),
      rivals: 4,
      rivalPace: 0.99,
      topSpeed: 24,
      starPickups: 3,
      boostPads: 3,
    ),
    TurboRaceDefinition(
      number: 3,
      icon: '🚦',
      names: L('Traffic Light Trouble'),
      environment: TurboEnvironment.busyCity,
      sky: TurboSky.cloudy,
      controlPoints: _points([
        [0, 0, 0], [70, 0, -30], [140, 0, 0], [160, 0, 60], [120, 0, 110], //
        [150, 0, 170], [80, 0, 210], [0, 0, 180], [-30, 0, 120], [20, 0, 70], [-20, 0, 30],
      ]),
      laps: 3,
      learning: TurboChallengeKind.numbers,
      gatesPerLap: 2,
      gateChoices: 3,
      bonus: const BonusUseBoost(2),
      rivals: 4,
      rivalPace: 0.99,
      topSpeed: 24,
      starPickups: 3,
      boostPads: 2,
    ),
    TurboRaceDefinition(
      number: 4,
      icon: '🌉',
      names: L('City Bridge Rush'),
      environment: TurboEnvironment.cityBridge,
      sky: TurboSky.sunny,
      controlPoints: _points([
        [0, 0, 0], [110, 0, -5], [220, 0, 0], [280, 0, 40], [280, 0, 110], //
        [220, 5, 150], [110, 8, 155], [0, 5, 150], [-60, 0, 110], [-60, 0, 40],
      ]),
      laps: 2,
      learning: TurboChallengeKind.shapes,
      gatesPerLap: 3,
      gateChoices: 3,
      bonus: const BonusNoWrongGates(),
      rivals: 5,
      rivalPace: 0.995,
      topSpeed: 26,
      starPickups: 4,
      boostPads: 3,
    ),
    TurboRaceDefinition(
      number: 5,
      icon: '🌆',
      names: L('Sunset City Sprint'),
      environment: TurboEnvironment.sunsetCity,
      sky: TurboSky.sunset,
      controlPoints: _points([
        [0, 0, 0], [100, 0, -40], [200, 0, -20], [260, 0, 50], [240, 0, 140], //
        [170, 0, 180], [120, 0, 140], [60, 0, 190], [-20, 0, 170], [-70, 0, 100], [-60, 0, 30],
      ]),
      laps: 2,
      learning: TurboChallengeKind.mixed,
      gatesPerLap: 3,
      gateChoices: 3,
      bonus: const BonusWin(),
      rivals: 5,
      rivalPace: 1.0,
      topSpeed: 28,
      starPickups: 4,
      boostPads: 4,
    ),
  ];
}

// Racers

/// ChihChi and friends. Index 0 is always the player.
class TurboRacer {
  const TurboRacer(this.face, this._name, this.paint);
  final String face;
  final String _name;
  final Color paint;

  String name(AppLanguage language) => L(_name).resolve(language);

  /// Who drives car `index` (car 0 is always ChihChi).
  static TurboRacer forCar(int index) => all[index % all.length];

  static final all = [
    TurboRacer('🐼', 'ChihChi', rgb(1.0, 0.36, 0.2)),
    TurboRacer('🐱', 'Mimi', rgb(0.95, 0.4, 0.75)),
    TurboRacer('🐶', 'Bruno', rgb(0.2, 0.5, 0.95)),
    TurboRacer('🐰', 'Coco', rgb(0.98, 0.8, 0.15)),
    TurboRacer('🦊', 'Foxy', rgb(0.95, 0.55, 0.1)),
    TurboRacer('🐥', 'Pip', rgb(0.3, 0.8, 0.45)),
  ];
}
