import 'dart:math' as math;
import 'dart:ui';

import '../../domain/models/game_engagement.dart';
import '../../features/ar_explorer/ar_hunt_content.dart';
import '../engine/bubble.dart';
import '../engine/draw.dart';
import '../engine/game_scene.dart';
import '../engine/living_backdrop.dart';

class _Barrier {
  _Barrier(this.emoji, this.size, this.y, this.startsLeft, this.crossing);
  final String emoji;
  final double size, y, crossing;
  final bool startsLeft;
  double age = 0;
}

/// Catch World: pictures of things drift down and bounce around; the child taps the one named.
/// A picture that falls out of the bottom is gone; when all are gone the round is over.
class WordHuntScene extends GameScene {
  void Function(String id, bool correct)? onObjectTapped;
  void Function()? onRoundExpired;

  static const _topSafe = 150.0, _bottomSafe = 80.0;

  List<ARHuntObject> _objects = [];
  String _targetID = '';
  double _fallSpeed = 150;
  int _barrierCount = 0;
  double _barrierCrossing = 8;
  bool _roundActive = false;
  bool _answered = false;
  final List<Bubble> _nodes = [];
  final List<Bubble> _leaving = [];
  final List<_Barrier> _barriers = [];
  final List<Burst> _bursts = [];
  LivingBackdrop? _backdrop;
  Bubble? _highlighted;
  final _random = math.Random();

  void setBackdrop(BackdropStyle style) {
    if (_backdrop == null) {
      _backdrop = LivingBackdrop(style);
    } else {
      _backdrop!.style = style;
    }
    if (size != Size.zero) _backdrop!.layout(size);
  }

  @override
  void resize(Size newSize) => _backdrop?.layout(newSize);

  void configure({
    required List<ARHuntObject> objects,
    required String targetID,
    required double fallSpeed,
    int barrierCount = 0,
    double barrierCrossingTime = 8,
  }) {
    _objects = objects;
    _targetID = targetID;
    _fallSpeed = fallSpeed;
    _barrierCount = barrierCount;
    _barrierCrossing = barrierCrossingTime;
    _clear();
    _roundActive = false;
    _answered = false;
  }

  void startRound() {
    _clear();
    _answered = false;
    _roundActive = true;
    _spawn();
  }

  void resetRound() {
    _clear();
    _roundActive = false;
    _answered = false;
    isPaused = false;
  }

  void pauseRound() {
    _roundActive = false;
    isPaused = true;
  }

  void resumeRound() {
    isPaused = false;
    _roundActive = true;
  }

  /// Pictures and barriers all drift slowly for as long as this is on.
  void setSlowMotion(bool on) => timeScale = on ? PlayBoost.slowMotionFactor : 1;

  void _clear() {
    _nodes.clear();
    _leaving.clear();
    _barriers.clear();
    _highlighted = null;
  }

  double get _objectScale => _objects.length <= 5 ? 1.0 : (_objects.length <= 8 ? 0.95 : 0.85);

  void _spawn() {
    if (_objects.isEmpty) return;
    final usable = math.max(size.width - 30, 100.0);
    final columns = math.min(_objects.length, 4);
    final columnWidth = usable / columns;
    final shuffled = [..._objects]..shuffle(_random);
    for (var i = 0; i < shuffled.length; i++) {
      final o = shuffled[i];
      final node = Bubble(id: o.id, emoji: o.emoji, caption: '', isTarget: o.id == _targetID, scale: _objectScale * 88 / Bubble.nodeSize);
      final column = i % 4;
      final x = 15 + column * columnWidth + columnWidth / 2 + (-18 + _random.nextDouble() * 36);
      node.position = Offset(x, -(i * 70 + _random.nextDouble() * 100));
      // A random direction, at this level's speed (give or take a little).
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = math.max(_fallSpeed, 60) * (0.8 + _random.nextDouble() * 0.35);
      node.velocity = Offset(math.cos(angle) * speed, math.sin(angle) * speed);
      node.nextDirectionChange = 0.8 + _random.nextDouble() * 1.2;
      node.lifetime = double.infinity;
      _nodes.add(node);
    }
    _addBarriers();
  }

  /// Big clouds and balloons that drift across in front of the pictures, more of them and faster
  /// on higher levels. They only hide things: taps go straight through them.
  void _addBarriers() {
    if (_barrierCount <= 0) return;
    final top = _topSafe + 40;
    final bottom = math.max(top + 1, size.height - _bottomSafe - 40);
    final band = (bottom - top) / _barrierCount;
    final emojis = ['☁️', '🎈', '🫧', '🍃', '🪁']..shuffle(_random);
    for (var i = 0; i < _barrierCount; i++) {
      _barriers.add(_Barrier(emojis[i % emojis.length], 90 + _random.nextDouble() * 30, top + band * (i + 0.3 + _random.nextDouble() * 0.4),
          i.isEven, _barrierCrossing * (0.85 + _random.nextDouble() * 0.3)));
    }
  }

  @override
  void tapDown(Offset position) {
    if (!_roundActive || _answered) return;
    Bubble? hit;
    for (final n in _nodes.reversed) {
      if (n.isActive && n.contains(position)) {
        hit = n;
        break;
      }
    }
    if (hit == null) return;
    final correct = hit.id == _targetID;
    _answered = true;
    _roundActive = false;
    for (final n in _nodes) {
      n.velocity = Offset.zero;
    }
    if (!correct) {
      final target = _nodes.where((n) => n.id == _targetID).firstOrNull;
      if (target != null) {
        target.showsHint = true;
        _highlighted = target;
      }
    }
    final id = hit.id;
    if (correct) {
      _bursts.add(Burst(hit.position));
      hit.catchAnimation(correct: true, onDone: () => onObjectTapped?.call(id, true));
    } else {
      // A little shake, then the answer is judged.
      final node = hit;
      final base = node.position;
      timeline.tween(0.15, (t) => node.position = base + Offset(8 * math.sin(t * 2 * math.pi), 0), curve: (x) => x, onDone: () {
        node.position = base;
        onObjectTapped?.call(id, false);
      });
    }
  }

  @override
  void update(double dt) {
    for (final b in _bursts) {
      b.update(dt);
    }
    _bursts.removeWhere((b) => b.isDone);
    for (final b in _barriers) {
      b.age += dt;
    }
    for (final n in _nodes) {
      n.update(dt);
    }
    _nodes.removeWhere((n) => n.state == BubbleState.gone);
    if (!_roundActive) return;
    const left = 0.0;
    final right = size.width;
    const top = _topSafe;
    final bottom = size.height - _bottomSafe;
    for (final node in List.of(_nodes)) {
      if (!node.isActive) continue;
      var p = node.position + node.velocity * dt;
      var v = node.velocity;
      if (p.dx - node.radius < left) {
        p = Offset(left + node.radius, p.dy);
        v = Offset(v.dx.abs(), v.dy);
      } else if (p.dx + node.radius > right) {
        p = Offset(right - node.radius, p.dy);
        v = Offset(-v.dx.abs(), v.dy);
      }
      // Bounce off the top edge.
      if (p.dy - node.radius < top) {
        p = Offset(p.dx, top + node.radius);
        v = Offset(v.dx, v.dy.abs());
      }
      // Fell out of the bottom: gone.
      if (p.dy - node.radius > bottom) {
        _nodes.remove(node);
        if (_nodes.isEmpty) {
          _roundActive = false;
          onRoundExpired?.call();
        }
        continue;
      }
      // Occasionally turn a little.
      node.nextDirectionChange -= dt;
      if (node.nextDirectionChange <= 0) {
        node.nextDirectionChange = 0.8 + _random.nextDouble() * 1.2;
        final speed = v.distance;
        final angle = math.atan2(v.dy, v.dx) + (-math.pi / 4 + _random.nextDouble() * math.pi / 2);
        v = Offset(math.cos(angle) * speed, math.sin(angle) * speed);
      }
      node.position = p;
      node.velocity = v;
    }
  }

  @override
  void render(Canvas canvas) {
    _backdrop?.render(canvas, time);
    for (final n in _nodes) {
      if (n != _highlighted) n.render(canvas);
    }
    if (_highlighted != null) {
      // The right answer glows and pulses so the child sees what to look for.
      final h = _highlighted!;
      final pulse = 1 + 0.12 * (0.5 - 0.5 * math.cos(time * math.pi / 0.45));
      canvas.save();
      canvas.translate(h.position.dx, h.position.dy);
      canvas.scale(pulse);
      canvas.translate(-h.position.dx, -h.position.dy);
      h.render(canvas);
      canvas.restore();
    }
    for (final b in _barriers) {
      final l = -50.0, r = size.width + 50;
      final cycle = (b.age / b.crossing) % 2;
      final k = easeInOut(cycle < 1 ? cycle : 2 - cycle);
      final x = b.startsLeft ? l + (r - l) * k : r - (r - l) * k;
      Draw.text(canvas, b.emoji, Offset(x, b.y), b.size, opacity: math.min(0.95, b.age / 0.4 * 0.95));
    }
    for (final b in _bursts) {
      b.render(canvas);
    }
  }
}
