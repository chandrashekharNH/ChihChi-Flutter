import 'dart:ui';

/// A landmark on the map: the start at the bottom, or the hub at the top of each land.
class RouteMapHub {
  const RouteMapHub(this.landmark, this.name);
  final String landmark;
  final String name;
}

enum RouteMapStopKind {
  locked,
  open,

  /// `stars` is null for games that only remember that a level was finished.
  completed,

  /// Part of ChihChi Full Adventure. Tapping it asks a grown-up (never starts the level).
  premium,
}

class RouteMapStopState {
  const RouteMapStopState._(this.kind, [this.stars]);
  static const locked = RouteMapStopState._(RouteMapStopKind.locked);
  static const open = RouteMapStopState._(RouteMapStopKind.open);
  static const premium = RouteMapStopState._(RouteMapStopKind.premium);
  const RouteMapStopState.completed([int? stars]) : this._(RouteMapStopKind.completed, stars);

  final RouteMapStopKind kind;
  final int? stars;

  bool get isCompleted => kind == RouteMapStopKind.completed;

  @override
  bool operator ==(Object other) => other is RouteMapStopState && other.kind == kind && other.stars == stars;
  @override
  int get hashCode => Object.hash(kind, stars);
}

/// One level on the road.
class RouteMapStop {
  const RouteMapStop({
    required this.level,
    required this.icon,
    required this.state,
    this.title,
    this.lockedCaption,
    required this.accessibilityLabel,
  });

  final int level;

  /// Shown on the stop while it is open.
  final String icon;
  final RouteMapStopState state;

  /// Shown under an open stop (e.g. the race name).
  final String? title;

  /// Shown under a locked stop (e.g. "Coming soon").
  final String? lockedCaption;
  final String accessibilityLabel;

  bool get isPlayable => state != RouteMapStopState.locked;
}

/// One land of the map: its stops climb through it and end at its hub.
class RouteMapLand {
  const RouteMapLand({
    required this.id,
    required this.hub,
    required this.colors,
    required this.decorations,
    required this.isReached,
    required this.stops,
  });

  final int id;
  final RouteMapHub hub;
  final List<Color> colors;
  final List<String> decorations;

  /// Lands not reached yet are drawn dimmer.
  final bool isReached;
  final List<RouteMapStop> stops;
}

/// A position on the map.
class RouteMapSpot {
  const RouteMapSpot._(this.kind, this.value);
  static const start = RouteMapSpot._(0, 0);
  const RouteMapSpot.level(int level) : this._(1, level);

  /// A land's hub, by land id.
  const RouteMapSpot.hub(int land) : this._(2, land);

  final int kind;
  final int value;

  bool get isStart => kind == 0;
  bool get isLevel => kind == 1;
  bool get isHub => kind == 2;

  @override
  bool operator ==(Object other) => other is RouteMapSpot && other.kind == kind && other.value == value;
  @override
  int get hashCode => Object.hash(kind, value);
}

/// Everything a game's route map shows. Games build it from their own progress.
class RouteMapContent {
  const RouteMapContent({
    required this.start,
    required this.startColors,
    required this.startDecorations,
    required this.lands,
    required this.openColor,
  });

  final RouteMapHub start;
  final List<Color> startColors;
  final List<String> startDecorations;

  /// Bottom to top.
  final List<RouteMapLand> lands;

  /// Fill of stops that can be played but aren't finished.
  final Color openColor;

  /// Every spot in travel order: the start, then each land's levels and its hub.
  List<RouteMapSpot> get journey => [
        RouteMapSpot.start,
        for (final land in lands) ...[
          for (final stop in land.stops) RouteMapSpot.level(stop.level),
          RouteMapSpot.hub(land.id),
        ],
      ];

  /// Where the marker waits: the first level still to play, else the furthest land reached.
  RouteMapSpot get markerSpot {
    for (final land in lands) {
      for (final stop in land.stops) {
        if (stop.state == RouteMapStopState.open) return RouteMapSpot.level(stop.level);
      }
    }
    for (final land in lands.reversed) {
      if (land.isReached) return RouteMapSpot.hub(land.id);
    }
    return RouteMapSpot.start;
  }

  RouteMapStop? stop(int level) {
    for (final land in lands) {
      for (final s in land.stops) {
        if (s.level == level) return s;
      }
    }
    return null;
  }

  /// The same map with every level the child may not play shown as Full Adventure (👑).
  /// Progress isn't changed: a finished premium level still counts as finished.
  RouteMapContent markingPremium(bool Function(int level) allows) => RouteMapContent(
        start: start,
        startColors: startColors,
        startDecorations: startDecorations,
        openColor: openColor,
        lands: [
          for (final land in lands)
            RouteMapLand(
              id: land.id,
              hub: land.hub,
              colors: land.colors,
              decorations: land.decorations,
              isReached: land.isReached,
              stops: [
                for (final s in land.stops)
                  allows(s.level)
                      ? s
                      : RouteMapStop(
                          level: s.level,
                          icon: s.icon,
                          state: RouteMapStopState.premium,
                          accessibilityLabel: s.accessibilityLabel,
                        ),
              ],
            ),
        ],
      );
}

/// Where every spot sits on the tall map. The start is at the bottom; each land's levels climb in
/// a gentle zig-zag and end at the land's hub. Lands grow with their number of levels, so the
/// height doesn't depend on the width.
class RouteMapLayout {
  static const double startHeight = 260;
  static const double _firstStopInset = 70;
  static const double _stopSpacing = 88;
  static const double _hubInset = 110;

  /// 5 levels → 620, the size of a Turbo Race land.
  static double landHeightFor(int stopCount) =>
      _firstStopInset + ((stopCount < 1 ? 1 : stopCount) - 1) * _stopSpacing + _stopSpacing + _hubInset;

  RouteMapLayout(this.width, this.content) {
    final heights = [for (final land in content.lands) landHeightFor(land.stops.length)];
    height = startHeight + heights.fold<double>(0, (a, b) => a + b);
    var bottom = height - startHeight;
    for (final h in heights) {
      bottom -= h;
      _landTops.add(bottom);
    }
    for (var i = 0; i < content.lands.length; i++) {
      _landIndexByID.putIfAbsent(content.lands[i].id, () => i);
      for (var step = 0; step < content.lands[i].stops.length; step++) {
        _stopPlaces[content.lands[i].stops[step].level] = (i, step);
      }
    }
  }

  final double width;
  final RouteMapContent content;
  late final double height;
  final List<double> _landTops = [];
  final Map<int, int> _landIndexByID = {};
  final Map<int, (int land, int step)> _stopPlaces = {};

  /// Top edge of a land, by its index in `content.lands`.
  double landTop(int index) => _landTops[index];
  double landHeight(int index) => landHeightFor(content.lands[index].stops.length);

  Offset point(RouteMapSpot spot) {
    if (spot.isStart) return Offset(width * 0.5, height - startHeight * 0.45);
    if (spot.isHub) {
      final index = _landIndexByID[spot.value];
      if (index == null) return point(RouteMapSpot.start);
      return Offset(width * 0.5, _landTops[index] + _hubInset);
    }
    final place = _stopPlaces[spot.value];
    if (place == null) return point(RouteMapSpot.start);
    final bottom = _landTops[place.$1] + landHeight(place.$1);
    final y = bottom - _firstStopInset - place.$2 * _stopSpacing;
    final x = width * (0.5 + (place.$2.isEven ? -0.24 : 0.24));
    return Offset(x, y);
  }
}
