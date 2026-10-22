import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Drawing helpers for scenes: emoji and text drawn centred on a point, with a small cache so the
/// same label isn't laid out again every frame.
class Draw {
  static final _cache = <String, TextPainter>{};
  static const _maxCached = 400;

  static TextPainter _painter(String text, double fontSize, Color color, FontWeight weight) {
    final key = '$text|${fontSize.toStringAsFixed(1)}|${color.toARGB32()}|${weight.value}';
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: weight,
          height: 1.0,
          fontFamilyFallback: const ['SF Pro Rounded', 'Nunito', 'Roboto'],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    _cache[key] = painter;
    if (_cache.length > _maxCached) _cache.remove(_cache.keys.first);
    return painter;
  }

  /// Size of a label.
  static Size measure(String text, double fontSize, {FontWeight weight = FontWeight.w900}) =>
      _painter(text, fontSize, const Color(0xFFFFFFFF), weight).size;

  static final _images = <String, (ui.Image, double, double)>{};
  static const _maxImages = 300;

  /// Text drawn once into a picture at a fixed size step, then scaled when drawn. Scaling real
  /// glyphs every frame (animations) makes the GPU keep rasterising new glyph sizes until its
  /// glyph cache is full, and then emoji stop showing anywhere in the app.
  static (ui.Image, double, double) _image(String text, double pixels, Color color, FontWeight weight) {
    // Size steps: 16, 24, 32, 48, 64, 96, 128, 192, 256, 384, 512 pixels.
    const steps = [16.0, 24.0, 32.0, 48.0, 64.0, 96.0, 128.0, 192.0, 256.0, 384.0, 512.0];
    final step = steps.firstWhere((s) => s >= pixels, orElse: () => steps.last);
    final key = '$text|$step|${color.toARGB32()}|${weight.value}';
    final hit = _images.remove(key);
    if (hit != null) {
      _images[key] = hit;
      return hit;
    }
    final painter = _painter(text, step, color, weight);
    final w = math.max(1, painter.width.ceil() + 4), h = math.max(1, painter.height.ceil() + 4);
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Offset(2, 2));
    final image = recorder.endRecording().toImageSync(w, h);
    final entry = (image, step, painter.width);
    _images[key] = entry;
    if (_images.length > _maxImages) {
      final oldest = _images.keys.first;
      _images.remove(oldest)?.$1.dispose();
    }
    return entry;
  }

  static double get _pixelRatio {
    final views = ui.PlatformDispatcher.instance.views;
    return views.isEmpty ? 2 : views.first.devicePixelRatio;
  }

  /// Draws `text` centred on `center`.
  static void text(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize, {
    Color color = const Color(0xFFFFFFFF),
    FontWeight weight = FontWeight.w900,
    double opacity = 1,
    double rotation = 0,
    double scale = 1,
    bool shadow = false,
  }) {
    if (text.isEmpty || opacity <= 0.01 || fontSize < 1) return;
    final size = (fontSize * scale).clamp(1.0, 600.0);
    final (image, step, _) = _image(text, size * _pixelRatio, color, weight);
    // The picture was laid out at `step`; shrink it to `size`.
    final factor = size / step;
    final w = image.width * factor, h = image.height * factor;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotation != 0) canvas.rotate(rotation);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0, 1));
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    if (shadow) {
      final (shade, _, _) = _image(text, size * _pixelRatio, const Color(0x59000000), weight);
      canvas.drawImageRect(shade, src, Rect.fromCenter(center: const Offset(0, 2), width: w, height: h), paint);
    }
    canvas.drawImageRect(image, src, Rect.fromCenter(center: Offset.zero, width: w, height: h), paint);
    canvas.restore();
  }

  static Paint fill(Color color) => Paint()
    ..color = color
    ..isAntiAlias = true;

  static Paint stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// HSV to colour (h, s, v in 0…1).
  static Color hsv(double h, double s, double v, [double a = 1]) =>
      HSVColor.fromAHSV(a.clamp(0, 1), (h % 1) * 360, s.clamp(0, 1), v.clamp(0, 1)).toColor();

  /// The same hue, lighter or darker (and optionally less saturated).
  static Color adjusted(Color c, double brightness, [double saturation = 1]) {
    final hsv = HSVColor.fromColor(c);
    return hsv.withValue((hsv.value * brightness).clamp(0, 1)).withSaturation((hsv.saturation * saturation).clamp(0, 1)).toColor();
  }
}
