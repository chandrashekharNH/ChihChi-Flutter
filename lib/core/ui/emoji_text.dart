import 'package:flutter/widgets.dart';

import '../../game/engine/draw.dart';

/// An emoji (or short label) drawn from a cached picture, so it can be scaled, spun or pulsed
/// without the GPU rasterising a new glyph size every frame. Use it for anything that animates its
/// size; plain `Text` is fine for still text.
class EmojiText extends StatelessWidget {
  const EmojiText(this.text, {super.key, required this.size, this.color = const Color(0xFFFFFFFF), this.weight = FontWeight.w900});
  final String text;
  final double size;
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final measured = Draw.measure(text, size, weight: weight);
    return ExcludeSemantics(
      child: CustomPaint(
        size: measured,
        painter: _EmojiPainter(text, size, color, weight),
      ),
    );
  }
}

class _EmojiPainter extends CustomPainter {
  _EmojiPainter(this.text, this.fontSize, this.color, this.weight);
  final String text;
  final double fontSize;
  final Color color;
  final FontWeight weight;

  @override
  void paint(Canvas canvas, Size size) =>
      Draw.text(canvas, text, size.center(Offset.zero), fontSize, color: color, weight: weight);

  @override
  bool shouldRepaint(_EmojiPainter old) => old.text != text || old.fontSize != fontSize || old.color != color;
}
