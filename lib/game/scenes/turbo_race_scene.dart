import 'dart:math' as math;
import 'dart:ui';

import '../../core/ui/palette.dart';
import '../../core/ui/seeded_random.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/catch_letter_level.dart';
import '../../features/turbo_race/turbo_race_content.dart';
import '../../features/turbo_race/turbo_race_learning.dart';
import '../../features/turbo_race/turbo_race_simulation.dart';
import '../../features/turbo_race/turbo_track.dart';
import '../engine/draw.dart';
import '../engine/game_scene.dart';

const _up = V3(0, 1, 0);

enum _PropKind { house, tree, bush, tower, parkedCar, lamp, trafficLight, pillar }

class _Prop {
  _Prop(this.kind, this.position, this.forward, {this.width = 0, this.height = 0, this.depth = 0, this.color = const Color(0xFFFFFFFF), this.seed = 0});
  final _PropKind kind;
  final V3 position;
  final V3 forward;
  final double width, height, depth;
  final Color color;
  final int seed;
}

class _GateView {
  _GateView(this.progress, this.challenge);
  final double progress;
  final TurboChallenge challenge;
  double age = 0;
  int? choice;
  double resolvedAge = 0;
  bool get resolved => choice != null;
}

class _Confetti {
  _Confetti(this.position, this.velocity, this.color);
  Offset position, velocity;
  final Color color;
  double age = 0;
}

/// A point in camera space.
class _C {
  const _C(this.x, this.y, this.z);
  final double x, y, z;
}

/// Draws a Turbo Race with a chase camera: sky, hills or skyline, the road with kerbs and barriers,
/// scenery, cars, learning gates, stars and boost pads, all projected from 3D and drawn far to near.
/// It only shows what `TurboRaceSimulation` computes; the rules live there and in the ViewModel.
class TurboRaceScene extends GameScene {
  TurboRaceScene(this.race, this.simulation, this.language) : track = simulation.track {
    _buildScenery();
  }

  final TurboRaceDefinition race;
  final TurboRaceSimulation simulation;
  final TurboTrack track;
  AppLanguage language;

  /// Called every frame with real seconds; the ViewModel runs the race from here.
  void Function(double dt)? onFrame;

  /// The child's own character's face for ChihChi's car, when they made one.
  Image? playerFace;

  /// Steering for the front wheels (−1…1), set by the ViewModel.
  double steer = 0;

  // Camera
  V3 _camPos = const V3(0, 3, 10);
  V3 _f = const V3(0, 0, -1), _r = const V3(1, 0, 0), _u = _up;
  double _focal = 400;
  double _fovExtra = 0;
  bool _hasCamera = false;
  bool introMode = true;
  double introProgress = 0;

  static const _near = 0.3;
  late final double _fogStart = race.sky == TurboSky.sunset ? 70 : 95;
  late final double _fogEnd = race.sky == TurboSky.sunset ? 280 : 330;

  final List<_Prop> _props = [];
  final Map<int, _GateView> _gates = {};
  final Map<int, double> _collecting = {};
  final List<_Confetti> _confetti = [];
  double _hop = 0;
  final _random = math.Random();

  // Colours
  late final (Color, Color) _sky = switch (race.sky) {
    TurboSky.sunny => (rgb(0.25, 0.55, 0.95), rgb(0.78, 0.9, 1)),
    TurboSky.bright => (rgb(0.3, 0.62, 1), rgb(0.86, 0.94, 1)),
    TurboSky.cloudy => (rgb(0.5, 0.6, 0.72), rgb(0.82, 0.86, 0.9)),
    TurboSky.sunset => (rgb(0.35, 0.25, 0.6), rgb(1, 0.62, 0.35)),
  };
  Color get _horizon => _sky.$2;
  late final Color _ground = switch (race.environment) {
    TurboEnvironment.suburbs => rgb(0.42, 0.68, 0.32),
    TurboEnvironment.downtown => rgb(0.62, 0.64, 0.62),
    TurboEnvironment.busyCity => rgb(0.58, 0.6, 0.6),
    TurboEnvironment.cityBridge => rgb(0.46, 0.66, 0.36),
    TurboEnvironment.sunsetCity => rgb(0.52, 0.5, 0.5),
  };
  bool get _isCity => race.environment != TurboEnvironment.suburbs && race.environment != TurboEnvironment.cityBridge;
  static final _lightDir = const V3(0.45, 0.85, 0.3).normalized;

  // Scenery (built once, like the iOS world builder)

  void _buildScenery() {
    final env = race.environment;
    final seed = track.length.round() + switch (env) {
      TurboEnvironment.suburbs => 11,
      TurboEnvironment.downtown => 23,
      TurboEnvironment.busyCity => 37,
      TurboEnvironment.cityBridge => 41,
      TurboEnvironment.sunsetCity => 53,
    };
    final g = SeededRandom(seed);
    final spacing = env == TurboEnvironment.suburbs ? 16.0 : 20.0;
    final roadPoints = track.samples(5);
    bool clear(V3 spot, double radius) {
      final limit = radius * radius;
      for (final p in roadPoints) {
        final dx = p.x - spot.x, dz = p.z - spot.z;
        if (dx * dx + dz * dz <= limit) return false;
      }
      return true;
    }

    for (var d = 10.0; d < track.length; d += spacing) {
      for (final side in const [-1.0, 1.0]) {
        final offset = TurboTrack.halfWidth + 7 + g.next() * 14;
        final base = track.centre(d) + track.right(d) * (side * offset);
        final spot = V3(base.x, 0, base.z);
        final roll = g.next();
        if (!clear(spot, TurboTrack.halfWidth + 6)) continue;
        // Face the road.
        final facing = track.right(d) * -side;
        final prop = _prop(roll, g, spot, facing);
        if (prop != null) _props.add(prop);
      }
      // Street lamps and traffic lights just outside the barrier in city races.
      if (env != TurboEnvironment.suburbs && d.toInt() % 60 < spacing.toInt()) {
        final side = (d / 60).floor().isEven ? 1.0 : -1.0;
        final spot = track.position(d, side * (TurboTrack.halfWidth + 3.4));
        _props.add(_Prop(env == TurboEnvironment.busyCity ? _PropKind.trafficLight : _PropKind.lamp, V3(spot.x, 0, spot.z),
            track.right(d) * -side));
      }
    }
    // Pillars under raised road.
    for (var d = 0.0; d < track.length; d += 14) {
      final c = track.centre(d);
      if (c.y > 1.5) {
        for (final side in const [-1.0, 1.0]) {
          final p = track.position(d, side * (TurboTrack.halfWidth - 1));
          _props.add(_Prop(_PropKind.pillar, V3(p.x, 0, p.z), track.forward(d), height: c.y));
        }
      }
    }
  }

  _Prop? _prop(double roll, SeededRandom g, V3 spot, V3 facing) {
    _Prop house() => _Prop(_PropKind.house, spot, facing,
        width: 7 + g.next() * 3,
        depth: 7 + g.next() * 2,
        height: 4.2,
        color: [rgb(1, 0.85, 0.7), rgb(0.75, 0.88, 1), rgb(1, 0.95, 0.75), rgb(0.85, 1, 0.85)][(g.next() * 4).floor() % 4]);
    _Prop tree() => _Prop(_PropKind.tree, spot, facing, height: 3 + g.next() * 2, color: rgb(0.2, 0.55 + g.next() * 0.15, 0.22));
    _Prop tower(double minH, double maxH) {
      final h = minH + g.next() * (maxH - minH);
      final w = 9 + g.next() * 7;
      return _Prop(_PropKind.tower, spot, facing,
          width: w,
          depth: w,
          height: h,
          seed: (g.next() * 3).floor(),
          color: [rgb(0.55, 0.6, 0.7), rgb(0.75, 0.7, 0.62), rgb(0.45, 0.5, 0.6), rgb(0.85, 0.82, 0.78)][(g.next() * 4).floor() % 4]);
    }

    switch (race.environment) {
      case TurboEnvironment.suburbs:
        return roll < 0.45 ? house() : roll < 0.9 ? tree() : _Prop(_PropKind.bush, spot, facing);
      case TurboEnvironment.downtown:
      case TurboEnvironment.sunsetCity:
        return roll < 0.8 ? tower(18, 55) : tree();
      case TurboEnvironment.busyCity:
        return roll < 0.7
            ? tower(10, 30)
            : roll < 0.85
                ? _Prop(_PropKind.parkedCar, spot, facing,
                    color: [rgb(1, 0.23, 0.19), rgb(0, 0.48, 1), rgb(1, 0.8, 0), rgb(0.2, 0.78, 0.35), rgb(1, 1, 1)][(g.next() * 5).floor() % 5])
                : tree();
      case TurboEnvironment.cityBridge:
        return roll < 0.5 ? tree() : roll < 0.8 ? house() : null;
    }
  }

  // Events from the ViewModel

  void showGate(int index, double progress, TurboChallenge challenge) => _gates[index] = _GateView(progress, challenge);

  /// Green for the right choice (it pops), red for a wrong one, then the gate fades away.
  void resolveGate(int index, int choice, int correctIndex) {
    final gate = _gates[index];
    if (gate == null) return;
    gate.choice = choice;
    gate.resolvedAge = 0;
    if (choice == correctIndex) hop();
  }

  void collectPickup(int index) => _collecting[index] = 0;

  void hop() => _hop = 0.4;

  /// Confetti over ChihChi's car.
  void celebrate() {
    hop();
    final car = simulation.player;
    final p = _screen(track.position(car.progress, car.lateral) + const V3(0, 2, 0));
    final origin = p ?? Offset(size.width / 2, size.height * 0.6);
    for (var i = 0; i < 140; i++) {
      final a = -math.pi / 2 + (_random.nextDouble() - 0.5) * 1.9;
      final speed = 300 + _random.nextDouble() * 500;
      _confetti.add(_Confetti(origin, Offset(math.cos(a), math.sin(a)) * speed,
          Draw.hsv(_random.nextDouble(), 0.75, 1)));
    }
  }

  // Frame

  @override
  void resize(Size newSize) => _updateFocal();

  void _updateFocal() {
    if (size.isEmpty) return;
    final portrait = size.height > size.width;
    final fov = (portrait ? 80.0 : 62.0) + _fovExtra;
    _focal = (portrait ? size.width / 2 : size.height / 2) / math.tan(fov / 2 * math.pi / 180);
  }

  @override
  void update(double dt) {
    onFrame?.call(dt);
    for (final g in _gates.values) {
      g.age += dt;
      if (g.resolved) g.resolvedAge += dt;
    }
    _gates.removeWhere((_, g) => g.resolved && g.resolvedAge > 1.6);
    for (final k in [..._collecting.keys]) {
      _collecting[k] = _collecting[k]! + dt;
    }
    _hop = math.max(0, _hop - dt);
    for (final c in [..._confetti]) {
      c.age += dt;
      c.velocity += Offset(0, 700 * dt);
      c.position += c.velocity * dt;
      if (c.age > 2.2) _confetti.remove(c);
    }
    if (introMode) {
      _introCamera(introProgress);
    } else {
      _followPlayer(dt);
    }
    repaint();
  }

  void _setCamera(V3 position, V3 target) {
    _camPos = position;
    _f = (target - position).normalized;
    _r = _f.cross(_up).normalized;
    _u = _r.cross(_f);
  }

  /// Trail along the road itself, so on tight bends the camera stays over the track.
  void _followPlayer(double dt) {
    final car = simulation.player;
    final position = track.position(car.progress, car.lateral);
    final forward = track.forward(car.progress);
    final speedShare = math.min(1.4, car.speed / math.max(simulation.topSpeed, 1));
    final behind = track.position(car.progress - (7 + speedShare * 2.2), car.lateral * 0.75);
    final target = behind + V3(0, 3.1 + speedShare * 0.4, 0);
    final blend = dt > 0 ? 1 - math.exp(-dt * 7) : 1.0;
    final next = _hasCamera ? _camPos + (target - _camPos) * blend : target;
    _hasCamera = true;
    _setCamera(next, position + forward * 9 + const V3(0, 1, 0));
    // A wider view while boosting feels faster (not with Reduce Motion).
    final wanted = !reduceMotion && car.boostTime > 0 ? 12.0 : 0.0;
    _fovExtra += (wanted - _fovExtra) * math.min(1, dt * 4);
    _updateFocal();
  }

  /// Before the countdown: the camera sweeps from in front of ChihChi's car round to behind it.
  void _introCamera(double t) {
    final car = simulation.player;
    final position = track.position(car.progress, car.lateral);
    final forward = track.forward(car.progress), right = track.right(car.progress);
    final eased = 0.5 - math.cos(math.min(1, t) * math.pi) / 2;
    final angle = eased * math.pi;
    final radius = 13 - eased * 5;
    final offset = forward * (math.cos(angle) * radius) + right * (math.sin(angle) * radius * 0.8);
    _setCamera(position + offset + V3(0, 4.2 - eased * 1.1, 0), position + const V3(0, 1, 0));
    _hasCamera = true;
    _updateFocal();
  }

  // Projection

  _C _cam(V3 p) {
    final v = p - _camPos;
    return _C(v.dot(_r), v.dot(_u), v.dot(_f));
  }

  Offset _proj(_C c) => Offset(size.width / 2 + c.x * _focal / c.z, size.height / 2 - c.y * _focal / c.z);

  Offset? _screen(V3 p) {
    final c = _cam(p);
    return c.z < _near ? null : _proj(c);
  }

  Color _fog(Color c, double depth) {
    final t = ((depth - _fogStart) / (_fogEnd - _fogStart)).clamp(0.0, 1.0);
    return t <= 0 ? c : Color.lerp(c, _horizon, t)!;
  }

  final _paint = Paint()..isAntiAlias = true;

  /// Fills a 3D polygon, clipped at the near plane and softened by fog.
  void _poly(Canvas canvas, List<V3> points, Color color, {double opacity = 1}) {
    final cam = [for (final p in points) _cam(p)];
    var clipped = cam;
    if (cam.any((c) => c.z < _near)) {
      clipped = [];
      for (var i = 0; i < cam.length; i++) {
        final a = cam[i], b = cam[(i + 1) % cam.length];
        final aIn = a.z >= _near, bIn = b.z >= _near;
        if (aIn) clipped.add(a);
        if (aIn != bIn) {
          final t = (_near - a.z) / (b.z - a.z);
          clipped.add(_C(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, _near));
        }
      }
      if (clipped.length < 3) return;
    }
    var depth = 0.0;
    final path = Path();
    for (var i = 0; i < clipped.length; i++) {
      final s = _proj(clipped[i]);
      depth += clipped[i].z;
      i == 0 ? path.moveTo(s.dx, s.dy) : path.lineTo(s.dx, s.dy);
    }
    path.close();
    _paint
      ..style = PaintingStyle.fill
      ..color = _fog(color, depth / clipped.length).withValues(alpha: color.a * opacity);
    canvas.drawPath(path, _paint);
  }

  Color _shade(Color c, V3 normal) {
    final light = 0.62 + 0.38 * math.max(0, normal.dot(_lightDir));
    return Draw.adjusted(c, light);
  }

  /// A box standing on `base`, facing `forward`. Only faces turned to the camera are drawn.
  void _box(Canvas canvas, V3 base, V3 forward, double width, double height, double length, Color color,
      {Color? top, double lift = 0, double opacity = 1, void Function(List<V3> face, V3 normal)? onFace}) {
    final f = forward, r = V3(-f.z, 0, f.x);
    final hw = width / 2, hl = length / 2;
    V3 corner(double x, double y, double z) => base + r * x + _up * (y + lift) + f * z;
    final faces = <(List<V3>, V3, bool)>[
      ([corner(-hw, height, -hl), corner(hw, height, -hl), corner(hw, height, hl), corner(-hw, height, hl)], _up, true),
      ([corner(-hw, 0, hl), corner(hw, 0, hl), corner(hw, height, hl), corner(-hw, height, hl)], f, false),
      ([corner(hw, 0, -hl), corner(-hw, 0, -hl), corner(-hw, height, -hl), corner(hw, height, -hl)], f * -1, false),
      ([corner(hw, 0, hl), corner(hw, 0, -hl), corner(hw, height, -hl), corner(hw, height, hl)], r, false),
      ([corner(-hw, 0, -hl), corner(-hw, 0, hl), corner(-hw, height, hl), corner(-hw, height, -hl)], r * -1, false),
    ];
    for (final (pts, normal, isTop) in faces) {
      final centre = (pts[0] + pts[2]) * 0.5;
      if (normal.dot(_camPos - centre) <= 0) continue;
      _poly(canvas, pts, _shade(isTop ? (top ?? color) : color, normal), opacity: opacity);
      onFace?.call(pts, normal);
    }
  }

  // Render

  @override
  void render(Canvas canvas) {
    if (size.isEmpty) return;
    _drawSky(canvas);
    _drawRoad(canvas);
    _drawPads(canvas);

    final items = <(double, void Function())>[];
    void add(V3 at, void Function() draw) {
      final c = _cam(at);
      if (c.z > -12 && c.z < _fogEnd + 40) items.add((c.z, draw));
    }

    for (final p in _props) {
      add(p.position, () => _drawProp(canvas, p));
    }
    add(track.centre(0), () => _drawGantry(canvas));
    final player = simulation.player;
    for (var i = 0; i < simulation.pickups.length; i++) {
      final p = simulation.pickups[i];
      final collecting = _collecting[i];
      if (p.isCollected && (collecting == null || collecting > 0.2)) continue;
      if (!(p.progress > player.progress - 5 && p.progress < player.progress + track.length * 0.9)) continue;
      final at = track.position(p.progress, p.lateral) + const V3(0, 1.4, 0);
      add(at, () => _drawStar(canvas, at, collecting));
    }
    for (final g in _gates.values) {
      add(track.centre(g.progress), () => _drawGate(canvas, g));
    }
    for (var i = simulation.cars.length - 1; i >= 0; i--) {
      final car = simulation.cars[i];
      add(track.position(car.progress, car.lateral), () => _drawCar(canvas, i, car));
    }
    items.sort((a, b) => b.$1.compareTo(a.$1));
    for (final item in items) {
      item.$2();
    }
    for (final c in _confetti) {
      canvas.drawRect(Rect.fromCenter(center: c.position, width: 8, height: 5),
          Draw.fill(c.color.withValues(alpha: (1 - c.age / 2.2).clamp(0, 1))));
    }
  }

  double get _horizonY {
    final h = V3(_f.x, 0, _f.z).normalized;
    final c = _cam(_camPos + h * 2000);
    return c.z <= 0 ? -1000 : _proj(c).dy;
  }

  double get _heading => math.atan2(_f.x, -_f.z);

  void _drawSky(Canvas canvas) {
    final horizon = _horizonY.clamp(-200.0, size.height + 200);
    final skyRect = Rect.fromLTWH(0, 0, size.width, math.max(1, horizon));
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = Gradient.linear(skyRect.topCenter, Offset(0, horizon), [_sky.$1, _horizon], [0, 1]),
    );
    if (race.sky == TurboSky.sunset || race.sky == TurboSky.sunny) {
      // A sun low over the hills, turning with the camera.
      final x = size.width / 2 + ((-_heading + 0.9) % (2 * math.pi) - math.pi) * _focal;
      final sunY = horizon - (race.sky == TurboSky.sunset ? 40 : 160);
      canvas.drawCircle(Offset(x, sunY), 60, Draw.fill(const Color(0x33FFF3B0)));
      canvas.drawCircle(Offset(x, sunY), 34, Draw.fill(race.sky == TurboSky.sunset ? rgb(1, 0.75, 0.4) : rgb(1, 0.96, 0.7)));
    }
    // Clouds drifting by.
    final cloud = Draw.fill(Color.fromRGBO(255, 255, 255, race.sky == TurboSky.cloudy ? 0.75 : 0.55));
    for (var i = 0; i < 6; i++) {
      final angle = i * 1.05 + time * 0.004;
      final x = size.width / 2 + ((angle - _heading) % (2 * math.pi) - math.pi) * _focal * 0.9;
      final y = horizon - 120 - (i % 3) * 45;
      for (final (dx, dy, r) in const [(0.0, 0.0, 22.0), (24.0, -8.0, 28.0), (52.0, 0.0, 20.0)]) {
        canvas.drawCircle(Offset(x + dx, y + dy), r, cloud);
      }
    }
    // Hills or a far skyline, turning with the camera.
    final far = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width + 8; x += 8) {
      final a = _heading + (x - size.width / 2) / _focal;
      final h = _isCity
          ? 22 + 30 * ((math.sin(a * 23).abs() * 3).floor() / 3) + 14 * (math.sin(a * 61) > 0.3 ? 1 : 0)
          : 26 + 18 * math.sin(a * 3) + 10 * math.sin(a * 7 + 1);
      far.lineTo(x, horizon - h);
    }
    far
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(far, Draw.fill(Color.lerp(_isCity ? rgb(0.5, 0.55, 0.65) : rgb(0.35, 0.58, 0.3), _horizon, 0.55)!));
    // Ground.
    canvas.drawRect(Rect.fromLTRB(0, horizon, size.width, size.height),
        Paint()..shader = Gradient.linear(Offset(0, horizon), Offset(0, size.height), [Color.lerp(_ground, _horizon, 0.6)!, _ground], [0, 0.35]));
  }

  void _drawRoad(Canvas canvas) {
    const step = 4.0;
    final count = (track.length / step).floor();
    final segments = <(double, double)>[];
    for (var i = 0; i < count; i++) {
      final d = i * step;
      final c = _cam(track.centre(d + step / 2));
      if (c.z < -12 || c.z > _fogEnd) continue;
      // Behind the camera's sides? Keep only what can be on screen.
      if (c.z > 0 && c.x.abs() > c.z * size.width / _focal + 30) continue;
      segments.add((c.z, d));
    }
    segments.sort((a, b) => b.$1.compareTo(a.$1));
    const hw = TurboTrack.halfWidth;
    final asphalt = rgb(0.36, 0.37, 0.4);
    for (final (_, d) in segments) {
      final d1 = d + step + 0.05;
      V3 p(double dist, double lat, [double h = 0]) => track.position(dist, lat) + V3(0, h + 0.02, 0);
      final i = (d / step).round();
      // Verge, kerbs, road, lane dashes, barriers.
      _poly(canvas, [p(d, -hw - 3), p(d, -hw - 1.2), p(d1, -hw - 1.2), p(d1, -hw - 3)], Draw.adjusted(_ground, 0.92));
      _poly(canvas, [p(d, hw + 1.2), p(d, hw + 3), p(d1, hw + 3), p(d1, hw + 1.2)], Draw.adjusted(_ground, 0.92));
      final kerb = i.isEven ? rgb(0.92, 0.2, 0.2) : rgb(0.97, 0.97, 0.97);
      _poly(canvas, [p(d, -hw - 1.2), p(d, -hw), p(d1, -hw), p(d1, -hw - 1.2)], kerb);
      _poly(canvas, [p(d, hw), p(d, hw + 1.2), p(d1, hw + 1.2), p(d1, hw)], kerb);
      _poly(canvas, [p(d, -hw), p(d, hw), p(d1, hw), p(d1, -hw)], i % 4 < 2 ? asphalt : Draw.adjusted(asphalt, 1.04));
      if (i % 3 == 0) {
        for (final lane in const [-2.3, 2.3]) {
          _poly(canvas, [p(d, lane - 0.12), p(d, lane + 0.12), p(d + step * 0.6, lane + 0.12), p(d + step * 0.6, lane - 0.12)],
              const Color(0xEEFFFFFF));
        }
      }
      // The start/finish line: a checker strip.
      final w = track.wrap(d);
      if (w < step) {
        for (var row = 0; row < 2; row++) {
          for (var col = 0; col < 14; col++) {
            final lat = -hw + col * 1.0;
            final dd = row * 1.0;
            _poly(canvas, [p(dd, lat, 0.01), p(dd, lat + 1, 0.01), p(dd + 1, lat + 1, 0.01), p(dd + 1, lat, 0.01)],
                (row + col).isEven ? const Color(0xFFFFFFFF) : const Color(0xFF222222));
          }
        }
      }
      final barrier = i.isEven ? rgb(0.95, 0.95, 0.97) : rgb(0.25, 0.45, 0.85);
      for (final side in const [-1.0, 1.0]) {
        final lat = side * (hw + 2.6);
        _poly(canvas, [p(d, lat), p(d1, lat), p(d1, lat, 0.9), p(d, lat, 0.9)], barrier);
      }
    }
  }

  void _drawPads(Canvas canvas) {
    for (final pad in simulation.boostPads) {
      final c = _cam(track.centre(pad.distance));
      if (c.z < -6 || c.z > _fogEnd) continue;
      V3 p(double along, double lat) => track.position(pad.distance + along, pad.lateral + lat) + const V3(0, 0.05, 0);
      _poly(canvas, [p(-2.5, -1.8), p(-2.5, 1.8), p(2.5, 1.8), p(2.5, -1.8)], rgb(0.05, 0.6, 0.95));
      final pulse = 0.6 + 0.4 * math.sin(time * 8);
      for (var row = 0; row < 2; row++) {
        final a = -1.6 + row * 2.2;
        _poly(canvas, [p(a, -1.4), p(a + 1.2, 0), p(a + 1.6, 0), p(a + 0.4, -1.4)], Color.fromRGBO(190, 255, 255, pulse));
        _poly(canvas, [p(a, 1.4), p(a + 1.2, 0), p(a + 1.6, 0), p(a + 0.4, 1.4)], Color.fromRGBO(190, 255, 255, pulse));
      }
    }
  }

  // Scenery

  void _drawProp(Canvas canvas, _Prop prop) {
    final f = prop.forward;
    switch (prop.kind) {
      case _PropKind.house:
        _box(canvas, prop.position, f, prop.width, prop.height, prop.depth, prop.color, onFace: (face, normal) {
          if ((normal - f).length < 0.01) {
            // A door and two windows on the side facing the road.
            final a = face[0], b = face[1];
            V3 at(double u, double v) => V3.lerp(a, b, u) + _up * v + f * 0.05;
            _poly(canvas, [at(0.44, 0), at(0.56, 0), at(0.56, 2), at(0.44, 2)], rgb(0.45, 0.3, 0.2));
            for (final u in const [0.15, 0.7]) {
              _poly(canvas, [at(u, 1.4), at(u + 0.15, 1.4), at(u + 0.15, 2.8), at(u, 2.8)], rgb(0.6, 0.82, 1));
            }
          }
        });
        // Pyramid roof.
        final r = V3(-f.z, 0, f.x);
        final hw = prop.width / 2 + 0.4, hl = prop.depth / 2 + 0.4;
        V3 c(double x, double z) => prop.position + r * x + _up * prop.height + f * z;
        final apex = prop.position + _up * (prop.height + 2.6);
        final roof = rgb(0.8, 0.3, 0.25);
        final sides = [
          (c(-hw, hl), c(hw, hl), f),
          (c(hw, -hl), c(-hw, -hl), f * -1),
          (c(hw, hl), c(hw, -hl), r),
          (c(-hw, -hl), c(-hw, hl), r * -1),
        ];
        for (final (a, b, n) in sides) {
          final normal = (n * 2.6 + _up * hw).normalized;
          if (normal.dot(_camPos - (a + b + apex) * (1 / 3)) <= 0) continue;
          _poly(canvas, [a, b, apex], _shade(roof, normal));
        }
      case _PropKind.tree:
        _box(canvas, prop.position, f, 0.6, prop.height, 0.6, rgb(0.45, 0.3, 0.18));
        for (var i = 0; i < 3; i++) {
          final radius = const [2.4, 1.9, 1.4][i];
          final at = prop.position + _up * (prop.height + i * 1.3) + V3(-f.z, 0, f.x) * (i * 0.4 - 0.4);
          _sphere(canvas, at, radius, prop.color);
        }
      case _PropKind.bush:
        _sphere(canvas, prop.position + _up * 0.6, 1.2, rgb(0.25, 0.6, 0.3), squashY: 0.7);
      case _PropKind.tower:
        final lit = race.sky == TurboSky.sunset;
        _box(canvas, prop.position, f, prop.width, prop.height, prop.depth, prop.color, onFace: (face, normal) {
          if (normal.y > 0.5) return;
          // Rows of windows; at sunset some are lit.
          final a = face[0], b = face[1];
          final rows = (prop.height / 3.2).floor();
          final cols = math.max(2, (prop.width / 3).floor());
          final c0 = _cam((a + b) * 0.5);
          if (c0.z > 180) return;
          for (var row = 1; row < rows; row++) {
            for (var col = 0; col < cols; col++) {
              final u0 = (col + 0.25) / cols, u1 = (col + 0.75) / cols;
              final v0 = row * 3.2 - 1.9, v1 = row * 3.2 - 0.5;
              final on = lit && ((row * 7 + col * 3 + prop.seed) % 5 == 0);
              V3 at(double u, double v) => V3.lerp(a, b, u) + _up * v + normal * 0.05;
              _poly(canvas, [at(u0, v0), at(u1, v0), at(u1, v1), at(u0, v1)],
                  on ? rgb(1, 0.85, 0.5) : Draw.adjusted(prop.color, 0.7, 0.8).withValues(alpha: 1));
            }
          }
        });
      case _PropKind.parkedCar:
        _box(canvas, prop.position, V3(-f.z, 0, f.x), 1.8, 0.8, 3.8, prop.color, lift: 0.2);
        _box(canvas, prop.position + V3(-f.z, 0, f.x) * 0.2, V3(-f.z, 0, f.x), 1.5, 0.6, 2, rgb(0.15, 0.15, 0.15), lift: 1.0);
      case _PropKind.lamp:
        _box(canvas, prop.position, f, 0.24, 6, 0.24, rgb(0.3, 0.3, 0.3));
        final bulb = prop.position + _up * 5.8 + f * 1.6;
        _box(canvas, prop.position + f * 0.8, f, 0.15, 0.15, 1.8, rgb(0.3, 0.3, 0.3), lift: 5.9);
        _sphere(canvas, bulb, 0.3, race.sky == TurboSky.sunset ? rgb(1, 0.88, 0.6) : rgb(0.9, 0.9, 0.9), glow: race.sky == TurboSky.sunset);
      case _PropKind.trafficLight:
        _box(canvas, prop.position, f, 0.24, 4.5, 0.24, rgb(0.25, 0.25, 0.25));
        _box(canvas, prop.position, f, 0.6, 1.6, 0.5, rgb(0.12, 0.12, 0.12), lift: 4.1);
        final lights = [rgb(1, 0.23, 0.19), rgb(1, 0.8, 0), rgb(0.2, 0.78, 0.35)];
        for (var i = 0; i < 3; i++) {
          _sphere(canvas, prop.position + _up * (5.4 - i * 0.5) + f * 0.27, 0.18, lights[i], glow: true);
        }
      case _PropKind.pillar:
        _box(canvas, prop.position, prop.forward, 1.2, prop.height, 1.2, rgb(0.75, 0.75, 0.78));
    }
  }

  void _sphere(Canvas canvas, V3 centre, double radius, Color color, {double squashY = 1, bool glow = false}) {
    final c = _cam(centre);
    if (c.z < _near + radius * 0.5) return;
    final s = _proj(c);
    final r = radius * _focal / c.z;
    if (r < 0.4) return;
    final col = _fog(color, c.z);
    final rect = Rect.fromCenter(center: s, width: r * 2, height: r * 2 * squashY);
    if (glow) canvas.drawOval(rect.inflate(r * 0.8), Draw.fill(col.withValues(alpha: 0.3)));
    canvas.drawOval(rect, Draw.fill(Draw.adjusted(col, glow ? 1 : 0.85)));
    canvas.drawOval(
        Rect.fromCenter(center: s + Offset(-r * 0.18, -r * 0.22 * squashY), width: r * 1.4, height: r * 1.3 * squashY),
        Draw.fill(Draw.adjusted(col, glow ? 1.1 : 1.08)));
  }

  void _drawGantry(Canvas canvas) {
    const span = TurboTrack.halfWidth + 2.4;
    final f = track.forward(0), r = track.right(0);
    final base = track.centre(0);
    final pillar = rgb(0.95, 0.3, 0.25);
    _box(canvas, base + r * -span, f, 0.7, 6.5, 0.7, pillar);
    _box(canvas, base + r * span, f, 0.7, 6.5, 0.7, pillar);
    _box(canvas, base, f, span * 2 + 0.7, 1.4, 0.4, rgb(0.12, 0.2, 0.45), lift: 5.5, onFace: (face, normal) {
      if (normal.y.abs() > 0.5 || (normal.dot(f)).abs() < 0.5) return;
      final c = _cam((face[0] + face[2]) * 0.5);
      if (c.z < _near) return;
      final s = _proj(c);
      final h = 1.4 * _focal / c.z;
      Draw.text(canvas, '🐼 CHIHCHI TURBO RACE 🏁', s, h * 0.5);
    });
  }

  void _drawStar(Canvas canvas, V3 at, double? collecting) {
    final c = _cam(at);
    if (c.z < _near) return;
    final s = _proj(c);
    var size = 1.5 * _focal / c.z;
    var opacity = 1.0;
    if (collecting != null) {
      size *= 1 + collecting / 0.2;
      opacity = (1 - collecting / 0.2).clamp(0, 1);
    }
    final spin = reduceMotion ? 1.0 : math.cos(time * math.pi).abs() * 0.85 + 0.15;
    canvas.save();
    canvas.translate(s.dx, s.dy);
    canvas.scale(spin, 1);
    Draw.text(canvas, '⭐', Offset.zero, size, opacity: opacity);
    canvas.restore();
  }

  void _drawGate(Canvas canvas, _GateView gate) {
    final f = track.forward(gate.progress), r = track.right(gate.progress);
    final base = track.centre(gate.progress);
    final grow = reduceMotion ? 1.0 : easeOut(math.min(1, gate.age / 0.35));
    final fade = gate.resolved ? (1 - ((gate.resolvedAge - 1.2) / 0.4).clamp(0.0, 1.0)) : 1.0;
    if (fade <= 0) return;
    final offsets = TurboRaceSimulation.optionOffsets(gate.challenge.options.length);
    final pole = rgb(0.95, 0.95, 0.95);
    // Far arch first.
    final order = [for (var i = 0; i < offsets.length; i++) i]
      ..sort((a, b) => _cam(base + r * offsets[b]).z.compareTo(_cam(base + r * offsets[a]).z));
    for (final i in order) {
      final at = base + r * offsets[i];
      final h = grow;
      for (final x in const [-1.9, 1.9]) {
        _box(canvas, at + r * x, f, 0.28, 4.6 * h, 0.28, pole, opacity: fade);
      }
      // Curtain: green for the right choice, red for the wrong one picked.
      var curtain = const Color(0x29FFFFFF);
      if (gate.resolved) {
        if (i == gate.challenge.correctIndex) {
          curtain = const Color(0x7334C759);
        } else if (i == gate.choice) {
          curtain = const Color(0x66FF3B30);
        }
      }
      // Fades as the camera drives through it, so it never fills the screen.
      final near = ((_cam(at).z - 3) / 8).clamp(0.0, 1.0);
      if (near > 0) {
        _poly(canvas, [at + r * -1.8, at + r * 1.8, at + r * 1.8 + _up * 3.8 * h, at + r * -1.8 + _up * 3.8 * h], curtain,
            opacity: fade * near);
      }
      final pop = gate.resolved && i == gate.challenge.correctIndex && gate.resolvedAge < 0.35
          ? 1 + 0.25 * math.sin(gate.resolvedAge / 0.35 * math.pi)
          : 1.0;
      _panel(canvas, at, f, gate.challenge.options[i].face, h * pop, fade);
    }
  }

  void _panel(Canvas canvas, V3 at, V3 f, TurboGateFace face, double scale, double opacity) {
    final background = switch (face) {
      GateText() => rgb(0.15, 0.35, 0.85),
      GateColor(:final color) => color.color,
      GateShape() => rgb(0.2, 0.2, 0.35),
    };
    final w = 3.6 * scale, h = 2.3 * scale;
    _box(canvas, at, f, w, h, 0.18, background, top: rgb(0.95, 0.95, 0.95), lift: 4.9 * scale - h / 2, opacity: opacity,
        onFace: (pts, normal) {
      if ((normal.dot(f)).abs() < 0.5) return;
      final c = _cam((pts[0] + pts[2]) * 0.5);
      if (c.z < _near) return;
      final s = _proj(c);
      final px = h * _focal / c.z;
      _poly(canvas, pts, background, opacity: opacity);
      switch (face) {
        case GateText(:final text):
          Draw.text(canvas, text, s, px * 0.72, opacity: opacity);
        case GateColor():
          break;
        case GateShape(:final shape):
          _shapePath(canvas, shape, Rect.fromCenter(center: s, width: px * 0.7, height: px * 0.7),
              Draw.fill(rgb(1, 0.85, 0.2).withValues(alpha: opacity)));
      }
    });
  }

  static void _shapePath(Canvas canvas, CatchLetterShape shape, Rect rect, Paint paint) {
    switch (shape) {
      case CatchLetterShape.circle:
        canvas.drawOval(rect, paint);
      case CatchLetterShape.square:
        canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(rect.width * 0.05), Radius.circular(rect.width * 0.08)), paint);
      case CatchLetterShape.triangle:
        canvas.drawPath(
            Path()
              ..moveTo(rect.center.dx, rect.top)
              ..lineTo(rect.right, rect.bottom)
              ..lineTo(rect.left, rect.bottom)
              ..close(),
            paint);
      case CatchLetterShape.star:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final radius = i.isEven ? rect.width / 2 : rect.width / 4.6;
          final a = i * math.pi / 5 - math.pi / 2;
          final p = rect.center + Offset(math.cos(a) * radius, math.sin(a) * radius);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path..close(), paint);
    }
  }

  // Cars

  void _drawCar(Canvas canvas, int index, TurboCar car) {
    final d = car.progress;
    final racer = TurboRacer.forCar(index);
    var base = track.position(d, car.lateral);
    if (index == 0 && _hop > 0) base = base + _up * (0.8 * math.sin((1 - _hop / 0.4) * math.pi));
    // Turn slightly into a slide when changing lanes.
    final drift = math.atan(car.lateralVelocity / math.max(car.speed, 4));
    final tf = track.forward(d), tr = track.right(d);
    final f = (tf * math.cos(drift) + tr * math.sin(drift)).normalized;
    final r = V3(-f.z, 0, f.x);
    // A rival right behind ChihChi sits between the camera and the player's car: fade it.
    final gap = simulation.player.progress - car.progress;
    final opacity = index > 0 && gap > 0 && gap < 10 ? 0.3 : 1.0;
    final paint = racer.paint;
    final trim = rgb(0.15, 0.15, 0.18);
    // Cars face -f in the iOS model (bonnet ahead); here +f is forward.
    V3 at(double x, double z) => base + r * x + f * z;
    // Wheels, body, bonnet, rear deck, cabin, spoiler.
    for (final x in const [-0.95, 0.95]) {
      for (final z in const [-1.35, 1.35]) {
        _box(canvas, at(x, z), f, 0.4, 0.7, 0.7, trim, opacity: opacity);
      }
    }
    _box(canvas, at(0, 0), f, 2.0, 0.5, 4.3, paint, lift: 0.37, opacity: opacity);
    _box(canvas, at(0, 1.2), f, 1.7, 0.34, 1.5, paint, lift: 0.81, opacity: opacity);
    _box(canvas, at(0, -1.45), f, 1.8, 0.4, 1.2, paint, lift: 0.8, opacity: opacity);
    _box(canvas, at(0, 0.1), f, 1.6, 0.6, 1.6, rgb(0.55, 0.8, 0.95), top: Draw.adjusted(paint, 0.9), lift: 0.87, opacity: opacity);
    _box(canvas, at(0, -1.95), f, 2.1, 0.08, 0.5, paint, lift: 1.5, opacity: opacity);
    for (final x in const [-0.7, 0.7]) {
      _box(canvas, at(x, -1.95), f, 0.08, 0.35, 0.2, trim, lift: 1.15, opacity: opacity);
    }
    // Boost flames out of the back.
    if (car.boostTime > 0) {
      final flame = _cam(at(0, -2.4) + _up * 0.6);
      if (flame.z > _near) {
        final s = _proj(flame);
        final rr = 0.55 * _focal / flame.z * (0.8 + 0.3 * math.sin(time * 40));
        canvas.drawCircle(s, rr * 1.5, Draw.fill(const Color(0x66FF9500)));
        canvas.drawCircle(s, rr, Draw.fill(const Color(0xFFFFD60A)));
      }
    }
    // The driver, and rivals' name tags.
    final head = _cam(at(0, 0.1) + _up * 1.95);
    if (head.z > _near) {
      final s = _proj(head);
      final px = _focal / head.z;
      final face = index == 0 ? playerFace : null;
      if (face != null) {
        final rect = Rect.fromCircle(center: s, radius: 0.55 * px);
        canvas.drawCircle(s, 0.6 * px, Draw.fill(const Color(0xFFFFFFFF)));
        canvas.save();
        canvas.clipPath(Path()..addOval(rect));
        canvas.drawImageRect(face, Rect.fromLTWH(0, 0, face.width.toDouble(), face.height.toDouble()), rect,
            Paint()..filterQuality = FilterQuality.medium);
        canvas.restore();
      } else {
        Draw.text(canvas, racer.face, s, 1.1 * px, opacity: opacity);
      }
      if (index > 0 && head.z < 90) {
        final tag = '${racer.face} ${racer.name(language)}';
        final fs = math.max(9.0, 0.5 * px);
        final m = Draw.measure(tag, fs);
        final rect = Rect.fromCenter(center: s + Offset(0, -0.95 * px), width: m.width + fs, height: fs * 1.5);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(fs)), Draw.fill(paint.withValues(alpha: 0.85 * opacity)));
        Draw.text(canvas, tag, rect.center, fs, opacity: opacity);
      }
    }
  }

  // Mini-map

  /// The track squeezed into a unit square, and each car's dot.
  late final (List<Offset>, double, double, double) miniMap = () {
    final points = track.samples(8);
    var minX = points.first.x, minZ = points.first.z, maxX = minX, maxZ = minZ;
    for (final p in points) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minZ = math.min(minZ, p.z);
      maxZ = math.max(maxZ, p.z);
    }
    final size = math.max(maxX - minX, maxZ - minZ);
    return ([for (final p in points) Offset((p.x - minX) / size, (p.z - minZ) / size)], minX, minZ, size);
  }();

  List<Offset> get miniMapCars {
    final (_, minX, minZ, s) = miniMap;
    return [
      for (final car in simulation.cars)
        () {
          final p = track.centre(car.progress);
          return Offset((p.x - minX) / s, (p.z - minZ) / s);
        }(),
    ];
  }
}
