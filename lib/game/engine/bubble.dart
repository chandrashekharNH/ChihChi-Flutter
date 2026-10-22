import 'dart:math' as math;
import 'dart:ui';

import '../../domain/models/catch_letter_level.dart';
import '../../domain/models/game_object.dart';
import 'draw.dart';

/// Optional look for Catch Letter bubbles. The default keeps the original emoji bubble.
class BubbleStyle {
  const BubbleStyle({this.symbol, this.badgeEmoji, this.fillColor, this.shape = CatchLetterShape.circle});

  /// Big text (a letter or number) shown instead of the emoji.
  final String? symbol;

  /// Small emoji badge on the bubble's corner (e.g. the animal for its letter).
  final String? badgeEmoji;

  /// Fixed fill colour. Null keeps the rainbow colour cycle.
  final Color? fillColor;
  final CatchLetterShape shape;

  static const standard = BubbleStyle();
}

enum BubbleState { alive, caught, escaping, fading, gone }

/// A floating bubble to catch: an emoji, letter or colour, drifting and bouncing around.
class Bubble {
  Bubble({
    required this.id,
    required this.emoji,
    required this.caption,
    required this.isTarget,
    double scale = 1,
    this.style = BubbleStyle.standard,
    this.category = ObjectCategory.toy,
  }) : radius = nodeSize * scale / 2 {
    final r = math.Random();
    _hue = r.nextDouble();
    _breathHalf = 0.7 + r.nextDouble() * 0.4;
    _breathDelay = r.nextDouble() * _breathHalf * 2;
  }

  static const nodeSize = 90.0;

  final String id;
  final String emoji;
  final String caption;
  final bool isTarget;
  final double radius;
  final BubbleStyle style;
  final ObjectCategory category;

  Offset position = Offset.zero;
  Offset velocity = Offset.zero;
  double nextDirectionChange = 1;
  double lifetime = 10;
  BubbleState state = BubbleState.alive;
  bool showsHint = false;

  double _age = 0;
  double _hue = 0;
  late double _breathHalf, _breathDelay;
  double _opacity = 0;
  double _extraScale = 1;
  double _spin = 0;
  double _flash = 0;
  double _shakeX = 0;
  double _stateTime = 0;
  Offset _escapeDir = Offset.zero;
  VoidCallback? _onDone;

  bool get isActive => state == BubbleState.alive;

  void catchAnimation({required bool correct, required VoidCallback onDone}) {
    state = correct ? BubbleState.caught : BubbleState.escaping;
    _stateTime = 0;
    _onDone = onDone;
    if (!correct) {
      final a = math.Random().nextDouble() * 2 * math.pi;
      _escapeDir = Offset(math.cos(a), math.sin(a));
    }
  }

  void fadeOut() {
    if (state == BubbleState.alive) {
      state = BubbleState.fading;
      _stateTime = 0;
    }
  }

  void update(double dt) {
    _age += dt;
    _stateTime += dt;
    _hue = (_hue + dt / 8) % 1;
    switch (state) {
      case BubbleState.alive:
        _opacity = math.min(1, _opacity + dt * 4);
      case BubbleState.caught:
        // Pop bigger with a yellow flash, then fade.
        final k = math.min(1.0, _stateTime / 0.12);
        _extraScale = 1 + 0.5 * k;
        _flash = 0.8 * k;
        if (_stateTime > 0.12) _opacity = math.max(0, 1 - (_stateTime - 0.12) / 0.2);
        if (_stateTime > 0.32) _finish();
      case BubbleState.escaping:
        // The wrong object wriggles free and zips away — a funny "escape", not a harsh fail.
        if (_stateTime < 0.15) {
          _shakeX = 8 * math.sin(_stateTime / 0.15 * 2 * math.pi);
        } else {
          _shakeX = 0;
          final e = math.min(1.0, (_stateTime - 0.15) / 0.45);
          final eased = e * e;
          position += _escapeDir * (500 * dt / 0.45) * (0.4 + eased);
          _spin = eased * 3 * math.pi;
          _extraScale = 1 - 0.6 * eased;
          _opacity = 1 - eased;
        }
        if (_stateTime > 0.6) _finish();
      case BubbleState.fading:
        _opacity = math.max(0, _opacity - dt / 0.35);
        if (_opacity <= 0) state = BubbleState.gone;
      case BubbleState.gone:
        break;
    }
  }

  void _finish() {
    state = BubbleState.gone;
    final done = _onDone;
    _onDone = null;
    done?.call();
  }

  /// Point inside the bubble (taps forgive a little).
  bool contains(Offset p) => (p - position).distance <= radius * 1.1;

  Color get _fill {
    if (style.fillColor != null) return style.fillColor!;
    return Draw.hsv(_hue, 0.88, 0.95);
  }

  void render(Canvas canvas) {
    if (state == BubbleState.gone || _opacity <= 0.01) return;
    final wobble = 0.05 * math.sin(_age * math.pi / 0.8);
    final b = _age - _breathDelay;
    final breath = b < 0 ? 1.0 : 1 + 0.12 * math.sin(b * math.pi / _breathHalf);
    final r = radius;
    canvas.save();
    canvas.translate(position.dx + _shakeX, position.dy);
    if (showsHint) {
      final pulse = 1 + 0.15 * (0.5 - 0.5 * math.cos(_age * math.pi / 0.45));
      canvas.drawCircle(Offset.zero, (r + 10) * pulse,
          Paint()
            ..color = const Color(0xCCFFEB3B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 6));
    }
    canvas.rotate(wobble + _spin);
    canvas.scale(breath * _extraScale);
    if (_opacity < 1) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, _opacity));

    final path = _shapePath(style.shape, r);
    final fill = _fill;
    canvas.drawPath(
        path,
        Paint()
          ..shader = Gradient.radial(Offset(-r * 0.3, -r * 0.35), r * 1.3,
              [Color.lerp(fill, const Color(0xFFFFFFFF), 0.3)!, fill, Draw.adjusted(fill, 0.8)], [0, 0.55, 1]));
    final strokeColor = style.fillColor != null ? const Color(0xFFFFFFFF) : Draw.hsv(_hue + 0.12, 0.6, 1, 0.85);
    canvas.drawPath(path, Draw.stroke(strokeColor, 4));
    if (_flash > 0) canvas.drawPath(path, Draw.fill(Color.fromRGBO(255, 235, 59, _flash * 0.7)));
    // A soft shine, like a real bubble.
    canvas.drawOval(Rect.fromCenter(center: Offset(-r * 0.35, -r * 0.42), width: r * 0.42, height: r * 0.24),
        Draw.fill(const Color(0x40FFFFFF)));

    final symbol = style.symbol;
    if (symbol != null) {
      final size = r * (symbol.runes.length > 1 ? 0.8 : 1.15);
      final dy = style.shape == CatchLetterShape.triangle ? r * 0.15 : 0.0;
      Draw.text(canvas, symbol, Offset(0, dy), size, color: _textColor(style.fillColor));
    } else if (emoji.isNotEmpty) {
      Draw.text(canvas, emoji, const Offset(0, -2), r * 1.05);
    }
    if (style.badgeEmoji != null) {
      final c = Offset(r * 0.72, -r * 0.72);
      canvas.drawCircle(c, r * 0.36, Draw.fill(const Color(0xFFFFFFFF)));
      canvas.drawCircle(c, r * 0.36, Draw.stroke(const Color(0x26000000), 1));
      Draw.text(canvas, style.badgeEmoji!, c, r * 0.46);
    }
    if (_opacity < 1) canvas.restore();
    canvas.restore();

    if (caption.isNotEmpty) {
      Draw.text(canvas, caption, position + Offset(0, r + 14), 14, opacity: _opacity, shadow: true, weight: FontWeight.w800);
    }
    if (showsHint) {
      final bob = 10 * (0.5 - 0.5 * math.cos(_age * math.pi / 0.35));
      Draw.text(canvas, '👆', position + Offset(0, r + r * 0.9 + 6 - bob), r * 0.9);
    }
  }

  static Path _shapePath(CatchLetterShape shape, double r) {
    switch (shape) {
      case CatchLetterShape.circle:
        return Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
      case CatchLetterShape.square:
        return Path()
          ..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 1.8),
              Radius.circular(r * 0.25)));
      case CatchLetterShape.triangle:
        return Path()
          ..moveTo(0, -r * 1.05)
          ..lineTo(r * 1.05, r * 0.8)
          ..lineTo(-r * 1.05, r * 0.8)
          ..close();
      case CatchLetterShape.star:
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final rr = i.isEven ? r * 1.1 : r * 0.55;
          final a = i * math.pi / 5 - math.pi / 2;
          final p = Offset(math.cos(a) * rr, math.sin(a) * rr);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        return path..close();
    }
  }

  /// Dark text on light fills (e.g. yellow) so letters stay readable.
  static Color _textColor(Color? fill) {
    if (fill == null) return const Color(0xFFFFFFFF);
    final l = 0.299 * fill.r + 0.587 * fill.g + 0.114 * fill.b;
    return l > 0.65 ? const Color(0xFF262626) : const Color(0xFFFFFFFF);
  }
}

/// Little emojis bursting out from a point.
class Burst {
  Burst(this.origin, {this.emojis = const ['✨', '⭐', '🌟', '💫'], int count = 8}) {
    final r = math.Random();
    for (var i = 0; i < count; i++) {
      final a = i * 2 * math.pi / count;
      final d = 60 + r.nextDouble() * 40;
      _parts.add((emojis[i % emojis.length], Offset(math.cos(a) * d, math.sin(a) * d), 18 + r.nextDouble() * 14));
    }
  }

  final Offset origin;
  final List<String> emojis;
  final List<(String, Offset, double)> _parts = [];
  double _t = 0;

  bool get isDone => _t >= 0.5;
  void update(double dt) => _t += dt;

  void render(Canvas canvas) {
    final k = math.min(1.0, _t / 0.5);
    for (final (emoji, to, size) in _parts) {
      Draw.text(canvas, emoji, origin + to * k, size, scale: 1 - 0.8 * k, opacity: math.max(0, 1 - _t / 0.3 * 0.6));
    }
  }
}
