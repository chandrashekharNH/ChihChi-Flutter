import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show HSVColor;

import '../../domain/models/game_engagement.dart';
import '../engine/draw.dart';
import '../engine/game_scene.dart';

/// What a floating balloon shows.
class LearnBlasterTargetFace {
  const LearnBlasterTargetFace({required this.id, this.title, this.emoji});
  final String id;
  final String? title;
  final String? emoji;
}

/// What a shot runs into first.
sealed class LearnBlasterHit {
  const LearnBlasterHit();
}

class HitTarget extends LearnBlasterHit {
  const HitTarget(this.id);
  final String id;
}

class HitToy extends LearnBlasterHit {
  const HitToy(this.id);
  final String id;
}

class HitNothing extends LearnBlasterHit {
  const HitNothing();
}

/// Result of a shot: what it hit and where on screen it lands.
class LearnBlasterShot {
  const LearnBlasterShot(this.hit, this.point);
  final LearnBlasterHit hit;
  final Offset point;
  String? get targetID => hit is HitTarget ? (hit as HitTarget).id : null;
}

/// A point in the playroom: x right, y up, z towards the camera (metres).
class _V3 {
  const _V3(this.x, this.y, this.z);
  final double x, y, z;
}

class _Balloon {
  _Balloon(this.face, this.color, this.lane, this.phase, this.bobPeriod, this.delay);
  final LearnBlasterTargetFace face;
  final Color color;
  final (double, double, double) lane; // y, z, speed
  final double phase, bobPeriod, delay;
  double age = 0;
  double scale = 0.01;
  double opacity = 1;
  double wobbleX = 0;
  double squish = 1;
  bool highlighted = false;
  bool popping = false;
  bool leaving = false;
  double frozenX = 0;
  bool frozen = false;
}

class _Confetti {
  _Confetti(this.position, this.velocity, this.color, this.size, this.spin);
  Offset position, velocity;
  final Color color;
  final double size, spin;
  double age = 0;
}

class _Projectile {
  _Projectile(this.from, this.to);
  final Offset from, to;
  double age = 0;
}

/// Learn Blaster's playroom, drawn in 2D with perspective: walls, floor, toys that drive and bounce,
/// balloons on lanes at different depths, and a blaster the child holds and aims. Only visuals and
/// hit-testing live here; the rules are in LearnBlasterViewModel.
class LearnBlasterScene extends GameScene {
  void Function()? onFire;

  /// Shows the "hold the gun" pulse on the first round.
  bool showsTip = false;

  static const _camera = _V3(0, 1.7, 4);
  static const _roomHalfWidth = 5.0, _roomHeight = 5.0, _backZ = -5.0;
  static const _balloonWidth = 1.0, _balloonHeight = 1.25;
  static const _maxTravel = 3.6;

  /// One lane per balloon so they never overlap.
  static const _lanes = [(2.45, -2.2, 1.0), (1.15, -1.7, 1.15), (1.8, -2.9, 0.9), (0.7, -2.5, 1.25), (2.9, -3.3, 1.05)];
  static const balloonColors = [
    Color.fromRGBO(255, 107, 158, 1),
    Color.fromRGBO(255, 153, 51, 1),
    Color.fromRGBO(46, 184, 191, 1),
    Color.fromRGBO(153, 107, 242, 1),
    Color.fromRGBO(84, 191, 89, 1),
    Color.fromRGBO(64, 140, 255, 1),
  ];

  final _random = math.Random();
  final Map<String, _Balloon> _balloons = {};
  final List<_Balloon> _gone = [];
  final List<_Confetti> _confetti = [];
  final List<_Projectile> _shots = [];
  double _focal = 400;
  double _fovTangent = math.tan(40 * math.pi / 180);
  double _aspect = 0.46;

  Offset aimPoint = Offset.zero;
  bool _aimOnTarget = false;
  double _aimGlow = 0;
  double _recoil = 0;

  // Toy reactions (seconds left, kind of move)
  final Map<String, double> _toyReact = {};

  // Touch on the blaster
  bool _holding = false;
  Offset _touchStart = Offset.zero;
  double _touchStartTime = 0;
  bool _dragging = false;
  static const _sensitivity = 1.4, _tapSlop = 12.0, _tapDuration = 0.4, _grabRadius = 85.0;

  // Projection

  @override
  void resize(Size newSize) {
    final first = aimPoint == Offset.zero;
    _aspect = newSize.width / newSize.height;
    final fov = _aspect >= 1 ? 55.0 : 80.0;
    _fovTangent = math.tan(fov / 2 * math.pi / 180);
    _focal = newSize.height / 2 / _fovTangent;
    aimPoint = first ? Offset(newSize.width / 2, newSize.height * 0.45) : _clampAim(aimPoint);
  }

  double _depth(double z) => math.max(0.05, _camera.z - z);

  Offset _project(_V3 p) {
    final d = _depth(p.z);
    return Offset(size.width / 2 + p.x * _focal / d, size.height / 2 - (p.y - _camera.y) * _focal / d);
  }

  double _pixels(double metres, double z) => metres * _focal / _depth(z);

  Path _poly(List<_V3> points) {
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = _project(points[i]);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  double _travelRange(double z) {
    final halfWidth = _depth(z) * _fovTangent * _aspect;
    return math.max(0.4, math.min(_maxTravel, halfWidth - 0.65));
  }

  // Aiming

  Offset _clampAim(Offset p) => Offset(p.dx.clamp(0, size.width), p.dy.clamp(0, size.height));

  void aim(Offset point) => aimPoint = _clampAim(point);

  /// Where the blaster sits on screen (its grip), so the child can grab it.
  Offset get blasterPoint {
    final norm = size.width <= 0 ? 0.0 : aimPoint.dx / size.width * 2 - 1;
    final span = math.min(size.width * 0.3, 0.45 / (0.9 * _fovTangent * _aspect) * size.width / 2);
    return Offset(size.width / 2 + norm * span, size.height * 0.85);
  }

  double get _blasterAngle {
    final v = aimPoint - blasterPoint;
    return math.atan2(v.dx, -v.dy).clamp(-1.2, 1.2);
  }

  Offset get _muzzle {
    final a = _blasterAngle;
    final length = size.height * 0.09 - _recoil;
    return blasterPoint + Offset(math.sin(a) * length, -math.cos(a) * length);
  }

  @override
  void dragStart(Offset position) {
    _holding = (position - blasterPoint).distance <= _grabRadius;
    if (!_holding) return;
    _touchStart = position;
    _touchStartTime = time;
    _dragging = false;
  }

  @override
  void dragUpdate(Offset position, Offset delta) {
    if (!_holding) return;
    if (!_dragging && (position - _touchStart).distance > _tapSlop) _dragging = true;
    if (_dragging) aim(aimPoint + delta * _sensitivity);
  }

  @override
  void dragEnd() {
    // Short taps fire. Real seconds would be better, but scene time only differs in slow motion.
    if (_holding && !_dragging && (time - _touchStartTime) / math.max(timeScale, 0.1) < _tapDuration) onFire?.call();
    _holding = false;
  }

  // Targets

  void showTargets(List<LearnBlasterTargetFace> faces, double crossingDuration) {
    clearTargets();
    final colorOffset = _random.nextInt(balloonColors.length);
    for (var i = 0; i < faces.length; i++) {
      final lane = _lanes[i % _lanes.length];
      final crossing = crossingDuration * lane.$3;
      _balloons[faces[i].id] = _Balloon(
        faces[i],
        balloonColors[(i + colorOffset) % balloonColors.length],
        (lane.$1, lane.$2, crossing),
        _random.nextDouble() * 2,
        1 + _random.nextDouble() * 0.5,
        i * 0.12,
      );
    }
  }

  void clearTargets() {
    for (final b in _balloons.values) {
      b.leaving = true;
      _gone.add(b);
    }
    _balloons.clear();
  }

  void popTarget(String id) {
    final b = _balloons.remove(id);
    if (b == null) return;
    b.popping = true;
    b.age = 0;
    b.frozenX = _balloonX(b);
    b.frozen = true;
    _gone.add(b);
    _burst(_balloonCenter(b));
  }

  void wobbleTarget(String id) {
    final b = _balloons[id];
    if (b == null) return;
    timeline.tween(0.3, (t) {
      b.wobbleX = 0.14 * math.sin(t * 4 * math.pi) * (1 - t);
      b.squish = 1 - 0.15 * math.sin(t * math.pi);
    }, curve: (x) => x, onDone: () {
      b.wobbleX = 0;
      b.squish = 1;
    });
  }

  /// Pulses the correct balloon so a struggling child can find it.
  void highlightTarget(String id) => _balloons[id]?.highlighted = true;

  void setSlowMotion(bool on) => timeScale = on ? PlayBoost.slowMotionFactor : 1;

  double _balloonX(_Balloon b) {
    if (b.frozen) return b.frozenX;
    final range = _travelRange(b.lane.$2);
    // Smooth left ↔ right, eased at the ends.
    return -range * math.cos(math.pi * (b.age / b.lane.$3 + b.phase)) + b.wobbleX;
  }

  _V3 _balloonPosition(_Balloon b) {
    final bob = 0.07 * (1 - math.cos(2 * math.pi * b.age / (2 * b.bobPeriod)));
    return _V3(_balloonX(b), b.lane.$1 + bob, b.lane.$2);
  }

  Offset _balloonCenter(_Balloon b) => _project(_balloonPosition(b));

  Rect _balloonRect(_Balloon b) {
    final c = _balloonCenter(b);
    final s = b.scale * (b.highlighted ? 1 + 0.1 * (1 - math.cos(time * 2 * math.pi / 0.7)) : 1);
    return Rect.fromCenter(
        center: c, width: _pixels(_balloonWidth, b.lane.$2) * s, height: _pixels(_balloonHeight, b.lane.$2) * s * b.squish);
  }

  // Toys

  static const _toyIDs = ['car', 'duck', 'plane', 'ball'];

  double _shuttle(double halfWidth, double duration, double t) {
    // Drive one way, turn (0.4 s), drive back, turn.
    final cycle = 2 * duration + 0.8;
    final c = t % cycle;
    if (c < duration) return -halfWidth + 2 * halfWidth * (c / duration);
    if (c < duration + 0.4) return halfWidth;
    if (c < 2 * duration + 0.4) return halfWidth - 2 * halfWidth * ((c - duration - 0.4) / duration);
    return -halfWidth;
  }

  bool _facingRight(double duration, double t) => (t % (2 * duration + 0.8)) < duration + 0.2;

  double _hop(String id) {
    final left = _toyReact[id];
    if (left == null) return 0;
    final total = id == 'ball' ? 0.65 : 0.4;
    final k = 1 - left / total;
    return (id == 'ball' ? 1.1 : 0.5) * math.sin(k.clamp(0, 1) * math.pi);
  }

  double _spin(String id) {
    final left = _toyReact[id];
    if (left == null) return 0;
    final total = id == 'plane' ? 0.6 : 0.4;
    return (1 - left / total).clamp(0, 1) * 2 * math.pi;
  }

  _V3 _toyPosition(String id) {
    switch (id) {
      case 'car':
        return _V3(_shuttle(3.8, 5.5, time), _hop(id), -1.0);
      case 'duck':
        return _V3(_shuttle(2.4, 7, time), _hop(id), -3.9);
      case 'plane':
        final a = time * 2 * math.pi / 9;
        final bob = 0.125 * (1 - math.cos(2 * math.pi * time / 2.2));
        return _V3(2 * math.cos(a), 3.5 + bob + _hop(id), -1.6 - 2 * math.sin(a));
      default:
        final c = time % 1.2;
        final bounce = c < 0.45 ? 0.8 * easeOut(c / 0.45) : (c < 0.9 ? 0.8 * (1 - easeIn((c - 0.45) / 0.45)) : 0.0);
        return _V3(-2.2, bounce + _hop(id), -3.0);
    }
  }

  /// Size on screen (radius in metres) used for hits.
  static const _toyRadius = {'car': 0.45, 'duck': 0.4, 'plane': 0.35, 'ball': 0.38};

  Offset _toyCenter(String id) {
    final p = _toyPosition(id);
    final lift = id == 'plane' ? 0.0 : _toyRadius[id]!;
    return _project(_V3(p.x, p.y + lift, p.z));
  }

  void reactToy(String id) {
    if (_toyReact.containsKey(id)) return;
    _toyReact[id] = id == 'ball' ? 0.65 : (id == 'plane' ? 0.6 : 0.4);
  }

  // Shooting

  LearnBlasterShot shotAtAim() {
    final hits = <(double, LearnBlasterHit)>[];
    for (final b in _balloons.values) {
      if (b.scale < 0.3) continue;
      final r = _balloonRect(b);
      // The round part of the balloon, plus a little slack for small fingers.
      final body = Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.82).inflate(6);
      if (body.contains(aimPoint)) hits.add((_depth(b.lane.$2), HitTarget(b.face.id)));
    }
    for (final id in _toyIDs) {
      final p = _toyPosition(id);
      final radius = _pixels(_toyRadius[id]!, p.z) * 1.1;
      if ((aimPoint - _toyCenter(id)).distance <= radius) hits.add((_depth(p.z), HitToy(id)));
    }
    if (hits.isEmpty) return LearnBlasterShot(const HitNothing(), aimPoint);
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    return LearnBlasterShot(hits.first.$2, aimPoint);
  }

  void fire(LearnBlasterShot shot) {
    _shots.add(_Projectile(_muzzle, shot.point));
    timeline.tween(0.17, (t) => _recoil = 8 * math.sin(t * math.pi), curve: (x) => x, onDone: () => _recoil = 0);
  }

  void _burst(Offset at) {
    for (var i = 0; i < 70; i++) {
      final a = _random.nextDouble() * 2 * math.pi;
      final speed = 150 + _random.nextDouble() * 260;
      final hue = (0.93 + _random.nextDouble() * 0.5) % 1;
      _confetti.add(_Confetti(at, Offset(math.cos(a), math.sin(a)) * speed,
          HSVColor.fromAHSV(1, hue * 360, 0.75, 1).toColor(), 4 + _random.nextDouble() * 4, _random.nextDouble() * 8 - 4));
    }
  }

  // Frame

  @override
  void update(double dt) {
    for (final b in _balloons.values) {
      b.age += dt;
      final grow = ((b.age - b.delay) / 0.35).clamp(0.0, 1.0);
      b.scale = math.max(0.01, easeOut(grow));
    }
    for (final b in [..._gone]) {
      b.age += dt;
      if (b.popping) {
        b.scale = b.age < 0.08 ? 1 + 0.3 * b.age / 0.08 : math.max(0, 1.3 * (1 - (b.age - 0.08) / 0.14));
        b.opacity = b.age < 0.08 ? 1 : math.max(0, 1 - (b.age - 0.08) / 0.14);
        if (b.age > 0.25) _gone.remove(b);
      } else {
        b.opacity -= dt / 0.2;
        if (b.opacity <= 0) _gone.remove(b);
      }
    }
    for (final id in [..._toyReact.keys]) {
      final left = _toyReact[id]! - dt;
      left <= 0 ? _toyReact.remove(id) : _toyReact[id] = left;
    }
    for (final c in [..._confetti]) {
      c.age += dt;
      c.velocity += Offset(0, 520 * dt);
      c.position += c.velocity * dt;
      if (c.age > 1.1) _confetti.remove(c);
    }
    for (final s in [..._shots]) {
      s.age += dt;
      if (s.age > 0.26) _shots.remove(s);
    }
    final onTarget = shotAtAim().targetID != null;
    _aimOnTarget = onTarget;
    _aimGlow += ((onTarget ? 1 : 0) - _aimGlow) * math.min(1, dt * 14);
    repaint();
  }

  @override
  void render(Canvas canvas) {
    if (size.isEmpty) return;
    _drawRoom(canvas);
    // Everything in the room, farthest first.
    final items = <(double, void Function())>[
      for (final id in _toyIDs) (_depth(_toyPosition(id).z), () => _drawToy(canvas, id)),
      for (final b in [..._gone, ..._balloons.values]) (_depth(b.lane.$2) - 0.01, () => _drawBalloon(canvas, b)),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    for (final item in items) {
      item.$2();
    }
    for (final c in _confetti) {
      canvas.save();
      canvas.translate(c.position.dx, c.position.dy);
      canvas.rotate(c.age * c.spin);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: c.size, height: c.size * 0.6),
          Draw.fill(c.color.withValues(alpha: (1 - c.age / 1.1).clamp(0, 1))));
      canvas.restore();
    }
    for (final s in _shots) {
      final k = math.min(1.0, s.age / 0.16);
      final p = Offset.lerp(s.from, s.to, easeOut(k))!;
      final grow = s.age > 0.16 ? 1 + (s.age - 0.16) / 0.08 : 1.0;
      final fade = s.age > 0.16 ? math.max(0.0, 1 - (s.age - 0.16) / 0.1) : 1.0;
      final r = (14 - 8 * k) * grow;
      canvas.drawCircle(p, r * 1.8, Draw.fill(const Color(0xFFFFE066).withValues(alpha: 0.35 * fade)));
      canvas.drawCircle(p, r, Draw.fill(const Color(0xFFFFD60A).withValues(alpha: fade)));
    }
    _drawGrabRing(canvas);
    _drawBlaster(canvas);
    _drawCrosshair(canvas);
  }

  // Room

  void _drawRoom(Canvas canvas) {
    const w = _roomHalfWidth, h = _roomHeight, back = _backZ, front = 6.0;
    canvas.drawRect(Offset.zero & size, Draw.fill(const Color(0xFFC2E0FF)));
    // Ceiling, side walls, back wall, floor.
    canvas.drawPath(_poly(const [_V3(-w, h, back), _V3(w, h, back), _V3(w, h, front - 2), _V3(-w, h, front - 2)]),
        Draw.fill(const Color(0xFFFFF6E8)));
    const side = Color(0xFFFFE6CC);
    canvas.drawPath(_poly(const [_V3(-w, 0, back), _V3(-w, h, back), _V3(-w, h, front - 2), _V3(-w, 0, front - 2)]),
        Draw.fill(Draw.adjusted(side, 0.93)));
    canvas.drawPath(_poly(const [_V3(w, 0, back), _V3(w, h, back), _V3(w, h, front - 2), _V3(w, 0, front - 2)]),
        Draw.fill(Draw.adjusted(side, 0.93)));
    canvas.drawPath(_poly(const [_V3(-w, 0, back), _V3(w, 0, back), _V3(w, h, back), _V3(-w, h, back)]),
        Draw.fill(const Color(0xFFC2E0FF)));
    final floor = _poly(const [_V3(-w, 0, back), _V3(w, 0, back), _V3(w, 0, front - 2.2), _V3(-w, 0, front - 2.2)]);
    final floorTop = _project(const _V3(0, 0, back)).dy;
    canvas.drawPath(
      floor,
      Paint()
        ..shader = Gradient.linear(Offset(0, floorTop), Offset(0, size.height),
            [const Color(0xFFD9A066), const Color(0xFFB87A40)]),
    );
    // Wooden planks running towards the back wall.
    final plank = Draw.stroke(const Color(0x338A5A2B), 1.2);
    for (var x = -w; x <= w; x += 0.7) {
      canvas.drawLine(_project(_V3(x, 0, back)), _project(_V3(x, 0, front - 2.2)), plank);
    }
    for (var z = back + 1.4; z < front - 2.2; z += 1.4) {
      canvas.drawLine(_project(_V3(-w, 0, z)), _project(_V3(w, 0, z)), Draw.stroke(const Color(0x1F8A5A2B), 1));
    }
    // Baseboards.
    final trim = Draw.fill(const Color(0xFFFFFFFF));
    canvas.drawPath(_poly(const [_V3(-w, 0, back), _V3(w, 0, back), _V3(w, 0.18, back), _V3(-w, 0.18, back)]), trim);
    canvas.drawPath(_poly(const [_V3(-w, 0, back), _V3(-w, 0.18, back), _V3(-w, 0.18, 3.8), _V3(-w, 0, 3.8)]), trim);
    canvas.drawPath(_poly(const [_V3(w, 0, back), _V3(w, 0.18, back), _V3(w, 0.18, 3.8), _V3(w, 0, 3.8)]), trim);

    _drawWindow(canvas);
    _drawPoster(canvas);
    _drawRug(canvas);
    _drawBlocks(canvas);
    // Ceiling lamp.
    final lamp = _project(const _V3(0, 4.7, -1));
    final lampR = _pixels(0.3, -1);
    canvas.drawCircle(lamp, lampR * 2.2, Draw.fill(const Color(0x33FFF2BF)));
    canvas.drawCircle(lamp, lampR, Draw.fill(const Color(0xFFFFF2BF)));
  }

  void _drawWindow(Canvas canvas) {
    const z = _backZ + 0.05;
    final frame = Rect.fromPoints(_project(const _V3(-3.55, 3.85, z)), _project(const _V3(-1.05, 2.15, z)));
    canvas.drawRRect(RRect.fromRectAndRadius(frame, const Radius.circular(4)), Draw.fill(const Color(0xFFFFFFFF)));
    final glass = frame.deflate(frame.width * 0.04);
    canvas.save();
    canvas.clipRect(glass);
    canvas.drawRect(glass, Paint()..shader = Gradient.linear(glass.topCenter, glass.bottomCenter, [const Color(0xFF5BB8FF), const Color(0xFFBFE6FF)]));
    // Sun, drifting cloud and a green hill.
    canvas.drawCircle(glass.topRight + Offset(-glass.width * 0.2, glass.height * 0.28), glass.height * 0.14, Draw.fill(const Color(0xFFFFD84D)));
    final cx = glass.left + ((time * 6) % (glass.width + 60)) - 30;
    final cy = glass.top + glass.height * 0.35;
    final cloud = Draw.fill(const Color(0xEEFFFFFF));
    for (final (dx, r) in const [(0.0, 9.0), (10.0, 12.0), (22.0, 9.0)]) {
      canvas.drawCircle(Offset(cx + dx, cy), r * glass.height / 70, cloud);
    }
    canvas.drawOval(Rect.fromCenter(center: glass.bottomCenter + Offset(0, glass.height * 0.15), width: glass.width * 1.4, height: glass.height * 0.6),
        Draw.fill(const Color(0xFF6CC35E)));
    canvas.restore();
    final bar = Draw.stroke(const Color(0xFFFFFFFF), math.max(2, frame.width * 0.03));
    canvas.drawLine(glass.topCenter, glass.bottomCenter, bar);
    canvas.drawLine(glass.centerLeft, glass.centerRight, bar);
  }

  void _drawPoster(Canvas canvas) {
    const z = _backZ + 0.02;
    final poster = Rect.fromPoints(_project(const _V3(1.55, 3.575, z)), _project(const _V3(3.25, 2.425, z)));
    canvas.drawRRect(RRect.fromRectAndRadius(poster, const Radius.circular(3)), Draw.fill(const Color(0xFFFFF8E1)));
    canvas.drawRRect(RRect.fromRectAndRadius(poster, const Radius.circular(3)), Draw.stroke(const Color(0xFFFF8A65), 2));
    const letters = ['A', 'B', 'C'], numbers = ['1', '2', '3'];
    const colors = [Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047)];
    for (var i = 0; i < 3; i++) {
      final x = poster.left + poster.width * (0.2 + 0.3 * i);
      Draw.text(canvas, letters[i], Offset(x, poster.top + poster.height * 0.32), poster.height * 0.36, color: colors[i]);
      Draw.text(canvas, numbers[i], Offset(x, poster.top + poster.height * 0.74), poster.height * 0.3, color: colors[2 - i]);
    }
  }

  void _drawRug(Canvas canvas) {
    const rings = [Color(0xFFFF8FAB), Color(0xFFFFD166), Color(0xFF8BD3DD), Color(0xFFB39DDB)];
    for (var i = 0; i < rings.length; i++) {
      final r = 2.3 * (1 - i * 0.22);
      final points = [for (var k = 0; k < 40; k++) _V3(r * math.cos(k * math.pi / 20), 0.01, -1.6 + r * math.sin(k * math.pi / 20))];
      canvas.drawPath(_poly(points), Draw.fill(rings[i]));
    }
  }

  void _drawBox(Canvas canvas, _V3 c, double s, Color color, double turn) {
    final h = s / 2;
    _V3 corner(double dx, double dy, double dz) {
      final x = dx * math.cos(turn) - dz * math.sin(turn), z = dx * math.sin(turn) + dz * math.cos(turn);
      return _V3(c.x + x, c.y + dy, c.z + z);
    }

    final front = [corner(-h, -h, h), corner(h, -h, h), corner(h, h, h), corner(-h, h, h)];
    final top = [corner(-h, h, h), corner(h, h, h), corner(h, h, -h), corner(-h, h, -h)];
    final left = [corner(-h, -h, -h), corner(-h, -h, h), corner(-h, h, h), corner(-h, h, -h)];
    // The camera is on the left of the corner blocks, so their left side shows.
    canvas.drawPath(_poly(left), Draw.fill(Draw.adjusted(color, 0.75)));
    canvas.drawPath(_poly(front), Draw.fill(color));
    canvas.drawPath(_poly(top), Draw.fill(Draw.adjusted(color, 1.15, 0.85)));
  }

  void _drawBlocks(Canvas canvas) {
    _drawBox(canvas, const _V3(3.3, 0.25, -4.35), 0.5, const Color(0xFF2979FF), 0.2);
    _drawBox(canvas, const _V3(3.9, 0.25, -4.2), 0.5, const Color(0xFFFF3B30), -0.15);
    _drawBox(canvas, const _V3(3.6, 0.75, -4.25), 0.5, const Color(0xFFFFCC00), 0.1);
  }

  // Toys

  void _drawShadow(Canvas canvas, _V3 at, double radius) {
    final c = _project(_V3(at.x, 0.005, at.z));
    final r = _pixels(radius, at.z);
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 2, height: r * 0.5), Draw.fill(const Color(0x33000000)));
  }

  void _drawToy(Canvas canvas, String id) {
    final p = _toyPosition(id);
    final unit = _pixels(1, p.z);
    switch (id) {
      case 'car':
        _drawShadow(canvas, p, 0.45);
        final base = _project(p);
        final right = _facingRight(5.5, time);
        canvas.save();
        canvas.translate(base.dx, base.dy);
        // A hit spins the car round once.
        final turn = math.cos(_spin(id));
        canvas.scale((right ? 1 : -1) * (turn < 0 ? -1 : 1) * math.max(0.05, turn.abs()), 1);
        final u = unit * 1.4;
        final rumble = 0.02 * u * math.sin(time * 40);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-0.3 * u, -0.3 * u + rumble, 0.6 * u, 0.2 * u), Radius.circular(0.06 * u)),
            Draw.fill(const Color(0xFFFF3B30)));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-0.2 * u, -0.45 * u + rumble, 0.32 * u, 0.16 * u), Radius.circular(0.05 * u)),
            Draw.fill(const Color(0xFFB3E5FC)));
        canvas.drawCircle(Offset(0.29 * u, -0.2 * u + rumble), 0.035 * u, Draw.fill(const Color(0xFFFFD60A)));
        for (final x in const [-0.2, 0.2]) {
          canvas.drawCircle(Offset(x * u, -0.09 * u), 0.09 * u, Draw.fill(const Color(0xFF444444)));
          canvas.drawCircle(Offset(x * u, -0.09 * u), 0.04 * u, Draw.fill(const Color(0xFFBBBBBB)));
        }
        canvas.restore();
      case 'duck':
        _drawShadow(canvas, p, 0.35);
        final base = _project(p);
        final right = _facingRight(7, time);
        final u = unit * 1.5;
        canvas.save();
        canvas.translate(base.dx, base.dy);
        canvas.scale(right ? 1 : -1, 1);
        canvas.rotate(0.15 * math.sin(time * 2 * math.pi / 0.5));
        const yellow = Color(0xFFFFD91A);
        canvas.drawOval(Rect.fromCenter(center: Offset(0, -0.2 * u), width: 0.57 * u, height: 0.4 * u), Draw.fill(yellow));
        canvas.drawCircle(Offset(0.18 * u, -0.45 * u), 0.14 * u, Draw.fill(yellow));
        final beak = Path()
          ..moveTo(0.29 * u, -0.47 * u)
          ..lineTo(0.42 * u, -0.43 * u)
          ..lineTo(0.29 * u, -0.39 * u)
          ..close();
        canvas.drawPath(beak, Draw.fill(const Color(0xFFFF9500)));
        canvas.drawCircle(Offset(0.22 * u, -0.5 * u), 0.025 * u, Draw.fill(const Color(0xFF000000)));
        canvas.drawOval(Rect.fromCenter(center: Offset(-0.05 * u, -0.22 * u), width: 0.26 * u, height: 0.14 * u), Draw.fill(Draw.adjusted(yellow, 0.88)));
        canvas.restore();
      case 'plane':
        final c = _project(p);
        final a = time * 2 * math.pi / 9;
        // Seen from the side when crossing, nose first when flying towards the camera.
        final across = -math.sin(a);
        final u = unit;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(0.35 * across.sign + _spin(id));
        canvas.scale(across.abs() < 0.2 ? 0.2 * across.sign.abs() + 0.2 : across.sign, 1);
        final wing = Path()
          ..moveTo(0.35 * u, 0)
          ..lineTo(-0.3 * u, -0.22 * u)
          ..lineTo(-0.18 * u, 0)
          ..lineTo(-0.3 * u, 0.1 * u)
          ..close();
        canvas.drawPath(wing, Draw.fill(const Color(0xFFFFFFFF)));
        canvas.drawPath(wing, Draw.stroke(const Color(0x33000000), 1));
        canvas.drawLine(Offset(-0.2 * u, 0), Offset(0.3 * u, 0), Draw.stroke(const Color(0xFF1E88E5), math.max(1, 0.03 * u)));
        canvas.restore();
      default:
        _drawShadow(canvas, _V3(p.x, 0, p.z), 0.38 * (1 - p.y * 0.3).clamp(0.4, 1));
        final r = 0.38 * unit;
        final c = _project(_V3(p.x, p.y + 0.38, p.z));
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r)));
        canvas.rotate(time * 2 * math.pi / 3);
        const stripes = [Color(0xFFFF3B30), Color(0xFFFFFFFF), Color(0xFF2979FF), Color(0xFFFFFFFF), Color(0xFFFFCC00), Color(0xFFFFFFFF)];
        for (var i = 0; i < stripes.length; i++) {
          final start = i * 2 * math.pi / stripes.length;
          canvas.drawPath(
              Path()
                ..moveTo(0, 0)
                ..arcTo(Rect.fromCircle(center: Offset.zero, radius: r * 1.5), start, 2 * math.pi / stripes.length, false)
                ..close(),
              Draw.fill(stripes[i]));
        }
        canvas.restore();
        canvas.drawCircle(c + Offset(-r * 0.35, -r * 0.35), r * 0.22, Draw.fill(const Color(0x55FFFFFF)));
        canvas.drawCircle(c, r, Draw.stroke(const Color(0x22000000), 1));
    }
  }

  // Balloons

  void _drawBalloon(Canvas canvas, _Balloon b) {
    if (b.scale <= 0.02 || b.opacity <= 0.01) return;
    final rect = _balloonRect(b);
    final w = rect.width, h = rect.height;
    // Drawn on a 400×500 card like the iOS balloon image.
    double sx(double v) => rect.left + v / 400 * w;
    double sy(double v) => rect.top + v / 500 * h;
    final alpha = b.opacity.clamp(0.0, 1.0);
    canvas.saveLayer(rect.inflate(4), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));

    final string = Path()
      ..moveTo(sx(200), sy(410))
      ..cubicTo(sx(170), sy(440), sx(230), sy(470), sx(200), sy(500));
    canvas.drawPath(string, Draw.stroke(const Color(0xD9FFFFFF), math.max(1, w * 5 / 400)));
    final knot = Path()
      ..moveTo(sx(200), sy(392))
      ..lineTo(sx(182), sy(418))
      ..lineTo(sx(218), sy(418))
      ..close();
    canvas.drawPath(knot, Draw.fill(b.color));

    final body = Rect.fromLTRB(sx(20), sy(16), sx(380), sy(400));
    canvas.drawOval(
      body,
      Paint()
        ..shader = Gradient.linear(Offset(sx(120), sy(20)), Offset(sx(280), sy(400)), [b.color.withValues(alpha: 0.75), b.color]),
    );
    canvas.drawOval(body.deflate(w * 4 / 400), Draw.stroke(const Color(0xE6FFFFFF), math.max(1.5, w * 8 / 400)));
    canvas.drawOval(Rect.fromLTWH(sx(80), sy(60), w * 0.2, h * 0.1), Draw.fill(const Color(0x66FFFFFF)));
    if (b.highlighted) {
      final glow = 0.5 + 0.5 * math.sin(time * 2 * math.pi / 0.7);
      canvas.drawOval(body.inflate(3), Draw.stroke(Color.fromRGBO(255, 235, 59, 0.6 + 0.4 * glow), math.max(2, w * 0.03)));
    }

    final content = Rect.fromLTRB(sx(50), sy(50), sx(350), sy(370));
    final face = b.face;
    void fitted(String text, Rect area, double size) {
      var s = size;
      final m = Draw.measure(text, s);
      if (m.width > area.width) s *= area.width / m.width;
      Draw.text(canvas, text, area.center, s, shadow: true);
    }

    if (face.emoji != null && face.title != null) {
      fitted(face.emoji!, Rect.fromLTWH(content.left, content.top, content.width, content.height * 190 / 320), w * 140 / 400);
      fitted(face.title!, Rect.fromLTWH(content.left, content.top + content.height * 190 / 320, content.width, content.height * 120 / 320),
          w * 80 / 400);
    } else if (face.emoji != null) {
      fitted(face.emoji!, content, w * 200 / 400);
    } else if (face.title != null) {
      fitted(face.title!, content, w * 230 / 400);
    }
    canvas.restore();
  }

  // Blaster, ring and crosshair

  void _drawBlaster(Canvas canvas) {
    final grip = blasterPoint;
    final u = size.height * 0.09 / 0.45; // pixels per blaster metre
    canvas.save();
    canvas.translate(grip.dx, grip.dy);
    canvas.rotate(_blasterAngle);
    canvas.translate(0, _recoil);
    // Handle, body, barrel and glowing tip (nose points up).
    canvas.save();
    canvas.translate(0, 0.08 * u);
    canvas.rotate(-0.3);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, 0.06 * u), width: 0.09 * u, height: 0.2 * u), Radius.circular(0.03 * u)),
        Draw.fill(const Color(0xFFFF4F8B)));
    canvas.restore();
    final bodyRect = Rect.fromCenter(center: Offset(0, -0.06 * u), width: 0.18 * u, height: 0.36 * u);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(0.06 * u)),
      Paint()..shader = Gradient.linear(bodyRect.centerLeft, bodyRect.centerRight, [const Color(0xFFFFB340), const Color(0xFFFF8C00), const Color(0xFFE07000)], [0, 0.5, 1]),
    );
    final barrel = Rect.fromCenter(center: Offset(0, -0.32 * u), width: 0.07 * u, height: 0.26 * u);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barrel, Radius.circular(0.03 * u)),
      Paint()..shader = Gradient.linear(barrel.centerLeft, barrel.centerRight, [const Color(0xFF5AD8E6), const Color(0xFF1AA6B7)]),
    );
    canvas.drawCircle(Offset(0, -0.45 * u), 0.08 * u, Draw.fill(const Color(0x55FFD60A)));
    canvas.drawCircle(Offset(0, -0.45 * u), 0.05 * u, Draw.fill(const Color(0xFFFFD60A)));
    canvas.drawOval(Rect.fromCenter(center: Offset(-0.04 * u, -0.12 * u), width: 0.04 * u, height: 0.16 * u), Draw.fill(const Color(0x55FFFFFF)));
    canvas.restore();
  }

  void _drawGrabRing(Canvas canvas) {
    final c = blasterPoint + Offset(0, -size.height * 0.02);
    final pulse = showsTip ? 1 + 0.06 * (1 - math.cos(time * 2 * math.pi / 1.4)) : 1.0;
    final r = 65 * pulse;
    final paint = Draw.stroke(Color.fromRGBO(255, 255, 255, showsTip ? 0.8 : 0.36), 3);
    const dashes = 24;
    for (var i = 0; i < dashes; i++) {
      final a = i * 2 * math.pi / dashes;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a, 2 * math.pi / dashes * 0.55, false, paint);
    }
    if (showsTip) Draw.text(canvas, '✋', c + Offset(0, -r - 4), 30);
  }

  void _drawCrosshair(Canvas canvas) {
    final color = Color.lerp(const Color(0xFFFFFFFF), const Color(0xFF34C759), _aimGlow)!;
    final s = 1 + 0.15 * _aimGlow;
    final c = aimPoint;
    final shadow = Draw.stroke(const Color(0x66000000), 6);
    canvas.drawCircle(c, 32 * s, shadow);
    if (_aimOnTarget || _aimGlow > 0.05) canvas.drawCircle(c, 32 * s, Draw.fill(color.withValues(alpha: 0.25 * _aimGlow)));
    canvas.drawCircle(c, 32 * s, Draw.stroke(color, 4));
    canvas.drawCircle(c, 5 * s, Draw.fill(color));
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(c + dir * 33 * s, c + dir * 47 * s, Draw.stroke(const Color(0x66000000), 6));
      canvas.drawLine(c + dir * 33 * s, c + dir * 47 * s, Draw.stroke(color, 4));
    }
  }
}
