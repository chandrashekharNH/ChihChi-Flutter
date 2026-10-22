import 'dart:math' as math;
import 'dart:ui';

import 'draw.dart';
import 'game_scene.dart';

/// A thing drawn in a scene: an emoji or text label, or a custom painter. Position is its centre.
class Sprite {
  Sprite({
    this.text = '',
    this.position = Offset.zero,
    this.fontSize = 32,
    this.color = const Color(0xFFFFFFFF),
    this.z = 0,
    this.painter,
    this.anchorBottom = false,
  });

  String text;
  Offset position;
  double fontSize;
  Color color;
  double z;
  double scale = 1;
  double scaleX = 1;
  double scaleY = 1;
  double rotation = 0;
  double opacity = 1;
  bool removed = false;

  /// Draws from the bottom centre (trees, buildings growing up out of the ground).
  bool anchorBottom;

  /// Custom drawing, centred on the origin, instead of text.
  void Function(Canvas canvas, Sprite sprite)? painter;

  /// Behaviours that run every frame while the sprite is alive.
  final List<void Function(Sprite s, double dt, double t)> _loops = [];
  double _age = 0;

  void loop(void Function(Sprite s, double dt, double age) behaviour) => _loops.add(behaviour);

  void update(double dt) {
    _age += dt;
    for (final l in _loops) {
      l(this, dt, _age);
    }
  }

  void render(Canvas canvas) {
    if (removed || opacity <= 0.01) return;
    canvas.save();
    canvas.translate(position.dx, position.dy);
    if (rotation != 0) canvas.rotate(rotation);
    final sx = scale * scaleX, sy = scale * scaleY;
    if (anchorBottom) {
      canvas.scale(sx, sy);
      canvas.translate(0, -fontSize / 2);
    } else {
      canvas.scale(sx, sy);
    }
    if (painter != null) {
      if (opacity < 1) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
      painter!(canvas, this);
      if (opacity < 1) canvas.restore();
    } else {
      Draw.text(canvas, text, Offset.zero, fontSize, color: color, opacity: opacity);
    }
    canvas.restore();
  }
}

/// Keeps a scene's sprites, sorted by depth, with handy one-line animations.
class SpriteLayer {
  SpriteLayer(this.timeline);
  final Timeline timeline;
  final List<Sprite> sprites = [];
  final _random = math.Random();

  Sprite add(Sprite s) {
    sprites.add(s);
    return s;
  }

  void clear() => sprites.clear();

  void update(double dt) {
    for (final s in List.of(sprites)) {
      s.update(dt);
    }
    sprites.removeWhere((s) => s.removed);
  }

  void render(Canvas canvas, {double? maxZ, double? minZ}) {
    final ordered = [...sprites]..sort((a, b) => a.z.compareTo(b.z));
    for (final s in ordered) {
      if (maxZ != null && s.z > maxZ) continue;
      if (minZ != null && s.z <= minZ) continue;
      s.render(canvas);
    }
  }

  // Animations

  void moveTo(Sprite s, Offset to, double duration, {double Function(double) curve = easeInOut, double delay = 0, void Function()? onDone}) {
    late Offset from;
    var started = false;
    timeline.tween(duration, (t) {
      if (!started) {
        from = s.position;
        started = true;
      }
      s.position = Offset.lerp(from, to, t)!;
    }, curve: curve, delay: delay, onDone: onDone);
  }

  void scaleTo(Sprite s, double to, double duration, {double delay = 0, double Function(double) curve = easeInOut, void Function()? onDone}) {
    late double from;
    var started = false;
    timeline.tween(duration, (t) {
      if (!started) {
        from = s.scale;
        started = true;
      }
      s.scale = from + (to - from) * t;
    }, curve: curve, delay: delay, onDone: onDone);
  }

  void fadeTo(Sprite s, double to, double duration, {double delay = 0, void Function()? onDone}) {
    late double from;
    var started = false;
    timeline.tween(duration, (t) {
      if (!started) {
        from = s.opacity;
        started = true;
      }
      s.opacity = from + (to - from) * t;
    }, curve: (x) => x, delay: delay, onDone: onDone);
  }

  void fadeOutAndRemove(Sprite s, double duration, {double delay = 0}) =>
      fadeTo(s, 0, duration, delay: delay, onDone: () => s.removed = true);

  /// Pops in from tiny to a little big and back to normal.
  void popIn(Sprite s, {double delay = 0}) {
    s.scale = 0.01;
    scaleTo(s, 1.2, 0.2, delay: delay, onDone: () => scaleTo(s, 1.0, 0.12));
  }

  /// Gently sways the sprite's angle back and forth for ever.
  void wiggle(Sprite s, {double amount = 0.15, double period = 0.6}) =>
      s.loop((sp, dt, age) => sp.rotation = amount * math.sin(age * 2 * math.pi / period));

  /// Bobs up and down around its current point for ever.
  void bob(Sprite s, {double height = 14, double period = 1.6}) {
    var base = s.position;
    var last = 0.0;
    s.loop((sp, dt, age) {
      // Follow any other movement of the sprite.
      final offset = -height * (0.5 - 0.5 * math.cos(age * 2 * math.pi / period));
      base = sp.position - Offset(0, last);
      sp.position = base + Offset(0, offset);
      last = offset;
    });
  }

  /// Emojis bursting out from a point.
  void sparkleBurst(Offset point, int count, {List<String> emojis = const ['✨', '⭐', '🌟'], double z = 25}) {
    for (var i = 0; i < count; i++) {
      final spark = add(Sprite(
        text: emojis[_random.nextInt(emojis.length)],
        position: point,
        fontSize: 14 + _random.nextDouble() * 10,
        z: z,
      ));
      final angle = i / count * 2 * math.pi;
      final distance = 50 + _random.nextDouble() * 40;
      final to = point + Offset(math.cos(angle) * distance, math.sin(angle) * distance);
      moveTo(spark, to, 0.5, curve: easeOut);
      scaleTo(spark, 0.3, 0.5);
      fadeOutAndRemove(spark, 0.5);
    }
  }
}
