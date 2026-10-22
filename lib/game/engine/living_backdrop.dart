import 'dart:math' as math;
import 'dart:ui';

import '../../domain/models/world_theme.dart';
import 'draw.dart';

enum BackdropSetting { meadow, city, night, underwater }

class BackdropStyle {
  const BackdropStyle({required this.color, required this.setting, required this.floaters});

  /// The world's colour; the sky and hills are shades of it.
  final Color color;
  final BackdropSetting setting;

  /// The world's own emojis, floating faintly in the background.
  final List<String> floaters;

  /// The living world for one of the child's chosen worlds.
  static BackdropStyle world(WorldTheme theme) => BackdropStyle(
        color: theme.sceneBGColor,
        setting: switch (theme.id) {
          WorldID.spaceWorld => BackdropSetting.night,
          WorldID.oceanWorld => BackdropSetting.underwater,
          _ => BackdropSetting.meadow,
        },
        floaters: theme.ambientEmojis,
      );

  @override
  bool operator ==(Object other) =>
      other is BackdropStyle && other.color == color && other.setting == setting && '${other.floaters}' == '$floaters';
  @override
  int get hashCode => Object.hash(color, setting, '$floaters');
}

class _Star {
  _Star(this.position, this.radius, this.speed, this.phase);
  final Offset position;
  final double radius, speed, phase;
}

/// A calm, slowly moving world behind the catch games: a sky in the world's colour, rolling hills,
/// drifting clouds (or twinkling stars, or rising bubbles), swaying plants and a few floating
/// friends. Everything is muted and slow so the objects being caught stay the focus. Everything
/// is worked out from the clock, so it needs no per-frame state.
class LivingBackdrop {
  LivingBackdrop(this.style, {this.animates = true});

  BackdropStyle style;
  bool animates;
  Size _size = Size.zero;
  final _random = math.Random(11);
  List<_Star> _stars = [];
  List<_Star> _bubbles = [];
  List<double> _cloudStarts = [];
  List<(Offset, double, double, double)> _floaters = [];

  void layout(Size size) {
    if (size == _size) return;
    _size = size;
    _stars = [
      for (var i = 0; i < 14; i++)
        _Star(Offset(_random.nextDouble() * size.width, size.height * (0.05 + _random.nextDouble() * 0.7)),
            1 + _random.nextDouble() * 1.2, 1.5 + _random.nextDouble() * 1.5, _random.nextDouble() * 6),
    ];
    _bubbles = [
      for (var i = 0; i < 7; i++)
        _Star(Offset(_random.nextDouble() * size.width, _random.nextDouble() * size.height), 3 + _random.nextDouble() * 4,
            18 + _random.nextDouble() * 12, _random.nextDouble()),
    ];
    _cloudStarts = [for (var i = 0; i < 3; i++) _random.nextDouble() * size.width];
    _floaters = [
      for (var i = 0; i < 6; i++)
        (
          Offset(0, size.height * (0.2 + _random.nextDouble() * 0.55)),
          24 + _random.nextDouble() * 8,
          -30 + _random.nextDouble() * 60,
          4 + _random.nextDouble() * 2.5,
        ),
    ];
  }

  double get _scale => math.min(1.5, math.max(0.85, _size.width / 390));

  void render(Canvas canvas, double time) {
    final size = _size;
    if (size.width < 2) return;
    final t = animates ? time : 0.0;
    final sc = _scale;
    // Sky: daytime worlds get a soft blue sky over the world's own colour at the horizon; the
    // colours stay deep so white letters and bright bubbles keep their contrast.
    final top = style.setting == BackdropSetting.meadow || style.setting == BackdropSetting.city
        ? Draw.hsv(0.56, 0.5, 0.62)
        : Draw.adjusted(style.color, 0.7);
    final horizon = Draw.adjusted(style.color, 1.3, 0.8);
    canvas.drawRect(
        Offset.zero & size, Paint()..shader = Gradient.linear(Offset.zero, Offset(0, size.height), [top, horizon]));
    // Breathing light.
    final breath = (math.sin(t * 2 * math.pi / 8) + 1) / 2 * 0.06;
    if (breath > 0.002) canvas.drawRect(Offset.zero & size, Draw.fill(Color.fromRGBO(255, 255, 255, breath)));

    switch (style.setting) {
      case BackdropSetting.meadow:
      case BackdropSetting.city:
        _skyLight(canvas, '☀️', t, sc);
        _clouds(canvas, t, sc);
      case BackdropSetting.night:
        for (final s in _stars) {
          final a = 0.15 + 0.7 * (math.sin(t * 2 * math.pi / (2 * s.speed) + s.phase) + 1) / 2;
          canvas.drawCircle(s.position, s.radius, Draw.fill(Color.fromRGBO(255, 255, 255, a)));
        }
        _skyLight(canvas, '🌙', t, sc);
      case BackdropSetting.underwater:
        for (final b in _bubbles) {
          final h = size.height + 20;
          final y = (b.position.dy - t * b.speed) % h;
          final p = Offset(b.position.dx, h - y - 10);
          canvas.drawCircle(p, b.radius, Draw.fill(const Color(0x14FFFFFF)));
          canvas.drawCircle(p, b.radius, Draw.stroke(const Color(0x59FFFFFF), 1));
        }
    }
    _hills(canvas, size);
    _scenery(canvas, t, sc);
    _drawFloaters(canvas, t);
  }

  void _skyLight(Canvas canvas, String emoji, double t, double sc) {
    final pulse = 1 + 0.04 * (1 - math.cos(t * 2 * math.pi / 6));
    Draw.text(canvas, emoji, Offset(_size.width - 56 * sc, _size.height * 0.26), 54 * sc, scale: pulse, opacity: 0.75);
  }

  /// Three clouds at different depths: nearer ones are bigger, brighter and faster (parallax).
  void _clouds(Canvas canvas, double t, double sc) {
    const depths = [(66.0, 0.8, 0.34, 9.0), (48.0, 0.65, 0.42, 6.0), (34.0, 0.5, 0.5, 4.0)];
    for (var i = 0; i < depths.length; i++) {
      final (font, alpha, height, speed) = depths[i];
      final span = _size.width + 160 * sc;
      final x = (_cloudStarts[i] + t * speed) % span - 80 * sc;
      Draw.text(canvas, '☁️', Offset(x, _size.height * height), font * sc, opacity: alpha);
    }
  }

  void _hills(Canvas canvas, Size size) {
    void hill(double height, Color color, double bump) {
      final w = size.width, base = size.height;
      final path = Path()
        ..moveTo(0, base)
        ..lineTo(0, base - height * 0.7)
        ..cubicTo(w * (0.15 + bump), base - height * 1.25, w * (0.32 + bump), base - height * 0.4, w * 0.5, base - height * 0.8)
        ..cubicTo(w * (0.66 + bump), base - height * 1.25, w * 0.86, base - height * 0.5, w, base - height * 0.75)
        ..lineTo(w, base)
        ..close();
      canvas.drawPath(path, Draw.fill(color));
    }

    hill(size.height * 0.17, Draw.adjusted(style.color, 0.62), 0.05);
    hill(size.height * 0.11, Draw.adjusted(style.color, 0.45), -0.06);
  }

  /// Plants (or buildings) standing along the ground, at the edges so the middle stays clear.
  void _scenery(Canvas canvas, double t, double sc) {
    final items = switch (style.setting) {
      BackdropSetting.meadow => [
          ('🌳', 0.05, 46.0, true), ('🌿', 0.3, 26.0, true), ('🌸', 0.44, 22.0, true),
          ('🌼', 0.6, 22.0, true), ('🌷', 0.76, 24.0, true), ('🌳', 0.94, 56.0, true),
        ],
      BackdropSetting.city => [('🏢', 0.06, 48.0, false), ('🌳', 0.3, 30.0, true), ('🚦', 0.72, 28.0, false), ('🏠', 0.92, 44.0, false)],
      BackdropSetting.night => [('🪨', 0.22, 24.0, false), ('🪨', 0.8, 20.0, false)],
      BackdropSetting.underwater => [('🌿', 0.06, 48.0, true), ('🪸', 0.3, 30.0, true), ('🐚', 0.66, 22.0, false), ('🌿', 0.93, 44.0, true)],
    };
    for (var i = 0; i < items.length; i++) {
      final (emoji, x, font, sways) = items[i];
      final f = font * sc;
      final ground = _size.height * 0.93;
      final tilt = sways ? 0.05 * math.sin(t * 2 * math.pi / (5.2 + i * 0.4) + i) : 0.0;
      canvas.save();
      canvas.translate(_size.width * x, ground);
      canvas.rotate(tilt);
      Draw.text(canvas, emoji, Offset(0, -f / 2), f, opacity: 0.85);
      canvas.restore();
    }
  }

  /// The world's emojis plus a setting friend (butterfly, leaf, fish...), wandering slowly.
  void _drawFloaters(Canvas canvas, double t) {
    final extras = switch (style.setting) {
      BackdropSetting.meadow => ['🦋', '🍃'],
      BackdropSetting.city => ['🎈'],
      BackdropSetting.night => ['✨'],
      BackdropSetting.underwater => ['🐠'],
    };
    // City emojis are buildings and signals, which would look odd floating in the sky.
    final own = style.setting == BackdropSetting.city ? <String>[] : style.floaters.take(3).toList();
    final emojis = [...own, ...extras];
    for (var i = 0; i < emojis.length && i < _floaters.length; i++) {
      final (base, font, dx, duration) = _floaters[i];
      final k = (1 - math.cos(t * math.pi / duration)) / 2;
      final column = (i + 0.5) / emojis.length;
      final p = Offset(_size.width * column + dx * k, base.dy - 18 * k);
      Draw.text(canvas, emojis[i], p, font * _scale, opacity: 0.28);
    }
  }
}
