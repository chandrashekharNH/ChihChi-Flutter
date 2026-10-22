import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../core/ui/palette.dart';
import '../../domain/models/puzzle_models.dart';
import 'puzzle_generator.dart';

/// A drawn puzzle picture. `base` is everything except the living elements, which are drawn on top
/// in `full` and animated separately when the puzzle is finished.
class PuzzleArt {
  const PuzzleArt(this.full, this.base, this.elements);
  final ui.Image full;
  final ui.Image base;
  final List<PuzzleSceneElement> elements;
}

class PieceArt {
  const PieceArt(this.face, this.shadow, this.anchor);
  final ui.Image face;
  final ui.Image shadow;

  /// Where the cell's centre sits in the image, in image pixels from the top-left.
  final Offset anchor;
}

/// Draws every puzzle picture in code (backdrop + large emoji art), so the library needs no bundled
/// images.
class PuzzleArtRenderer {
  static const pixelSize = 1024.0;

  static Future<PuzzleArt> render(PuzzleSubject subject, String wordText) async {
    const size = Size(pixelSize, pixelSize);
    final elements = _livingElements(subject);
    final baseRecorder = ui.PictureRecorder();
    final baseCanvas = Canvas(baseRecorder);
    _drawBase(subject, wordText, baseCanvas, size);
    final basePicture = baseRecorder.endRecording();
    final base = await basePicture.toImage(pixelSize.toInt(), pixelSize.toInt());
    final fullRecorder = ui.PictureRecorder();
    final fullCanvas = Canvas(fullRecorder);
    fullCanvas.drawPicture(basePicture);
    for (final e in elements) {
      drawEmoji(fullCanvas, e, size, withShadow: true);
    }
    final full = await fullRecorder.endRecording().toImage(pixelSize.toInt(), pixelSize.toInt());
    return PuzzleArt(full, base, elements);
  }

  /// Cuts `image` into piece images: picture clipped to the outline, a darker edge underneath for
  /// thickness, and a light bevel stroke. Pieces are drawn at most `maxCell` pixels a side.
  static Future<Map<int, PieceArt>> pieceArt(ui.Image image, PuzzleLayout layout, {double maxCell = 260}) async {
    final full = Size(image.width.toDouble(), image.height.toDouble());
    final sourceCell = Size(full.width / layout.grid.columns, full.height / layout.grid.rows);
    // Small grids would make huge piece images; scale them down a little.
    final k = math.min(1.0, maxCell / math.max(sourceCell.width, sourceCell.height));
    final cell = Size(sourceCell.width * k, sourceCell.height * k);
    final margin = PuzzleGenerator.tabSize(cell);
    final thickness = math.max(3.0, math.min(cell.width, cell.height) * 0.035);
    final w = (cell.width + margin * 2).ceil(), h = (cell.height + margin * 2 + thickness).ceil();
    final anchor = Offset(margin + cell.width / 2, margin + cell.height / 2);
    final result = <int, PieceArt>{};
    for (final piece in layout.pieces) {
      final outline = PuzzleGenerator.outline(piece, cell, layout.usesJigsawShapes);
      final origin = Offset(piece.column * cell.width - margin, piece.row * cell.height - margin);
      final faceRecorder = ui.PictureRecorder();
      final c = Canvas(faceRecorder);
      // Thickness: the same outline, darker, slightly lower.
      c.save();
      c.translate(0, thickness);
      c.drawPath(outline, Paint()..color = const Color(0x8C2E2E2E));
      c.restore();
      // Picture.
      c.save();
      c.clipPath(outline);
      c.translate(-origin.dx, -origin.dy);
      c.scale(k);
      c.drawImage(image, Offset.zero, Paint()..filterQuality = FilterQuality.medium);
      c.restore();
      // Bevel.
      c.drawPath(
          outline,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0x8CFFFFFF)
            ..strokeWidth = math.max(2, thickness * 0.7));
      c.drawPath(
          outline,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0x2E000000)
            ..strokeWidth = 1);
      final face = await faceRecorder.endRecording().toImage(w, h);
      final shadowRecorder = ui.PictureRecorder();
      Canvas(shadowRecorder).drawPath(outline, Paint()..color = const Color(0xFF000000));
      final shadow = await shadowRecorder.endRecording().toImage(w, h);
      result[piece.id] = PieceArt(face, shadow, anchor);
    }
    return result;
  }

  /// Picture pixels per piece-image pixel (pieces may be drawn smaller than the picture).
  static double pieceScale(ui.Image image, PuzzleLayout layout, {double maxCell = 260}) {
    final cell = math.max(image.width / layout.grid.columns, image.height / layout.grid.rows);
    return math.min(1.0, maxCell / cell);
  }

  // Living elements

  static List<PuzzleSceneElement> _livingElements(PuzzleSubject subject) => switch (subject) {
        ObjectSubject(:final emoji) => [PuzzleSceneElement(emoji, 0.5, 0.5, 0.62)],
        SceneSubject(:final elements) => elements,
        LetterSubject(:final emoji) => [PuzzleSceneElement(emoji, 0.8, 0.8, 0.24)],
        NumberSubject() => const [],
        ColorSubject(:final color) => [PuzzleSceneElement(color.emoji, 0.5, 0.5, 0.36)],
        WordSubject(:final emoji) => [PuzzleSceneElement(emoji, 0.5, 0.36, 0.42)],
        PhotoSubject() => const [],
      };

  // Drawing

  static void _drawBase(PuzzleSubject subject, String wordText, Canvas c, Size size) {
    switch (subject) {
      case ObjectSubject(:final backdrop):
        _backdrop(backdrop, c, size);
        _glow(c, Offset(size.width / 2, size.height / 2), size.width * 0.38);
      case SceneSubject(:final backdrop):
        _backdrop(backdrop, c, size);
      case LetterSubject(:final symbol):
        _brightGradient(symbol, c, size);
        _text(c, symbol, Offset(size.width * 0.46, size.height * 0.44), size.width * 0.52, const Color(0xFFFFFFFF), const Color(0x40000000));
      case NumberSubject(:final value, :final emoji):
        _backdrop(PuzzleBackdrop.sky, c, size);
        final stroke = rgb(0.2, 0.4, 0.8);
        if (value <= 20) {
          _text(c, '$value', Offset(size.width / 2, size.height * 0.2), size.width * 0.26, const Color(0xFFFFFFFF), stroke);
          _count(c, value, emoji, Rect.fromLTWH(size.width * 0.06, size.height * 0.38, size.width * 0.88, size.height * 0.56));
        } else {
          _text(c, '$value', Offset(size.width / 2, size.height * 0.5), size.width * 0.46, const Color(0xFFFFFFFF), stroke);
          for (final (x, y) in [(0.14, 0.14), (0.86, 0.14), (0.14, 0.86), (0.86, 0.86)]) {
            drawEmoji(c, PuzzleSceneElement(emoji, x, y, 0.14), size, withShadow: false);
          }
        }
      case ColorSubject(:final color):
        _backdrop(PuzzleBackdrop.sky, c, size);
        _paintBlob(c, color, size);
      case WordSubject():
        _backdrop(PuzzleBackdrop.indoor, c, size);
        _glow(c, Offset(size.width / 2, size.height * 0.36), size.width * 0.28);
        _wordTiles(c, wordText, size);
      case PhotoSubject(:final image):
        // Fill the square board, cropping the longer side around the centre.
        final iw = image.width.toDouble(), ih = image.height.toDouble();
        final scale = math.max(size.width / math.max(iw, 1), size.height / math.max(ih, 1));
        final dw = iw * scale, dh = ih * scale;
        c.drawImageRect(image, Rect.fromLTWH(0, 0, iw, ih), Rect.fromLTWH((size.width - dw) / 2, (size.height - dh) / 2, dw, dh),
            Paint()..filterQuality = FilterQuality.medium);
    }
  }

  static Color _c(double r, double g, double b, [double a = 1]) => rgb(r, g, b, a);

  static void _gradient(Canvas c, Color top, Color bottom, Rect rect) =>
      c.drawRect(rect, Paint()..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [top, bottom]));

  static void _ellipse(Canvas c, Rect rect, Color fill) => c.drawOval(rect, Paint()..color = fill);

  /// Repeatable sprinkle positions (stars, bubbles) so a picture looks the same each time.
  static List<Offset> _sprinkle(int count, int seed, Rect rect) {
    final r = math.Random(seed);
    return [for (var i = 0; i < count; i++) Offset(rect.left + r.nextDouble() * rect.width, rect.top + r.nextDouble() * rect.height)];
  }

  static void _backdrop(PuzzleBackdrop backdrop, Canvas c, Size size) {
    final w = size.width, h = size.height;
    final all = Offset.zero & size;
    switch (backdrop) {
      case PuzzleBackdrop.meadow:
      case PuzzleBackdrop.farm:
        _gradient(c, _c(0.5, 0.8, 1), _c(0.86, 0.95, 1), all);
        _ellipse(c, Rect.fromLTWH(-w * 0.3, h * 0.55, w * 1.1, h * 0.8), _c(0.5, 0.82, 0.38));
        _ellipse(c, Rect.fromLTWH(w * 0.25, h * 0.6, w * 1.1, h * 0.8), _c(0.42, 0.76, 0.33));
        if (backdrop == PuzzleBackdrop.farm) {
          for (var i = 0; i < 4; i++) {
            c.drawRect(Rect.fromLTWH(0, h * (0.8 + i * 0.05), w, h * 0.018), Paint()..color = _c(0.88, 0.76, 0.38, 0.55));
          }
        }
      case PuzzleBackdrop.jungle:
        _gradient(c, _c(0.45, 0.78, 0.6), _c(0.78, 0.93, 0.72), all);
        for (final p in _sprinkle(14, 7, Rect.fromLTWH(0, 0, w, h * 0.6))) {
          _ellipse(c, Rect.fromLTWH(p.dx - w * 0.12, p.dy - w * 0.08, w * 0.24, w * 0.16), _c(0.25, 0.6, 0.3, 0.35));
        }
        _gradient(c, _c(0.3, 0.62, 0.28), _c(0.2, 0.48, 0.2), Rect.fromLTWH(0, h * 0.7, w, h * 0.3));
      case PuzzleBackdrop.underwater:
        _gradient(c, _c(0.12, 0.6, 0.85), _c(0.03, 0.26, 0.52), all);
        for (var i = 0; i < 4; i++) {
          final x = w * (0.1 + i * 0.25);
          c.drawPath(
              Path()
                ..moveTo(x, 0)
                ..lineTo(x + w * 0.12, 0)
                ..lineTo(x + w * 0.02, h * 0.8)
                ..close(),
              Paint()..color = _c(1, 1, 1, 0.07));
        }
        for (final p in _sprinkle(18, 3, Rect.fromLTWH(0, 0, w, h * 0.8))) {
          c.drawOval(Rect.fromLTWH(p.dx, p.dy, w * 0.022, w * 0.022),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = _c(1, 1, 1, 0.45));
        }
        _gradient(c, _c(0.96, 0.87, 0.62), _c(0.88, 0.76, 0.5), Rect.fromLTWH(0, h * 0.88, w, h * 0.12));
      case PuzzleBackdrop.beach:
        _gradient(c, _c(0.5, 0.8, 1), _c(0.9, 0.97, 1), Rect.fromLTWH(0, 0, w, h * 0.5));
        _gradient(c, _c(0.2, 0.65, 0.9), _c(0.1, 0.5, 0.8), Rect.fromLTWH(0, h * 0.5, w, h * 0.2));
        _ellipse(c, Rect.fromLTWH(-w * 0.2, h * 0.64, w * 1.4, h * 0.7), _c(0.98, 0.88, 0.62));
      case PuzzleBackdrop.space:
      case PuzzleBackdrop.night:
        final isSpace = backdrop == PuzzleBackdrop.space;
        _gradient(c, isSpace ? _c(0.04, 0.03, 0.18) : _c(0.08, 0.1, 0.32), isSpace ? _c(0.14, 0.05, 0.36) : _c(0.22, 0.22, 0.48), all);
        final stars = _sprinkle(70, isSpace ? 11 : 5, all);
        for (var i = 0; i < stars.length; i++) {
          final r = w * (i % 5 == 0 ? 0.006 : 0.003);
          c.drawCircle(stars[i], r, Paint()..color = _c(1, 1, 1, 0.85));
        }
        if (!isSpace) _ellipse(c, Rect.fromLTWH(-w * 0.2, h * 0.78, w * 1.4, h * 0.5), _c(0.1, 0.26, 0.22));
      case PuzzleBackdrop.snow:
        _gradient(c, _c(0.68, 0.84, 1), _c(0.9, 0.95, 1), all);
        _ellipse(c, Rect.fromLTWH(-w * 0.3, h * 0.6, w * 1.2, h * 0.7), _c(0.97, 0.98, 1));
        _ellipse(c, Rect.fromLTWH(w * 0.3, h * 0.66, w * 1.0, h * 0.6), _c(0.93, 0.96, 1));
        for (final p in _sprinkle(30, 9, Rect.fromLTWH(0, 0, w, h * 0.6))) {
          _ellipse(c, Rect.fromLTWH(p.dx, p.dy, w * 0.01, w * 0.01), _c(1, 1, 1, 0.9));
        }
      case PuzzleBackdrop.city:
        _gradient(c, _c(0.55, 0.8, 1), _c(0.95, 0.97, 1), all);
        const heights = [0.3, 0.42, 0.24, 0.36, 0.28, 0.46, 0.32];
        for (var i = 0; i < heights.length; i++) {
          final x = i * w / heights.length;
          c.drawRect(Rect.fromLTWH(x, h * (0.78 - heights[i]), w / heights.length - 6, h * heights[i]), Paint()..color = _c(0.58, 0.64, 0.8, 0.8));
        }
        c.drawRect(Rect.fromLTWH(0, h * 0.72, w, h * 0.28), Paint()..color = _c(0.3, 0.31, 0.36));
        for (var i = 0; i < 6; i++) {
          c.drawRect(Rect.fromLTWH(i * w / 6 + w * 0.03, h * 0.9, w * 0.09, h * 0.012), Paint()..color = _c(1, 1, 1, 0.8));
        }
      case PuzzleBackdrop.desert:
        _gradient(c, _c(1, 0.84, 0.55), _c(1, 0.95, 0.8), all);
        _ellipse(c, Rect.fromLTWH(-w * 0.3, h * 0.58, w * 1.1, h * 0.8), _c(0.97, 0.78, 0.45));
        _ellipse(c, Rect.fromLTWH(w * 0.3, h * 0.64, w * 1.0, h * 0.7), _c(0.93, 0.72, 0.4));
      case PuzzleBackdrop.sky:
        _gradient(c, _c(0.45, 0.75, 1), _c(0.9, 0.96, 1), all);
        for (final p in [Offset(w * 0.2, h * 0.18), Offset(w * 0.75, h * 0.3), Offset(w * 0.35, h * 0.72)]) {
          _ellipse(c, Rect.fromLTWH(p.dx - w * 0.12, p.dy - h * 0.035, w * 0.24, h * 0.07), _c(1, 1, 1, 0.55));
        }
      case PuzzleBackdrop.festival:
        _gradient(c, _c(0.26, 0.08, 0.42), _c(0.58, 0.16, 0.44), all);
        final tints = [_c(1, 0.8, 0.2, 0.28), _c(1, 0.4, 0.6, 0.25), _c(0.4, 0.9, 1, 0.22)];
        final points = _sprinkle(24, 13, all);
        for (var i = 0; i < points.length; i++) {
          c.drawCircle(points[i], w * (0.02 + (i % 4) * 0.012), Paint()..color = tints[i % tints.length]);
        }
      case PuzzleBackdrop.indoor:
        _gradient(c, _c(1, 0.94, 0.82), _c(1, 0.86, 0.72), all);
        _gradient(c, _c(0.78, 0.53, 0.32), _c(0.62, 0.4, 0.22), Rect.fromLTWH(0, h * 0.72, w, h * 0.28));
        c.drawRect(Rect.fromLTWH(0, h * 0.72, w, h * 0.018), Paint()..color = _c(0.55, 0.34, 0.18));
      case PuzzleBackdrop.volcano:
        _gradient(c, _c(1, 0.6, 0.35), _c(0.7, 0.28, 0.25), all);
        _gradient(c, _c(0.4, 0.25, 0.18), _c(0.28, 0.16, 0.12), Rect.fromLTWH(0, h * 0.74, w, h * 0.26));
    }
  }

  static void _glow(Canvas c, Offset center, double radius) => c.drawCircle(center, radius,
      Paint()..shader = ui.Gradient.radial(center, radius, [const Color(0x8CFFFFFF), const Color(0x00FFFFFF)]));

  static void _brightGradient(String seed, Canvas c, Size size) {
    var hash = 0;
    for (final r in seed.runes) {
      hash = (hash * 31 + r) & 0x7fffffff;
    }
    final hue = (hash % 360) / 360;
    _gradient(c, HSVColor.fromAHSV(1, hue * 360, 0.55, 1).toColor(), HSVColor.fromAHSV(1, ((hue + 0.12) % 1) * 360, 0.75, 0.9).toColor(),
        Offset.zero & size);
    for (final p in _sprinkle(12, seed.length * 17, Offset.zero & size)) {
      c.drawCircle(p, size.width * 0.04, Paint()..color = _c(1, 1, 1, 0.14));
    }
  }

  static void _text(Canvas c, String text, Offset center, double fontSize, Color color, Color strokeColor) {
    TextPainter painter(Paint? foreground, Color? color, List<Shadow>? shadows) => TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, foreground: foreground, color: color, shadows: shadows, height: 1),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
    final outline = painter(
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fontSize * 0.08
          ..strokeJoin = StrokeJoin.round
          ..color = strokeColor,
        null,
        [Shadow(color: const Color(0x4D000000), blurRadius: fontSize * 0.08, offset: Offset(0, fontSize * 0.04))]);
    final fill = painter(null, color, null);
    final origin = center - Offset(fill.width / 2, fill.height / 2);
    outline.paint(c, origin);
    fill.paint(c, origin);
  }

  static void drawEmoji(Canvas c, PuzzleSceneElement e, Size size, {required bool withShadow}) {
    final fontSize = e.size * size.width;
    final center = Offset(e.x * size.width, e.y * size.height);
    if (withShadow) {
      _ellipse(c, Rect.fromLTWH(center.dx - fontSize * 0.34, center.dy + fontSize * 0.36, fontSize * 0.68, fontSize * 0.12), _c(0, 0, 0, 0.14));
    }
    final painter = TextPainter(
      text: TextSpan(text: e.emoji, style: TextStyle(fontSize: fontSize, height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(c, center - Offset(painter.width / 2, painter.height / 2));
  }

  static void _count(Canvas c, int value, String emoji, Rect rect) {
    final columns = math.min(5, value);
    final rows = (value / 5).ceil();
    final cell = math.min(rect.width / columns, rect.height / math.max(rows, 1));
    final tw = cell * columns, th = cell * rows;
    for (var i = 0; i < value; i++) {
      final x = rect.center.dx - tw / 2 + cell * (i % 5 + 0.5);
      final y = rect.center.dy - th / 2 + cell * (i ~/ 5 + 0.5);
      drawEmoji(c, PuzzleSceneElement(emoji, x / pixelSize, y / pixelSize, cell * 0.8 / pixelSize), const Size(pixelSize, pixelSize),
          withShadow: false);
    }
  }

  static void _paintBlob(Canvas c, PuzzleColor color, Size size) {
    final fill = color.color;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.36;
    c.drawCircle(center + const Offset(0, 10), radius, Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    c.drawCircle(center, radius, Paint()..color = fill);
    for (final (dx, dy, r) in [(-0.33, -0.2, 0.09), (0.34, 0.12, 0.08), (0.1, 0.36, 0.07), (-0.24, 0.3, 0.06)]) {
      c.drawCircle(center + Offset(size.width * dx, size.width * dy), size.width * r, Paint()..color = fill);
    }
    _ellipse(c, Rect.fromLTWH(center.dx - radius * 0.55, center.dy - radius * 0.7, radius * 0.5, radius * 0.28), _c(1, 1, 1, 0.3));
  }

  static void _wordTiles(Canvas c, String text, Size size) {
    final characters = text.characters.where((ch) => ch.trim().isNotEmpty && ch != '-').toList();
    if (characters.isEmpty) return;
    final tile = math.min(size.width * 0.16, size.width * 0.9 / characters.length);
    final gap = tile * 0.08;
    final total = characters.length * tile;
    final tints = [_c(0.95, 0.35, 0.35), _c(0.25, 0.55, 0.95), _c(0.25, 0.7, 0.35), _c(0.98, 0.65, 0.15), _c(0.6, 0.35, 0.85)];
    for (var i = 0; i < characters.length; i++) {
      final rect = Rect.fromLTWH(size.width / 2 - total / 2 + i * tile + gap / 2, size.height * 0.78 - tile / 2, tile - gap, tile - gap);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(tile * 0.18));
      c.drawRRect(rr.shift(const Offset(0, 6)), Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      c.drawRRect(rr, Paint()..color = tints[i % tints.length]);
      _text(c, characters[i], rect.center, tile * 0.6, const Color(0xFFFFFFFF), const Color(0x26000000));
    }
  }
}

extension on String {
  Iterable<String> get characters sync* {
    // Grapheme-ish split good enough for word tiles (letters and combining marks stay together).
    final runes = this.runes.toList();
    var current = StringBuffer();
    for (final r in runes) {
      final isMark = (r >= 0x0300 && r <= 0x036F) || (r >= 0x0900 && r <= 0x0DFF && _isIndicMark(r)) || r == 0x200D || r == 0x200C;
      if (current.isNotEmpty && !isMark) {
        yield current.toString();
        current = StringBuffer();
      }
      current.writeCharCode(r);
    }
    if (current.isNotEmpty) yield current.toString();
  }
}

/// Indic vowel signs and viramas join the letter before them.
bool _isIndicMark(int r) {
  final offset = (r - 0x0900) % 0x80;
  return offset <= 0x03 || (offset >= 0x3A && offset <= 0x4F) || (offset >= 0x51 && offset <= 0x57) || offset == 0x62 || offset == 0x63;
}
