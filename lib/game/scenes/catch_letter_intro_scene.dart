import 'dart:math' as math;
import 'dart:ui';

import '../../core/ui/palette.dart';
import '../../domain/models/catch_letter_level.dart';
import '../engine/bubble.dart';
import '../engine/chihchi_sprite.dart';
import '../engine/draw.dart';
import '../engine/game_scene.dart';
import '../engine/sprites.dart';

/// Short animated "movie" that opens each Catch Letter world. Depth comes from parallax layers,
/// camera zoom, scaling and particles. The intro view drives the timeline and narration; this
/// scene only animates.
class CatchLetterIntroScene extends GameScene {
  CatchLetterIntroScene(this.batch);

  final CatchLetterBatch batch;
  final chihchi = ChihChiSprite(size: 110);
  late final layer = SpriteLayer(timeline);
  final _random = math.Random();
  double _zoom = 1.25;
  Bubble? _letter;
  Offset _letterBase = Offset.zero;
  bool _letterFloats = false;
  bool _built = false;
  final List<(Sprite, int)> _parallax = [];

  double get groundY => size.height * 0.7;
  Offset get _center => Offset(size.width / 2, size.height / 2);

  @override
  void resize(Size newSize) {
    if (_built) return;
    _built = true;
    _addParallax();
    chihchi.position = Offset(-120, groundY - 55);
  }

  void _addParallax() {
    const layers = [(10, 22.0, 0.25, 40.0), (6, 38.0, 0.45, 20.0)];
    for (var l = 0; l < layers.length; l++) {
      final (count, font, alpha, speed) = layers[l];
      for (var i = 0; i < count; i++) {
        final s = layer.add(Sprite(
          text: batch.ambientEmojis[i % batch.ambientEmojis.length],
          position: Offset(-size.width * 0.2 + _random.nextDouble() * size.width * 1.4, -size.height * 0.1 + _random.nextDouble() * size.height * 0.75),
          fontSize: font,
          z: -10.0 + l,
        )..opacity = alpha);
        final base = s.position;
        s.loop((sp, dt, age) {
          final k = 0.5 - 0.5 * math.cos(age * 2 * math.pi / (speed / 5));
          sp.position = base + Offset(30 * k, -8 * k);
        });
        _parallax.add((s, l));
      }
    }
  }

  Color get _groundColor => switch (batch) {
        CatchLetterBatch.cityAdventure => const Color(0xFF737373),
        CatchLetterBatch.memoryChallenge => rgb(0.3, 0.18, 0.5),
        CatchLetterBatch.chihchiMaster => rgb(0.95, 0.7, 0.25),
        CatchLetterBatch.lettersAndNumbers => rgb(0.3, 0.55, 0.95),
        _ => rgb(0.35, 0.72, 0.3),
      };

  // Beats (called by the intro view's timeline)

  void enterChihChi() {
    final target = Offset(size.width * 0.3, groundY - 55);
    for (var step = 1; step <= 3; step++) {
      final x = -120 + (target.dx + 120) * step / 3;
      timeline.after(0.42 * (step - 1), () => chihchi.hop(Offset(x, target.dy), height: 40, duration: 0.4));
    }
  }

  void lookAround() => chihchi.lookAround();

  /// The camera pulls back to reveal the world, then the world's showcase plays.
  void revealWorld() {
    final from = _zoom;
    timeline.tween(1.2, (t) => _zoom = from + (1 - from) * t);
    _showcase();
  }

  void showTitle(String icon, String title) {
    final at = Offset(size.width / 2, size.height * 0.22);
    var fontSize = 34.0;
    while (Draw.measure(title, fontSize).width > size.width * 0.86 && fontSize > 18) {
      fontSize -= 2;
    }
    final group = layer.add(Sprite(position: at, z: 30)
      ..painter = (canvas, s) {
        Draw.text(canvas, icon, const Offset(0, -40), 64);
        Draw.text(canvas, title, const Offset(2, 3), fontSize, color: const Color(0x59000000));
        Draw.text(canvas, title, Offset.zero, fontSize);
      });
    group.scale = 0.1;
    layer.scaleTo(group, 1.15, 0.3, onDone: () => layer.scaleTo(group, 1, 0.15));
    layer.sparkleBurst(at, 12);
  }

  void celebrate() {
    chihchi.celebrate();
    layer.sparkleBurst(chihchi.position, 14);
  }

  // Batch 1 tutorial beats

  void showFloatingLetter(String symbol) {
    final bubble = Bubble(id: 'intro', emoji: symbol, caption: '', isTarget: true, scale: 1.3, style: BubbleStyle(symbol: symbol));
    _letterBase = Offset(size.width * 0.72, size.height * 0.38);
    bubble.position = _letterBase;
    _letter = bubble;
    _letterFloats = true;
  }

  void noticeLetter() {
    chihchi.setExpression(ChihChiExpression.surprised);
    chihchi.look(1);
  }

  void moveLetter() {
    final b = _letter;
    if (b == null) return;
    _letterFloats = false;
    final start = b.position;
    final end = Offset(size.width * 0.58, groundY - 150);
    final c1 = Offset(size.width * 0.95, size.height * 0.55);
    final c2 = Offset(size.width * 0.4, size.height * 0.5);
    timeline.tween(1.4, (t) {
      final u = 1 - t;
      b.position = start * (u * u * u) + c1 * (3 * u * u * t) + c2 * (3 * u * t * t) + end * (t * t * t);
    });
  }

  void catchLetter() {
    final b = _letter;
    if (b == null) return;
    chihchi.hop(Offset(b.position.dx - 50, groundY - 55), height: 90, duration: 0.5);
    timeline.after(0.45, () {
      layer.sparkleBurst(b.position, 16);
      b.catchAnimation(correct: true, onDone: () {});
      chihchi.celebrate();
    });
  }

  // World showcases

  Sprite _popIn(String text, Offset at, double size, double delay, {bool wiggle = false}) {
    final s = layer.add(Sprite(text: text, position: at, fontSize: size, z: 5));
    layer.popIn(s, delay: delay);
    timeline.after(delay, () => layer.sparkleBurst(at, 5));
    if (wiggle) layer.wiggle(s);
    return s;
  }

  /// Grows up out of the ground (trees, buildings).
  void _grow(String text, Offset at, double size, double delay) {
    final s = layer.add(Sprite(text: text, position: at + Offset(0, size * 0.6), fontSize: size, z: -2, anchorBottom: true));
    s.scaleY = 0.01;
    timeline.tween(0.5, (t) => s.scaleY = math.max(0.01, t), delay: delay);
  }

  void _showcase() {
    final w = size.width, h = size.height;
    switch (batch) {
      case CatchLetterBatch.firstAdventure:
        _popIn('☀️', Offset(w * 0.18, h * 0.28), 64, 0);
        const flowers = ['🌼', '🌷', '🌸', '🌻'];
        for (var i = 0; i < flowers.length; i++) {
          _popIn(flowers[i], Offset(w * (0.15 + 0.23 * i), groundY - 12), 36, 0.2 + i * 0.15);
        }
      case CatchLetterBatch.lettersAndNumbers:
        final colors = [rgb(1, 0.23, 0.19), rgb(1, 0.58, 0), rgb(1, 0.8, 0), rgb(0.2, 0.78, 0.35), rgb(0.19, 0.69, 0.78)];
        for (var i = 0; i < 5; i++) {
          final angle = math.pi * (0.85 - 0.175 * i);
          final at = Offset(w / 2 + math.cos(angle) * w * 0.38, h * 0.55 - math.sin(angle) * h * 0.2);
          final s = layer.add(Sprite(text: '${i + 1}', position: at, fontSize: 56, color: colors[i], z: 5));
          layer.popIn(s, delay: i * 0.18);
          timeline.after(i * 0.18 + 0.32, () => layer.bob(s, height: 18, period: 0.6));
        }
      case CatchLetterBatch.lettersAndObjects:
        const objects = ['🍎', '⚽', '🎈', '🐱', '🚗'];
        for (var i = 0; i < objects.length; i++) {
          _popIn(objects[i], Offset(w * (0.14 + 0.18 * i), h * (0.45 - 0.06 * (i % 2))), 48, i * 0.18, wiggle: true);
        }
      case CatchLetterBatch.animalWorld:
        for (var i = 0; i < 3; i++) {
          _grow('🌴', Offset(w * [0.1, 0.5, 0.9][i], groundY - 50), 90, i * 0.15);
        }
        const animals = ['🐒', '🦁', '🐘', '🦜'];
        for (var i = 0; i < animals.length; i++) {
          _popIn(animals[i], Offset(w * (0.2 + 0.2 * i), h * 0.48), 50, 0.6 + i * 0.2, wiggle: true);
        }
      case CatchLetterBatch.colorsAndShapes:
        final rainbow = [rgb(1, 0.23, 0.19), rgb(1, 0.58, 0), rgb(1, 0.8, 0), rgb(0.2, 0.78, 0.35), rgb(0, 0.48, 1), rgb(0.69, 0.32, 0.87)];
        for (var i = 0; i < rainbow.length; i++) {
          final radius = w * 0.45 - i * 14;
          final band = layer.add(Sprite(position: Offset(w / 2, h * 0.58), z: -3)
            ..painter = (canvas, s) => canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius), math.pi, math.pi, false,
                Paint()
                  ..color = rainbow[i]
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 14));
          band.scale = 0.01;
          layer.scaleTo(band, 1, 0.5, delay: i * 0.1);
        }
        const shapes = ['🔺', '⭐', '🟣', '🟧'];
        for (var i = 0; i < shapes.length; i++) {
          _popIn(shapes[i], Offset(w * (0.2 + 0.2 * i), h * 0.38), 44, 0.8 + i * 0.15, wiggle: true);
        }
      case CatchLetterBatch.natureWorld:
        _grow('🌳', Offset(w * 0.8, groundY - 60), 120, 0);
        final sun = _popIn('☀️', Offset(w * 0.2, h * 0.4), 60, 0.2);
        layer.moveTo(sun, Offset(w * 0.2, h * 0.15), 2.0, delay: 0.2);
        const flowers = ['🌸', '🌼', '🍄'];
        for (var i = 0; i < flowers.length; i++) {
          _popIn(flowers[i], Offset(w * (0.45 + 0.12 * i), groundY - 12), 34, 0.5 + i * 0.15);
        }
        final butterfly = _popIn('🦋', Offset(w * 0.1, h * 0.5), 40, 0.6);
        final base = butterfly.position;
        butterfly.loop((s, dt, age) {
          final k = 0.5 - 0.5 * math.cos(age * math.pi / 1.2);
          s.position = base + Offset(w * 0.35 * k, -40 * k);
        });
      case CatchLetterBatch.spaceWorld:
        for (var i = 0; i < 16; i++) {
          final star = _popIn(_random.nextBool() ? '✨' : '⭐', Offset(_random.nextDouble() * w, _random.nextDouble() * h * 0.55),
              14 + _random.nextDouble() * 12, _random.nextDouble() * 0.8);
          star.loop((s, dt, age) => s.opacity = 0.3 + 0.7 * (0.5 + 0.5 * math.cos(age * math.pi / 0.6)));
        }
        _popIn('🪐', Offset(w * 0.8, h * 0.3), 64, 0.3);
        _launchRocket();
      case CatchLetterBatch.cityAdventure:
        const buildings = ['🏢', '🏬', '🏙️', '🏫'];
        for (var i = 0; i < buildings.length; i++) {
          _grow(buildings[i], Offset(w * (0.12 + 0.25 * i), groundY - 60), 90, i * 0.15);
        }
        for (var i = 0; i < 2; i++) {
          final car = layer.add(Sprite(text: ['🚗', '🚌'][i], position: Offset(-60, groundY + 25 + i * 40), fontSize: 46, z: 8));
          car.scaleX = -1;
          final start = 0.6 + i * 0.5;
          car.loop((s, dt, age) {
            if (age < start) return;
            final k = ((age - start) / 2.2) % 1;
            s.position = Offset(-60 + (w + 120) * k, s.position.dy);
          });
        }
      case CatchLetterBatch.memoryChallenge:
        for (var i = 0; i < 3; i++) {
          final box = _popIn('🎁', Offset(w * [0.2, 0.5, 0.8][i], h * 0.45), 56, i * 0.25);
          timeline.after(1.2 + i * 0.2, () {
            box.text = '❓';
            layer.sparkleBurst(box.position, 8);
          });
        }
        for (var i = 0; i < 4; i++) {
          final fog = _popIn('☁️', Offset(_random.nextDouble() * w, h * (0.1 + _random.nextDouble() * 0.5)), 60, 0);
          fog.opacity = 0.5;
          final base = fog.position;
          fog.loop((s, dt, age) => s.position = base + Offset(40 * (0.5 - 0.5 * math.cos(age * math.pi / 2)), 0));
        }
      case CatchLetterBatch.chihchiMaster:
        final crown = layer.add(Sprite(text: '👑', position: Offset(chihchi.position.dx, -60), fontSize: 50, z: 20));
        layer.moveTo(crown, chihchi.position + const Offset(0, -60), 0.8, delay: 0.4, onDone: chihchi.celebrate);
        for (var i = 0; i < 5; i++) {
          timeline.after(0.3 + i * 0.35, () {
            final p = Offset(w * (0.15 + _random.nextDouble() * 0.7), h * (0.15 + _random.nextDouble() * 0.35));
            _popIn(_random.nextBool() ? '🎆' : '🎇', p, 60, 0);
            layer.sparkleBurst(p, 10);
          });
        }
    }
  }

  void _launchRocket() {
    final rocket = layer.add(Sprite(text: '🚀', position: Offset(size.width * 0.65, size.height + 40), fontSize: 64, z: 15));
    rocket.rotation = -math.pi / 4;
    var puff = 0.0;
    rocket.loop((s, dt, age) {
      puff += dt;
      if (age > 0.5 && puff > 0.08) {
        puff = 0;
        final p = layer.add(Sprite(text: '💨', position: s.position + const Offset(-10, 40), fontSize: 28, z: 14));
        layer.scaleTo(p, 1.8, 0.6);
        layer.fadeOutAndRemove(p, 0.6);
      }
    });
    layer.moveTo(rocket, Offset(size.width * 0.75, -120), 2.2, curve: easeIn, delay: 0.5, onDone: () => rocket.removed = true);
  }

  @override
  void update(double dt) {
    chihchi.update(dt);
    layer.update(dt);
    final b = _letter;
    if (b != null) {
      if (_letterFloats) b.position = _letterBase + Offset(0, -14 * (0.5 - 0.5 * math.cos(time * math.pi / 0.8)));
      b.update(dt);
      if (b.state == BubbleState.gone) _letter = null;
    }
  }

  @override
  void render(Canvas canvas) {
    final colors = batch.gradient;
    canvas.drawRect(Offset.zero & size,
        Paint()..shader = Gradient.linear(Offset.zero, Offset(0, size.height), colors, [for (var i = 0; i < colors.length; i++) i / math.max(1, colors.length - 1)]));
    canvas.save();
    // Camera zoom around the middle.
    canvas.translate(_center.dx, _center.dy);
    canvas.scale(_zoom);
    canvas.translate(-_center.dx, -_center.dy);
    layer.render(canvas, maxZ: -4);
    if (batch != CatchLetterBatch.spaceWorld) {
      canvas.drawOval(
          Rect.fromCenter(center: Offset(size.width / 2, groundY + size.height * 0.22), width: size.width * 2.2, height: size.height * 0.5),
          Draw.fill(_groundColor));
    }
    layer.render(canvas, minZ: -4, maxZ: 9);
    chihchi.render(canvas);
    _letter?.render(canvas);
    layer.render(canvas, minZ: 9);
    canvas.restore();
  }
}
