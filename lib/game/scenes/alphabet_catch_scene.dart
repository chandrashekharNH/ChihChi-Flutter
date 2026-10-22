import 'dart:math' as math;
import 'dart:ui';

import '../../domain/models/game_engagement.dart';
import '../../domain/models/level_configuration.dart';
import '../../features/common/wrong_catch_card.dart';
import '../engine/bubble.dart';
import '../engine/chihchi_sprite.dart';
import '../engine/draw.dart';
import '../engine/game_scene.dart';
import '../engine/living_backdrop.dart';

/// One bubble to spawn in a Catch Letter question.
class CatchItem {
  const CatchItem({
    required this.id,
    required this.caption,
    required this.emoji,
    required this.isTarget,
    required this.scale,
    this.style = BubbleStyle.standard,
    this.label = const WrongCatchLabel('', ''),
  });

  final String id;
  final String caption;
  final String emoji;
  final bool isTarget;
  final double scale;
  final BubbleStyle style;

  /// How the item is named when the child catches it by mistake (or it is the one they missed).
  final WrongCatchLabel label;
}

class CatchConfig {
  const CatchConfig({
    required this.levelConfig,
    required this.items,
    required this.backdrop,
    this.showsHint = false,
    this.barrierEmojis = const [],
    this.barrierCount = 0,
    this.barrierCrossingTime = 8,
  });

  final LevelConfiguration levelConfig;
  final List<CatchItem> items;
  final BackdropStyle backdrop;

  /// Highlight the target with a glowing ring and pointing hand (first-failure tutorial).
  final bool showsHint;

  /// Big emojis that drift in front of the bubbles and partly hide them. Taps pass through.
  final List<String> barrierEmojis;
  final int barrierCount;
  final double barrierCrossingTime;
}

class _Barrier {
  _Barrier(this.emoji, this.size, this.y, this.startsLeft, this.crossing, this.phase);
  final String emoji;
  final double size, y, crossing, phase;
  final bool startsLeft;
  double age = 0;
}

/// Bubbles drift around the screen; the child taps the one asked for. ChihChi stands bottom-left
/// and reacts to every catch.
class AlphabetCatchScene extends GameScene {
  void Function(String id, bool isCorrect)? onObjectCaught;
  void Function()? onRoundExpired;

  CatchConfig? _config;
  final List<Bubble> _bubbles = [];
  final List<Burst> _bursts = [];
  final List<_Barrier> _barriers = [];
  bool _interaction = false;
  bool _caughtThisRound = false;
  int _roundToken = 0;
  LivingBackdrop? _backdrop;
  final chihchi = ChihChiSprite(size: 64);
  final _random = math.Random();

  @override
  void resize(Size newSize) {
    _backdrop?.layout(newSize);
    chihchi.position = Offset(58, newSize.height - 150);
  }

  void configure(CatchConfig config) {
    _config = config;
    resetRound();
    if (_backdrop == null) {
      _backdrop = LivingBackdrop(config.backdrop);
    } else if (_backdrop!.style != config.backdrop) {
      _backdrop!.style = config.backdrop;
    }
    _backdrop!.animates = !reduceMotion;
    if (size != Size.zero) _backdrop!.layout(size);
  }

  void resetRound() {
    _roundToken++;
    _bubbles.clear();
    _barriers.clear();
    _caughtThisRound = false;
    _interaction = false;
  }

  void startRound() {
    final config = _config;
    if (config == null) return;
    _caughtThisRound = false;
    _interaction = true;
    final token = _roundToken;
    var delay = 0.08;
    for (final item in [...config.items]..shuffle(_random)) {
      timeline.after(delay, () {
        if (token != _roundToken || _caughtThisRound) return;
        final bubble = Bubble(
          id: item.id,
          emoji: item.emoji,
          caption: item.caption,
          isTarget: item.isTarget,
          scale: item.scale,
          style: item.style,
        );
        _launch(bubble, config);
        if (item.isTarget && config.showsHint) {
          bubble.showsHint = true;
          bubble.velocity *= 0.45;
        }
      });
      delay += 0.14;
    }
    // No barriers during the retry demonstration, so the highlighted target stays visible.
    if (!config.showsHint) _addBarriers(config);
  }

  void pauseRound() => isPaused = true;
  void resumeRound() => isPaused = false;

  /// Bubbles and barriers all drift slowly for as long as this is on.
  void setSlowMotion(bool on) => timeScale = on ? PlayBoost.slowMotionFactor : 1;

  void resetChihChi() => chihchi.setExpression(ChihChiExpression.neutral);

  void _launch(Bubble bubble, CatchConfig config) {
    const m = 60.0;
    final edge = _random.nextInt(4);
    final perp = -0.45 + _random.nextDouble() * 0.9;
    final norm = math.sqrt(math.max(0, 1 - perp * perp));
    final speed = config.levelConfig.fallSpeed * (bubble.isTarget ? 1.3 : 1.65);
    switch (edge) {
      case 0: // top
        bubble.position = Offset(m + _random.nextDouble() * (size.width - 2 * m), -55);
        bubble.velocity = Offset(perp * speed, norm * speed);
      case 1: // bottom
        bubble.position = Offset(m + _random.nextDouble() * (size.width - 2 * m), size.height + 55);
        bubble.velocity = Offset(perp * speed, -norm * speed);
      case 2: // left
        bubble.position = Offset(-55, m + _random.nextDouble() * (size.height - 2 * m));
        bubble.velocity = Offset(norm * speed, perp * speed);
      default: // right
        bubble.position = Offset(size.width + 55, m + _random.nextDouble() * (size.height - 2 * m));
        bubble.velocity = Offset(-norm * speed, perp * speed);
    }
    bubble.nextDirectionChange = 0.7 + _random.nextDouble() * 1.1;
    bubble.lifetime = 9 + _random.nextDouble() * 3;
    _bubbles.add(bubble);
  }

  @override
  void update(double dt) {
    chihchi.update(dt);
    for (final b in _bursts) {
      b.update(dt);
    }
    _bursts.removeWhere((b) => b.isDone);
    for (final b in _barriers) {
      b.age += dt;
    }
    const xMin = 50.0, yMin = 50.0;
    final xMax = size.width - 50, yMax = size.height - 50;
    for (final node in List.of(_bubbles)) {
      node.update(dt);
      if (node.state == BubbleState.gone) {
        _bubbles.remove(node);
        continue;
      }
      if (!node.isActive) continue;
      // Lifetime: a target that floats away ends the round.
      node.lifetime -= dt;
      if (node.lifetime <= 0) {
        node.fadeOut();
        if (!_caughtThisRound && node.isTarget) onRoundExpired?.call();
        continue;
      }
      var p = node.position + node.velocity * dt;
      var v = node.velocity;
      // Bounce off all four walls.
      if (p.dx < xMin && v.dx < 0) {
        p = Offset(xMin, p.dy);
        v = Offset(-v.dx, v.dy);
      } else if (p.dx > xMax && v.dx > 0) {
        p = Offset(xMax, p.dy);
        v = Offset(-v.dx, v.dy);
      }
      if (p.dy < yMin && v.dy < 0) {
        p = Offset(p.dx, yMin);
        v = Offset(v.dx, -v.dy);
      } else if (p.dy > yMax && v.dy > 0) {
        p = Offset(p.dx, yMax);
        v = Offset(v.dx, -v.dy);
      }
      // Random direction change.
      node.nextDirectionChange -= dt;
      if (node.nextDirectionChange <= 0) {
        final speed = v.distance;
        final a = _random.nextDouble() * 2 * math.pi;
        v = Offset(math.cos(a) * speed, math.sin(a) * speed);
        node.nextDirectionChange = 0.9 + _random.nextDouble() * 1.6;
      }
      node.position = p;
      node.velocity = v;
    }
    // Object-to-object elastic collision (fine for a dozen bubbles).
    final active = _bubbles.where((b) => b.isActive).toList();
    for (var i = 0; i < active.length; i++) {
      for (var j = i + 1; j < active.length; j++) {
        final a = active[i], b = active[j];
        final d = b.position - a.position;
        final distSq = d.dx * d.dx + d.dy * d.dy;
        final minDist = a.radius + b.radius;
        if (distSq >= minDist * minDist || distSq < 0.001) continue;
        final dist = math.sqrt(distSq);
        final n = d / dist;
        final rel = (a.velocity.dx - b.velocity.dx) * n.dx + (a.velocity.dy - b.velocity.dy) * n.dy;
        if (rel <= 0) continue;
        a.velocity -= n * rel;
        b.velocity += n * rel;
        final push = (minDist - dist) * 0.5 + 1;
        a.position -= n * push;
        b.position += n * push;
      }
    }
  }

  @override
  void tapDown(Offset position) {
    if (!_interaction || _caughtThisRound || isPaused) return;
    // The top-most bubble under the finger (barriers are see-through to taps).
    for (final node in _bubbles.reversed) {
      if (node.isActive && node.contains(position)) {
        _handleCatch(node);
        return;
      }
    }
  }

  void _handleCatch(Bubble node) {
    _caughtThisRound = true;
    _interaction = false;
    final correct = node.isTarget;
    // After a wrong catch the right answer stays and lights up, so the child sees what to look for.
    if (!correct) {
      final target = _bubbles.where((b) => b.isActive && b.isTarget).firstOrNull;
      if (target != null) _reveal(target);
    }
    for (final other in _bubbles) {
      if (other != node && other.isActive && !other.showsHint) other.fadeOut();
    }
    final id = node.id;
    node.catchAnimation(correct: correct, onDone: () => onObjectCaught?.call(id, correct));
    chihchi.reach(node.position);
    if (correct) {
      _bursts.add(Burst(node.position));
      chihchi.celebrate();
    } else {
      chihchi.confusedShake();
    }
  }

  /// Stops the missed target somewhere fully on screen and highlights it until the round resets.
  void _reveal(Bubble target) {
    target.velocity = Offset.zero;
    target.lifetime = double.infinity;
    target.showsHint = true;
    const inset = 90.0;
    final from = target.position;
    final spot = Offset(from.dx.clamp(inset, size.width - inset), from.dy.clamp(inset, size.height - inset));
    timeline.tween(0.3, (t) => target.position = Offset.lerp(from, spot, t)!, curve: easeOut);
    // Frozen in place: nothing else moves it.
    target.nextDirectionChange = double.infinity;
  }

  void _addBarriers(CatchConfig config) {
    if (config.barrierCount <= 0 || config.barrierEmojis.isEmpty) return;
    final top = 110.0;
    final bottom = math.max(top + 1, size.height - 170);
    final band = (bottom - top) / config.barrierCount;
    final emojis = [...config.barrierEmojis]..shuffle(_random);
    for (var i = 0; i < config.barrierCount; i++) {
      _barriers.add(_Barrier(
        emojis[i % emojis.length],
        90 + _random.nextDouble() * 35,
        top + band * (i + 0.3 + _random.nextDouble() * 0.4),
        i.isEven,
        config.barrierCrossingTime * (0.85 + _random.nextDouble() * 0.3),
        _random.nextDouble(),
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    _backdrop?.render(canvas, time);
    chihchi.render(canvas);
    for (final b in _bubbles) {
      b.render(canvas);
    }
    // Barriers drift in front of the bubbles, back and forth across the play area.
    for (final b in _barriers) {
      final left = -40.0, right = size.width + 40;
      final cycle = (b.age / b.crossing) % 2;
      final k = easeInOut(cycle < 1 ? cycle : 2 - cycle);
      final x = b.startsLeft ? left + (right - left) * k : right - (right - left) * k;
      final bob = -18 * (0.5 - 0.5 * math.cos(b.age * math.pi / 1.4));
      Draw.text(canvas, b.emoji, Offset(x, b.y + bob), b.size, opacity: math.min(0.95, b.age / 0.4 * 0.95));
    }
    for (final b in _bursts) {
      b.render(canvas);
    }
  }
}
