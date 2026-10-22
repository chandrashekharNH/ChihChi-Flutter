import 'dart:math' as math;
import 'dart:ui';

import '../../core/ui/palette.dart';
import 'draw.dart';
import 'game_scene.dart';

enum ChihChiExpression { neutral, happy, surprised, confused }

/// ChihChi — the app's little chick mascot, drawn with shapes so no image assets are needed.
/// Position is the centre of the body; size is the body's diameter.
class ChihChiSprite {
  ChihChiSprite({this.size = 90});

  final double size;
  Offset position = Offset.zero;
  bool facingLeft = false;
  ChihChiExpression expression = ChihChiExpression.neutral;
  double _look = 0;

  // Animation state (offsets of the body from `position`).
  Offset _reach = Offset.zero;
  double _jump = 0;
  double _spin = 0;
  double _tilt = 0;
  double _wingFlap = 0;
  double _squashX = 1, _squashY = 1;
  double _blinkTimer = 2.5;
  double _blink = 1;
  double _popQuestion = 0, _popExclaim = 0;
  final Timeline _anims = Timeline();
  double _time = 0;

  static final _yellow = rgb(1.0, 0.84, 0.2);
  static final _outline = rgb(0.9, 0.55, 0.1);
  static final _orange = rgb(1.0, 0.55, 0.1);

  void update(double dt) {
    _time += dt;
    _anims.update(dt);
    _blinkTimer -= dt;
    if (_blinkTimer <= 0) {
      _blinkTimer = 2.5 + math.Random().nextDouble() * 2;
      _anims.tween(0.14, (t) => _blink = t < 0.43 ? 1 - 0.9 * (t / 0.43) : 0.1 + 0.9 * ((t - 0.43) / 0.57));
    }
  }

  void setExpression(ChihChiExpression e) {
    expression = e;
    if (e == ChihChiExpression.confused) _pop((v) => _popQuestion = v);
    if (e == ChihChiExpression.surprised) _pop((v) => _popExclaim = v);
    if (e != ChihChiExpression.confused) _look = 0;
  }

  void _pop(void Function(double) set) {
    _anims.tween(1.55, (t) {
      final s = t * 1.55;
      if (s < 0.15) {
        set(0.2 + (s / 0.15));
      } else if (s < 1.25) {
        set(1);
      } else {
        set(1 - (s - 1.25) / 0.3);
      }
    }, curve: (x) => x);
  }

  /// -1 = left, 0 = centre, 1 = right.
  void look(double direction) => _look = direction;

  void flapWings([int times = 3]) {
    _anims.tween(0.16 * times, (t) => _wingFlap = math.sin(t * times * math.pi).abs(), curve: (x) => x,
        onDone: () => _wingFlap = 0);
  }

  void celebrate() {
    setExpression(ChihChiExpression.happy);
    flapWings(5);
    _anims.tween(0.5, (t) {
      _jump = math.sin(t * math.pi) * 0.7 * size;
      _spin = t * 2 * math.pi;
    }, curve: (x) => x, onDone: () {
      _jump = 0;
      _spin = 0;
    });
  }

  void confusedShake() {
    setExpression(ChihChiExpression.confused);
    const keys = [0.25, -0.25, 0.15, 0.0];
    const times = [0.12, 0.2, 0.15, 0.12];
    var start = 0.0;
    var from = 0.0;
    for (var i = 0; i < keys.length; i++) {
      final a = from, b = keys[i];
      _anims.tween(times[i], (t) => _tilt = a + (b - a) * t, delay: start);
      start += times[i];
      from = b;
    }
  }

  /// Leans toward a point and back — ChihChi "reaching" for something.
  void reach(Offset point) {
    final d = point - position;
    final distance = math.max(1.0, d.distance);
    final length = math.min(0.6 * size, distance);
    final target = d / distance * length;
    look(d.dx >= 0 ? 1 : -1);
    _anims.tween(0.14, (t) => _reach = target * t, onDone: () {
      _anims.tween(0.2, (t) => _reach = target * (1 - t), onDone: () => _reach = Offset.zero);
    });
  }

  /// Bouncy hop to a point.
  void hop(Offset to, {double? height, double duration = 0.45}) {
    final from = position;
    final jump = height ?? 0.6 * size;
    flapWings(2);
    _anims.tween(duration, (t) {
      position = Offset.lerp(from, to, t)!;
      _jump = math.sin(t * math.pi) * jump;
    }, onDone: () {
      _jump = 0;
      _anims.tween(0.18, (t) {
        final k = t < 0.45 ? t / 0.45 : 1 - (t - 0.45) / 0.55;
        _squashX = 1 + 0.15 * k;
        _squashY = 1 - 0.15 * k;
      }, onDone: () {
        _squashX = 1;
        _squashY = 1;
      });
    });
  }

  void lookAround() {
    look(-1);
    _anims.after(0.5, () => look(1));
    _anims.after(1.0, () => look(0));
  }

  void render(Canvas canvas) {
    final s = size;
    final bob = math.sin(_time * math.pi / 1.2) * 0.02 * s;
    canvas.save();
    canvas.translate(position.dx + _reach.dx, position.dy + _reach.dy - _jump - bob);
    canvas.rotate(_tilt + _spin);
    canvas.scale((facingLeft ? -1 : 1) * _squashX, _squashY);

    // Feet
    for (final x in [-0.15 * s, 0.15 * s]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x, 0.5 * s), width: 0.2 * s, height: 0.08 * s), Draw.fill(_orange));
    }
    // Wings (behind the body)
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(side * 0.45 * s, 0.08 * s);
      canvas.rotate(-side * (0.5 + 0.6 * _wingFlap));
      final r = Rect.fromCenter(center: Offset.zero, width: 0.26 * s, height: 0.4 * s);
      canvas.drawOval(r, Draw.fill(rgb(1.0, 0.76, 0.15)));
      canvas.drawOval(r, Draw.stroke(_outline, 2));
      canvas.restore();
    }
    // Head tuft
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate((i - 1) * 0.07 * s, -0.54 * s);
      canvas.rotate(-[0.35, 0.0, -0.35][i]);
      final r = Rect.fromCenter(center: Offset.zero, width: 0.1 * s, height: 0.24 * s);
      canvas.drawOval(r, Draw.fill(_yellow));
      canvas.drawOval(r, Draw.stroke(_outline, 2));
      canvas.restore();
    }
    // Body
    final body = Rect.fromCircle(center: Offset.zero, radius: 0.5 * s);
    canvas.drawOval(
        body,
        Paint()
          ..shader = Gradient.radial(Offset(-0.15 * s, -0.2 * s), 0.6 * s, [rgb(1, 0.92, 0.45), _yellow, rgb(0.98, 0.74, 0.12)],
              [0, 0.6, 1]));
    canvas.drawOval(body, Draw.stroke(_outline, 3));
    canvas.drawOval(Rect.fromCenter(center: Offset(0, 0.22 * s), width: 0.6 * s, height: 0.45 * s), Draw.fill(rgb(1, 0.93, 0.6)));
    // Cheeks
    for (final x in [-0.3 * s, 0.3 * s]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x, 0.05 * s), width: 0.14 * s, height: 0.08 * s),
          Draw.fill(rgb(1, 0.5, 0.55, 0.6)));
    }
    // Eyes
    final happy = expression == ChihChiExpression.happy;
    for (var i = 0; i < 2; i++) {
      final x = (i == 0 ? -0.17 : 0.17) * s;
      if (happy) {
        final path = Path()
          ..addArc(Rect.fromCircle(center: Offset(x, -0.04 * s), radius: 0.08 * s), math.pi * 1.15, math.pi * 0.7);
        canvas.drawPath(path, Draw.stroke(const Color(0xFF1A1A1A), 0.045 * s));
        continue;
      }
      final eyeScale = expression == ChihChiExpression.surprised ? 1.2 : 1.0;
      final white = Rect.fromCenter(center: Offset(x, -0.12 * s), width: 0.22 * s * eyeScale, height: 0.26 * s * eyeScale * _blink);
      canvas.drawOval(white, Draw.fill(const Color(0xFFFFFFFF)));
      canvas.drawOval(white, Draw.stroke(const Color(0xFF333333), 1.5));
      if (_blink < 0.4) continue;
      var pupil = Offset(x + _look * 0.045 * s, -0.12 * s + 0.02 * s);
      if (expression == ChihChiExpression.confused) {
        pupil = Offset(x + (i == 0 ? -0.03 : 0.03) * s, -0.12 * s + (i == 0 ? -0.03 : 0.05) * s);
      }
      final pr = 0.07 * s * (expression == ChihChiExpression.surprised ? 0.8 : 1);
      canvas.drawCircle(pupil, pr, Draw.fill(const Color(0xFF1A1A1A)));
      canvas.drawCircle(pupil + Offset(0.025 * s, -0.03 * s), 0.025 * s, Draw.fill(const Color(0xFFFFFFFF)));
    }
    // Beak
    final open = happy || expression == ChihChiExpression.surprised;
    final beakFill = Draw.fill(_orange);
    final beakLine = Draw.stroke(rgb(0.85, 0.4, 0.05), 1.5);
    if (open) {
      final top = Path()
        ..moveTo(-0.1 * s, 0.02 * s)
        ..lineTo(0.1 * s, 0.02 * s)
        ..lineTo(0, 0.1 * s)
        ..close();
      final bottom = Path()
        ..moveTo(-0.08 * s, 0.12 * s)
        ..lineTo(0.08 * s, 0.12 * s)
        ..lineTo(0, 0.21 * s)
        ..close();
      for (final p in [top, bottom]) {
        canvas.drawPath(p, beakFill);
        canvas.drawPath(p, beakLine);
      }
    } else {
      final closed = Path()
        ..moveTo(-0.09 * s, 0.04 * s)
        ..lineTo(0.09 * s, 0.04 * s)
        ..lineTo(0, 0.16 * s)
        ..close();
      canvas.drawPath(closed, beakFill);
      canvas.drawPath(closed, beakLine);
    }
    canvas.restore();

    // Question mark / exclamation pop above the head
    final markAt = position + Offset(0.45 * s, -0.55 * s - _jump);
    if (_popQuestion > 0.01) Draw.text(canvas, '?', markAt, 0.5 * s, scale: _popQuestion.clamp(0.2, 1.2), opacity: _popQuestion.clamp(0, 1));
    if (_popExclaim > 0.01) Draw.text(canvas, '!', markAt, 0.5 * s, scale: _popExclaim.clamp(0.2, 1.2), opacity: _popExclaim.clamp(0, 1));
  }
}
