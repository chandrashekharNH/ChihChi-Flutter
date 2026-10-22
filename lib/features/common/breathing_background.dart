import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app's multi-colour background: soft rainbow colours that slowly drift and "breathe"
/// (gently brighten and dim). Still when the system asks for reduced motion.
class BreathingBackground extends StatefulWidget {
  const BreathingBackground({super.key, this.cycle = 40});

  /// Seconds for the colours to travel once around the rainbow.
  final double cycle;

  @override
  State<BreathingBackground> createState() => _BreathingBackgroundState();
}

class _BreathingBackgroundState extends State<BreathingBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(hours: 1))..forward();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    if (still) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.forward();
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final time = still ? 0.0 : _clock.value * 3600;
          return CustomPaint(painter: _MeshPainter(time, widget.cycle), size: Size.infinite);
        },
      ),
    );
  }
}

/// A 3×3 "mesh" of colours approximated with overlapping soft radial blobs.
class _MeshPainter extends CustomPainter {
  _MeshPainter(this.time, this.cycle);
  final double time;
  final double cycle;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = time / cycle;
    final breath = (math.sin(time * 2 * math.pi / 6) + 1) / 2;
    Color colour(int index) {
      final hue = ((phase + index * 0.09) % 1) * 360;
      return HSVColor.fromAHSV(1, hue, 0.62, 0.8 + 0.12 * breath).toColor();
    }

    double sway(double speed, double offset) => math.sin(time * speed + offset) * 0.08;
    final points = <Offset>[
      const Offset(0, 0), const Offset(0.5, 0), const Offset(1, 0),
      const Offset(0, 0.5), Offset(0.5 + sway(0.35, 0), 0.5 + sway(0.28, 1.3)), const Offset(1, 0.5),
      const Offset(0, 1), const Offset(0.5, 1), const Offset(1, 1),
    ];
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = colour(4));
    final radius = math.max(size.width, size.height) * 0.62;
    for (var i = 0; i < 9; i++) {
      if (i == 4) continue;
      final centre = Offset(points[i].dx * size.width, points[i].dy * size.height);
      final c = colour(i);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(colors: [c, c.withValues(alpha: 0)], stops: const [0.0, 1.0])
              .createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }
    final middle = Offset(points[4].dx * size.width, points[4].dy * size.height);
    final c4 = colour(4);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(colors: [c4, c4.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: middle, radius: radius * 0.6)),
    );
    // Keeps white text readable on light colours.
    canvas.drawRect(rect, Paint()..color = Colors.black.withValues(alpha: 0.08));
  }

  @override
  bool shouldRepaint(_MeshPainter old) => old.time != time;
}
