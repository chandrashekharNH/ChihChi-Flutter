import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'avatar_appearance.dart';
import 'character_model.dart';

/// The standard moves every character can do. Appearance and animation are separate: any look
/// plays any of these.
enum CharacterAnimation {
  idle,
  walk,
  run,
  jump,
  celebrate,
  win,
  sad,
  wave,
  dance,
  collect,
  hit;

  /// Loops until something else plays; the rest play once and settle back into idle.
  bool get loops => this == idle || this == walk || this == run || this == dance;

  /// Length of a one-shot move.
  double get duration => switch (this) {
        jump => 0.8,
        celebrate => 1.1,
        win => 1.1,
        sad => 1.8,
        wave => 1.6,
        collect => 0.65,
        hit => 0.6,
        _ => double.infinity,
      };
}

double _ease(double x) => x <= 0 ? 0 : (x >= 1 ? 1 : x * x * (3 - 2 * x));

/// A value that moves through `keys` (duration, target) from `start`, eased, optionally looping.
double _track(double t, double start, List<(double, double)> keys, {bool loop = false}) {
  final total = keys.fold<double>(0, (a, k) => a + k.$1);
  if (total <= 0) return start;
  var time = loop ? t % total : t;
  var from = loop ? keys.last.$2 : start;
  if (loop && t < total) from = start;
  for (final (duration, target) in keys) {
    if (time <= duration) return from + (target - from) * _ease(duration == 0 ? 1 : time / duration);
    time -= duration;
    from = target;
  }
  return from;
}

List<(double, double)> _hop(double height, double duration) =>
    [(duration * 0.2, -0.06), (duration * 0.35, height), (duration * 0.45, 0)];

List<(double, double)> _repeat(List<(double, double)> keys, int count) => [for (var i = 0; i < count; i++) ...keys];

/// Sets the joints of `rig` for `animation` at `t` seconds in.
void poseCharacter(CharacterRig rig, CharacterAnimation animation, double t) {
  rig.reset();
  final hips = rig[Joint.hips], torso = rig[Joint.torso], head = rig[Joint.head];
  final la = rig[Joint.leftArm], ra = rig[Joint.rightArm], ll = rig[Joint.leftLeg], rl = rig[Joint.rightLeg];
  final restY = hips.rest.y;

  void armsUp(double d) {
    la.euler.z = _track(t, -0.12, [(d, -2.6)]);
    ra.euler.z = _track(t, 0.12, [(d, 2.6)]);
  }

  switch (animation) {
    case CharacterAnimation.idle:
      hips.position.y = restY + _track(t, 0, [(0.9, 0.018), (0.9, 0)], loop: true);
      la.euler.z = _track(t, -0.12, [(0.9, -0.2), (0.9, -0.1)], loop: true);
      ra.euler.z = _track(t, 0.12, [(0.9, 0.2), (0.9, 0.1)], loop: true);
      // A blink every few seconds.
      final phase = t % 2.75;
      final closed = phase > 2.6 && phase < 2.74;
      for (final eye in rig.eyes) {
        eye.scale.y = closed ? 0.1 : 1;
      }
    case CharacterAnimation.walk:
    case CharacterAnimation.run:
      final run = animation == CharacterAnimation.run;
      final legs = run ? 0.95 : 0.5, arms = run ? 0.9 : 0.45, period = run ? 0.36 : 0.6;
      final bob = run ? 0.06 : 0.03, lean = run ? 0.2 : 0.04;
      final half = period / 2;
      ll.euler.x = _track(t, 0, [(half, legs), (half, -legs)], loop: true);
      rl.euler.x = _track(t, 0, [(half, -legs), (half, legs)], loop: true);
      la.euler
        ..x = _track(t, 0, [(half, -arms), (half, arms)], loop: true)
        ..z = -0.1;
      ra.euler
        ..x = _track(t, 0, [(half, arms), (half, -arms)], loop: true)
        ..z = 0.1;
      torso.euler.x = _track(t, 0, [(0.2, lean)]);
      hips.position.y = restY + _track(t, 0, [(half / 2, bob), (half / 2, 0)], loop: true);
    case CharacterAnimation.dance:
      hips.euler
        ..y = _track(t, 0, [(0.35, 0.3), (0.35, -0.3)], loop: true)
        ..z = _track(t, 0, [(0.35, 0.12), (0.35, -0.12)], loop: true);
      la.euler.z = _track(t, -0.12, [(0.35, -2.5), (0.35, -0.4)], loop: true);
      ra.euler.z = _track(t, 0.12, [(0.35, 0.4), (0.35, 2.5)], loop: true);
      head.euler.z = _track(t, 0, [(0.35, -0.15), (0.35, 0.15)], loop: true);
    case CharacterAnimation.jump:
      hips.position.y = restY + _track(t, 0, _hop(0.45, 0.7));
      armsUp(0.25);
      ll.euler.x = _track(t, 0, [(0.25, -0.5), (0.4, 0)]);
      rl.euler.x = _track(t, 0, [(0.25, 0.3), (0.4, 0)]);
    case CharacterAnimation.celebrate:
      armsUp(0.2);
      hips.position.y = restY + _track(t, 0, [..._hop(0.3, 0.5), ..._hop(0.3, 0.5)]);
      head.euler
        ..x = _track(t, 0, [(0.25, -0.15)])
        ..z = _track(t, 0, _repeat([(0.25, 0.15), (0.25, -0.15)], 2));
    case CharacterAnimation.win:
      armsUp(0.2);
      hips.position.y = restY + _track(t, 0, _hop(0.35, 0.9));
      hips.euler.y = math.min(t / 0.9, 1) * 2 * math.pi;
    case CharacterAnimation.sad:
      head.euler
        ..x = _track(t, 0, [(0.4, 0.4)])
        ..z = _track(t, 0, [(0.4, 0.1)]);
      torso.euler.x = _track(t, 0, [(0.4, 0.15)]);
      la.euler
        ..x = _track(t, 0, [(0.4, -0.2)])
        ..z = _track(t, -0.12, [(0.4, 0.05)]);
      ra.euler
        ..x = _track(t, 0, [(0.4, -0.2)])
        ..z = _track(t, 0.12, [(0.4, -0.05)]);
    case CharacterAnimation.wave:
      ra.euler.z = _track(t, 0.12, [(0.25, 2.5), ..._repeat([(0.2, 2.1), (0.2, 2.8)], 3)]);
      head.euler.z = _track(t, 0, [(0.3, -0.12)]);
    case CharacterAnimation.collect:
      for (final arm in [la, ra]) {
        arm.euler.x = _track(t, 0, [(0.2, -1.4), (0.15, -1.4), (0.25, -0.3)]);
      }
      hips.position.y = restY + _track(t, 0, _hop(0.12, 0.4));
    case CharacterAnimation.hit:
      torso.euler.x = _track(t, 0, [(0.1, -0.35), (0.2, 0.1), (0.2, 0)]);
      head.euler.y = _track(t, 0, _repeat([(0.08, 0.25), (0.08, -0.25)], 3));
      la.euler.z = _track(t, -0.12, [(0.1, -1.0), (0.3, -0.12)]);
      ra.euler.z = _track(t, 0.12, [(0.1, 1.0), (0.3, 0.12)]);
  }
}

/// What part of the character fills the view.
enum CharacterFraming {
  fullBody(0.9, 2.46),
  upperBody(1.3, 1.36),
  portrait(1.36, 1.48);

  const CharacterFraming(this.centerY, this.visibleHeight);

  /// Model height at the middle of the view, and how much model height fits in it.
  final double centerY;
  final double visibleHeight;
}

class _Item {
  _Item(this.shape, this.matrix, this.depth, this.order);
  final Shape3D shape;
  final vm.Matrix4 matrix;
  final double depth;
  final int order;
}

/// Draws a posed character: every shape projected, sorted back to front and shaded.
class CharacterPainter extends CustomPainter {
  CharacterPainter(this.rig, {this.yaw = 0, this.framing = CharacterFraming.fullBody, this.shadow = true, super.repaint});

  final CharacterRig rig;
  final double yaw;
  final CharacterFraming framing;
  final bool shadow;

  late double _s;
  late Offset _origin;

  Offset _project(vm.Vector3 p) => Offset(_origin.dx + p.x * _s, _origin.dy - (p.y - framing.centerY) * _s);

  @override
  void paint(Canvas canvas, Size size) {
    _s = size.height / framing.visibleHeight;
    _origin = Offset(size.width / 2, size.height / 2);
    final view = vm.Matrix4.rotationY(yaw);
    final items = <_Item>[];
    var order = 0;
    void walk(Node3D node, vm.Matrix4 parent) {
      final m = parent * node.local;
      for (final shape in node.shapes) {
        items.add(_Item(shape, m, _depthOf(shape, m), order++));
      }
      for (final child in node.children) {
        walk(child, m);
      }
    }

    walk(rig.root, view);
    items.sort((a, b) {
      final d = a.depth.compareTo(b.depth);
      return d != 0 ? d : a.order.compareTo(b.order);
    });

    if (shadow) {
      final c = _project(vm.Vector3.zero());
      canvas.drawOval(Rect.fromCenter(center: c, width: 1.1 * _s, height: 0.22 * _s),
          Paint()..color = const Color(0x2E000000));
    }
    for (final item in items) {
      _draw(canvas, item);
    }
  }

  double _depthOf(Shape3D shape, vm.Matrix4 m) {
    vm.Vector3 c;
    switch (shape) {
      case SphereShape():
        c = shape.center;
      case CapsuleShape():
        c = (shape.a + shape.b) * 0.5;
      case FrustumShape():
        c = (shape.a + shape.b) * 0.5;
      case LineShape():
        c = shape.points.fold(vm.Vector3.zero(), (a, p) => a + p) / shape.points.length.toDouble();
      case CuboidShape():
        c = shape.center;
    }
    return m.transformed3(c).z;
  }

  static double _scaleOf(vm.Matrix4 m) {
    final l = m.getRotation();
    return (l.getColumn(0).length + l.getColumn(1).length + l.getColumn(2).length) / 3;
  }

  static Color _shade(Color c, double amount) => amount >= 0
      ? Color.lerp(c, const Color(0xFFFFFFFF), amount)!
      : Color.lerp(c, const Color(0xFF000000), -amount)!;

  Paint _fill(Shape3D shape, Rect bounds) {
    final paint = Paint()..isAntiAlias = true;
    final base = shape.color.withValues(alpha: shape.color.a * shape.opacity);
    if (shape.finish == Finish.glow) return paint..color = base;
    paint.shader = RadialGradient(
      center: const Alignment(-0.35, -0.45),
      radius: 1.05,
      colors: [_shade(base, 0.28), base, _shade(base, -0.28)],
      stops: const [0, 0.55, 1],
    ).createShader(bounds);
    return paint;
  }

  void _highlight(Canvas canvas, Rect bounds) => canvas.drawOval(
      Rect.fromCenter(
          center: bounds.center + Offset(-bounds.width * 0.18, -bounds.height * 0.22),
          width: bounds.width * 0.28,
          height: bounds.height * 0.2),
      Paint()..color = const Color(0x66FFFFFF));

  void _draw(Canvas canvas, _Item item) {
    final shape = item.shape, m = item.matrix;
    switch (shape) {
      case SphereShape():
        _sphere(canvas, shape, m);
      case CapsuleShape():
        final a = _project(m.transformed3(shape.a)), b = _project(m.transformed3(shape.b));
        final r = shape.radius * _scaleOf(m) * _s;
        _stick(canvas, shape, a, b, r, r);
      case FrustumShape():
        final a = _project(m.transformed3(shape.a)), b = _project(m.transformed3(shape.b));
        final k = _scaleOf(m) * _s;
        _stick(canvas, shape, a, b, shape.ra * k, shape.rb * k, flat: true);
      case LineShape():
        final points = [for (final p in shape.points) _project(m.transformed3(p))];
        if (points.length < 2) return;
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final p in points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        if (shape.closed) path.close();
        final base = shape.color.withValues(alpha: shape.color.a * shape.opacity);
        canvas.drawPath(
            path,
            Paint()
              ..color = base
              ..isAntiAlias = true
              ..style = shape.filled ? PaintingStyle.fill : PaintingStyle.stroke
              ..strokeWidth = shape.width * _scaleOf(m) * _s
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round);
      case CuboidShape():
        final h = shape.size * 0.5;
        final corners = [
          for (final x in [-h.x, h.x])
            for (final y in [-h.y, h.y])
              for (final z in [-h.z, h.z]) _project(m.transformed3(shape.center + vm.Vector3(x, y, z))),
        ];
        final hull = _hull(corners);
        final path = Path()..addPolygon(hull, true);
        final bounds = path.getBounds();
        final rr = RRect.fromRectAndRadius(bounds, Radius.circular(bounds.shortestSide * 0.18));
        canvas.save();
        canvas.clipPath(path);
        canvas.drawRRect(rr.inflate(2), _fill(shape, bounds));
        canvas.restore();
    }
  }

  /// A sphere's outline under any squash and turn is an ellipse: its axes come from the 2×2
  /// spread of the projected unit axes.
  void _sphere(Canvas canvas, SphereShape shape, vm.Matrix4 m) {
    final centre = _project(m.transformed3(shape.center));
    final l = m.getRotation();
    final r = shape.radius * _s;
    // Columns of L·S, projected (y flipped).
    final cols = [
      for (var i = 0; i < 3; i++)
        () {
          final c = l.getColumn(i) * shape.scale[i];
          return Offset(c.x * r, -c.y * r);
        }(),
    ];
    var a = 0.0, b = 0.0, c = 0.0;
    for (final v in cols) {
      a += v.dx * v.dx;
      b += v.dx * v.dy;
      c += v.dy * v.dy;
    }
    final mid = (a + c) / 2, diff = math.sqrt(math.pow((a - c) / 2, 2) + b * b);
    final major = math.sqrt(math.max(0, mid + diff)), minor = math.sqrt(math.max(0, mid - diff));
    final angle = 0.5 * math.atan2(2 * b, a - c);
    if (major < 0.3) return;
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: major * 2, height: math.max(minor * 2, 0.5));
    // Keep the light coming from the upper left whatever the ellipse's turn.
    final paint = Paint()..isAntiAlias = true;
    final base = shape.color.withValues(alpha: shape.color.a * shape.opacity);
    if (shape.finish == Finish.glow) {
      paint.color = base;
    } else {
      final light = Offset(-0.35, -0.45);
      final rotated = Offset(light.dx * math.cos(-angle) - light.dy * math.sin(-angle),
          light.dx * math.sin(-angle) + light.dy * math.cos(-angle));
      paint.shader = RadialGradient(
        center: Alignment(rotated.dx, rotated.dy),
        radius: 1.05,
        colors: [_shade(base, 0.28), base, _shade(base, -0.3)],
        stops: const [0, 0.55, 1],
      ).createShader(rect);
    }
    canvas.drawOval(rect, paint);
    if (shape.finish == Finish.glossy && major > 3) {
      canvas.rotate(-angle);
      _highlight(canvas, Rect.fromCenter(center: Offset.zero, width: major * 2, height: minor * 2));
    }
    canvas.restore();
  }

  /// A capsule (round ends) or a cylinder / cone (flat ends) between two projected points.
  void _stick(Canvas canvas, Shape3D shape, Offset a, Offset b, double ra, double rb, {bool flat = false}) {
    final dir = b - a;
    final length = dir.distance;
    final n = length < 0.001 ? const Offset(1, 0) : Offset(-dir.dy / length, dir.dx / length);
    final path = Path();
    if (flat) {
      path
        ..moveTo((a + n * ra).dx, (a + n * ra).dy)
        ..lineTo((b + n * rb).dx, (b + n * rb).dy)
        ..lineTo((b - n * rb).dx, (b - n * rb).dy)
        ..lineTo((a - n * ra).dx, (a - n * ra).dy)
        ..close();
      // Round the ends a little, as seen from slightly above.
      // Only a flared end (a skirt's hem) shows its rim.
      if (rb > ra * 1.2 && rb >= 0.5) path.addOval(Rect.fromCenter(center: b, width: rb * 2, height: rb * 0.5));
    } else {
      path.addPath(_capsulePath(a, b, ra), Offset.zero);
    }
    final r = math.max(ra, rb);
    final mid = (a + b) / 2;
    final light = n.dx + n.dy < 0 ? n : -n;
    final paint = Paint()..isAntiAlias = true;
    final base = shape.color.withValues(alpha: shape.color.a * shape.opacity);
    if (shape.finish == Finish.glow) {
      paint.color = base;
    } else {
      paint.shader = ui.Gradient.linear(mid + light * r, mid - light * r,
          [_shade(base, 0.25), base, _shade(base, -0.28)], [0, 0.45, 1]);
    }
    canvas.drawPath(path, paint);
  }

  Path _capsulePath(Offset a, Offset b, double r) {
    final dir = b - a;
    final angle = math.atan2(dir.dy, dir.dx);
    final length = dir.distance;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-r, -r, length + 2 * r, 2 * r), Radius.circular(r)));
    final matrix = Matrix4.identity()
      ..setTranslationRaw(a.dx, a.dy, 0)
      ..rotateZ(angle);
    return path.transform(matrix.storage);
  }

  static List<Offset> _hull(List<Offset> points) {
    final p = [...points]..sort((a, b) => a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy));
    double cross(Offset o, Offset a, Offset b) => (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    final lower = <Offset>[], upper = <Offset>[];
    for (final q in p) {
      while (lower.length >= 2 && cross(lower[lower.length - 2], lower.last, q) <= 0) {
        lower.removeLast();
      }
      lower.add(q);
    }
    for (final q in p.reversed) {
      while (upper.length >= 2 && cross(upper[upper.length - 2], upper.last, q) <= 0) {
        upper.removeLast();
      }
      upper.add(q);
    }
    return [...lower.take(lower.length - 1), ...upper.take(upper.length - 1)];
  }

  @override
  bool shouldRepaint(CharacterPainter old) => true;
}

/// A live character on a clear background. Drag sideways to turn it round; change `cue` to play
/// `animation` again (e.g. a wave each time something is picked in the studio).
class CharacterSceneView extends StatefulWidget {
  const CharacterSceneView({
    super.key,
    required this.appearance,
    this.animation = CharacterAnimation.idle,
    this.cue = 0,
    this.framing = CharacterFraming.fullBody,
    this.allowsTurning = true,
  });

  final AvatarAppearance appearance;
  final CharacterAnimation animation;
  final int cue;
  final CharacterFraming framing;
  final bool allowsTurning;

  @override
  State<CharacterSceneView> createState() => _CharacterSceneViewState();
}

class _CharacterSceneViewState extends State<CharacterSceneView> with SingleTickerProviderStateMixin {
  late CharacterRig _rig = CharacterModel.build(widget.appearance);
  late CharacterAnimation _playing = widget.animation;
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_tick);
  Duration _start = Duration.zero;
  Duration _now = Duration.zero;
  double _yaw = 0;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void didUpdateWidget(CharacterSceneView old) {
    super.didUpdateWidget(old);
    if (old.appearance != widget.appearance) {
      _rig = CharacterModel.build(widget.appearance);
      _play(widget.animation);
    } else if (old.cue != widget.cue || old.animation != widget.animation) {
      _play(widget.animation);
    }
  }

  void _play(CharacterAnimation animation) {
    _playing = animation;
    _start = _now;
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    var t = (elapsed - _start).inMicroseconds / 1e6;
    if (!_playing.loops && t > _playing.duration) {
      _play(CharacterAnimation.idle);
      t = 0;
    }
    poseCharacter(_rig, _playing, t);
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paint = RepaintBoundary(
      child: CustomPaint(
        painter: _LivePainter(this),
        size: Size.infinite,
      ),
    );
    if (!widget.allowsTurning) return IgnorePointer(child: paint);
    return GestureDetector(
      onHorizontalDragUpdate: (d) => _yaw += d.delta.dx * 0.012,
      child: paint,
    );
  }
}

class _LivePainter extends CustomPainter {
  _LivePainter(this.state) : super(repaint: state._frame);
  final _CharacterSceneViewState state;

  @override
  void paint(Canvas canvas, Size size) =>
      CharacterPainter(state._rig, yaw: state._yaw, framing: state.widget.framing).paint(canvas, size);

  @override
  bool shouldRepaint(_LivePainter old) => true;
}

/// The child's character as a flat picture (head and shoulders), for results, rewards, map
/// markers and the Parent Zone. Rendered once when the character is saved, then cached.
class CharacterPortrait {
  static Future<Uint8List?> render(AvatarAppearance look, {double size = 512}) async {
    try {
      final rig = CharacterModel.build(look);
      poseCharacter(rig, CharacterAnimation.idle, 0);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      CharacterPainter(rig, framing: CharacterFraming.portrait, shadow: false).paint(canvas, Size(size, size));
      final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
