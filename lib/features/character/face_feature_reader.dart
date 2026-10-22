import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'avatar_appearance.dart';
import 'measured_face.dart';

enum FaceReadFailure { noFace, severalFaces, tooDark }

/// What one photo suggests for the character.
class FaceHints {
  FaceHints({
    required this.skinTone,
    this.hairColor,
    required this.faceShape,
    this.hairStyle,
    this.eyeColor,
    this.measured,
  });

  final SkinTone skinTone;

  /// Null when the hair couldn't be told apart from skin or background (the child's pick stays).
  final HairColor? hairColor;
  final FaceShape faceShape;

  /// Null when no hair could be seen to measure, or the eyes weren't found.
  final HairStyle? hairStyle;
  final EyeColor? eyeColor;

  /// The face's own proportions and exact colours, when the landmarks were clear.
  final MeasuredFace? measured;

  /// The child's look with only these things changed.
  AvatarAppearance appliedTo(AvatarAppearance look) {
    final result = look.copy()
      ..skinTone = skinTone
      ..faceShape = faceShape;
    if (hairColor != null) result.hairColor = hairColor!;
    // A style the photo can't tell from short (spiky, curly) or from long (ponytail, buns) is the
    // child's own pick: keep it when the length agrees.
    if (hairStyle != null && _hairLength(look.hairStyle) != _hairLength(hairStyle!)) result.hairStyle = hairStyle!;
    if (eyeColor != null) result.eyeColor = eyeColor!;
    if (measured != null) result.measured = measured;
    return result;
  }

  static int _hairLength(HairStyle style) => switch (style) {
        HairStyle.none => 0,
        HairStyle.short || HairStyle.spiky || HairStyle.curly => 1,
        HairStyle.bob => 2,
        HairStyle.long || HairStyle.ponytail || HairStyle.buns => 3,
      };
}

class FaceReadResult {
  const FaceReadResult.success(FaceHints this.hints) : failure = null;
  const FaceReadResult.failure(FaceReadFailure this.failure) : hints = null;
  final FaceHints? hints;
  final FaceReadFailure? failure;
}

/// The photo scaled down to at most 512 px and read as RGBA bytes, for averaging small patches.
class _Pixels {
  _Pixels(this.width, this.height, this.bytes, this.scale);
  final int width, height;
  final Uint8List bytes;

  /// Photo pixels → these pixels.
  final double scale;

  static Future<_Pixels?> load(String path) async {
    try {
      final data = await File(path).readAsBytes();
      final probe = await ui.instantiateImageCodec(data);
      final full = (await probe.getNextFrame()).image;
      final s = math.min(1.0, 512 / math.max(full.width, full.height));
      final w = math.max(1, (full.width * s).round()), h = math.max(1, (full.height * s).round());
      full.dispose();
      final codec = await ui.instantiateImageCodec(data, targetWidth: w, targetHeight: h);
      final image = (await codec.getNextFrame()).image;
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (bytes == null) return null;
      return _Pixels(w, h, bytes.buffer.asUint8List(), s);
    } catch (_) {
      return null;
    }
  }

  /// Average colour of a square patch around a photo point (null if it falls outside the photo).
  ui.Color? average(ui.Offset photoPoint, double photoSize) {
    final half = math.max(1, (photoSize * scale / 2).round());
    final cx = (photoPoint.dx * scale).round(), cy = (photoPoint.dy * scale).round();
    if (cx - half < 0 || cy - half < 0 || cx + half >= width || cy + half >= height) return null;
    var r = 0, g = 0, b = 0, count = 0;
    for (var y = cy - half; y <= cy + half; y++) {
      for (var x = cx - half; x <= cx + half; x++) {
        final i = (y * width + x) * 4;
        r += bytes[i];
        g += bytes[i + 1];
        b += bytes[i + 2];
        count++;
      }
    }
    final n = count * 255.0;
    return ui.Color.from(alpha: 1, red: r / n, green: g / n, blue: b / n);
  }
}

double _luminance(ui.Color c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;

/// Colour difference weighted the way eyes see it ("redmean").
double colourDistance(ui.Color a, ui.Color b) {
  final mean = (a.r + b.r) / 2;
  final dr = a.r - b.r, dg = a.g - b.g, db = a.b - b.b;
  return math.sqrt((2 + mean) * dr * dr + 4 * dg * dg + (3 - mean) * db * db) / 3;
}

ui.Color? _averageColours(List<ui.Color> colours) {
  if (colours.isEmpty) return null;
  var r = 0.0, g = 0.0, b = 0.0;
  for (final c in colours) {
    r += c.r;
    g += c.g;
    b += c.b;
  }
  final n = colours.length;
  return ui.Color.from(alpha: 1, red: r / n, green: g / n, blue: b / n);
}

/// Looks at one photo, on the device, and suggests a skin tone, hair colour, hair length, eye
/// colour and face shape from the character options, and measures the face (`MeasuredFace`) so the
/// drawn face can be built to match. Only choices and numbers come out; the picture is not kept.
class FaceFeatureReader {
  static Future<FaceReadResult> read(String photoPath) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(enableContours: true, enableLandmarks: true, performanceMode: FaceDetectorMode.accurate),
    );
    try {
      final faces = await detector.processImage(InputImage.fromFilePath(photoPath));
      final pixels = await _Pixels.load(photoPath);
      if (faces.isEmpty || pixels == null) return const FaceReadResult.failure(FaceReadFailure.noFace);
      final photoWidth = pixels.width / pixels.scale;
      // A grown-up helping may be in the picture too: several big faces is confusing, so ask again.
      final big = faces.where((f) => f.boundingBox.width / photoWidth > 0.15).toList();
      if (big.length > 1) return const FaceReadResult.failure(FaceReadFailure.severalFaces);
      final face = big.isNotEmpty ? big.first : faces.reduce((a, b) => a.boundingBox.width >= b.boundingBox.width ? a : b);
      return _readFace(face, pixels);
    } catch (_) {
      return const FaceReadResult.failure(FaceReadFailure.noFace);
    } finally {
      detector.close();
    }
  }

  static FaceReadResult _readFace(Face face, _Pixels pixels) {
    final rect = face.boundingBox;
    final patch = rect.width * 0.12;
    final cheeks = [
      ui.Offset(rect.left + rect.width * 0.27, rect.top + rect.height * 0.6),
      ui.Offset(rect.left + rect.width * 0.73, rect.top + rect.height * 0.6),
    ].map((p) => pixels.average(p, patch)).whereType<ui.Color>().toList();
    final skin = _averageColours(cheeks);
    if (skin == null) return const FaceReadResult.failure(FaceReadFailure.noFace);
    if (_luminance(skin) <= 0.12) return const FaceReadResult.failure(FaceReadFailure.tooDark);

    // Hair: just above the forehead.
    final hair = pixels.average(ui.Offset(rect.center.dx, rect.top - rect.height * 0.08), rect.width * 0.2);
    final hairColor = hair == null || colourDistance(hair, skin) < 0.12 ? null : nearestHairColor(hair);

    // Hair length: is there hair beside the jaw, and below it by the neck, on both sides?
    HairStyle? hairStyle;
    if (hair != null && hairColor != null) {
      bool hasHair(double x, double y) => [rect.left - rect.width * x, rect.right + rect.width * x].every((spotX) {
            final sample = pixels.average(ui.Offset(spotX, rect.top + rect.height * y), rect.width * 0.1);
            return sample != null && colourDistance(sample, hair) < 0.1 && colourDistance(sample, skin) > 0.1;
          });
      hairStyle = hairStyleFor(besideJaw: hasHair(0.12, 0.8), belowJaw: hasHair(0.02, 1.2));
    }

    List<ui.Offset> contour(FaceContourType type) =>
        (face.contours[type]?.points ?? const []).map((p) => ui.Offset(p.x.toDouble(), p.y.toDouble())).toList();

    // Eye colour: the iris either side of each pupil (the pupil itself is always dark).
    final irises = <ui.Color>[];
    for (final eye in [contour(FaceContourType.leftEye), contour(FaceContourType.rightEye)]) {
      if (eye.isEmpty) continue;
      final minX = eye.map((p) => p.dx).reduce(math.min), maxX = eye.map((p) => p.dx).reduce(math.max);
      if (maxX - minX <= 8) continue;
      final width = maxX - minX;
      final centreY = eye.map((p) => p.dy).reduce((a, b) => a + b) / eye.length;
      for (final side in [-1.0, 1.0]) {
        final sample = pixels.average(ui.Offset((minX + maxX) / 2 + side * width * 0.13, centreY), width * 0.1);
        if (sample != null) irises.add(sample);
      }
    }
    final iris = _averageColours(irises);
    final eyeColor = iris == null ? null : nearestEyeColor(iris);

    // The face's own proportions, and the lip colour from the middle of the mouth.
    final lips = [...contour(FaceContourType.upperLipTop), ...contour(FaceContourType.lowerLipBottom)];
    final marks = Landmarks()
      ..leftEye = contour(FaceContourType.leftEye)
      ..rightEye = contour(FaceContourType.rightEye)
      ..leftBrow = [...contour(FaceContourType.leftEyebrowTop), ...contour(FaceContourType.leftEyebrowBottom)]
      ..rightBrow = [...contour(FaceContourType.rightEyebrowTop), ...contour(FaceContourType.rightEyebrowBottom)]
      ..nose = [...contour(FaceContourType.noseBridge), ...contour(FaceContourType.noseBottom)]
      ..lips = lips
      // ML Kit's outline goes all round the face; the lower part is the jaw, as on iOS.
      ..contour = _lowerFace(contour(FaceContourType.face));
    final proportions = MeasuredFace.proportionsFrom(marks);
    ui.Color? lipColour;
    if (lips.isNotEmpty) {
      final middle = ui.Offset(lips.map((p) => p.dx).reduce((a, b) => a + b) / lips.length,
          lips.map((p) => p.dy).reduce((a, b) => a + b) / lips.length);
      lipColour = pixels.average(middle, rect.width * 0.06);
    }
    final skinTone = nearestSkinTone(skin);
    final measured = proportions == null
        ? null
        : MeasuredFace(
            proportions: proportions,
            skin: Tint.of(skin),
            skinMatch: skinTone,
            hair: hairColor == null || hair == null ? null : Tint.of(hair),
            hairMatch: hairColor,
            iris: iris == null ? null : Tint.of(iris),
            irisMatch: eyeColor,
            lips: lipColour == null ? null : Tint.of(lipColour),
          );

    // Face shape from the jaw outline when there is one, else from the box.
    var ratio = rect.width / math.max(rect.height, 1);
    final outline = contour(FaceContourType.face);
    if (outline.length > 4) {
      final xs = outline.map((p) => p.dx), ys = outline.map((p) => p.dy);
      final h = ys.reduce(math.max) - ys.reduce(math.min);
      if (h > 0) ratio = (xs.reduce(math.max) - xs.reduce(math.min)) / h;
    }
    return FaceReadResult.success(FaceHints(
      skinTone: skinTone,
      hairColor: hairColor,
      faceShape: faceShapeFor(ratio),
      hairStyle: hairStyle,
      eyeColor: eyeColor,
      measured: measured,
    ));
  }

  /// The points of a full face outline from the eye line down (what Apple's contour covers).
  static List<ui.Offset> _lowerFace(List<ui.Offset> outline) {
    if (outline.isEmpty) return outline;
    final top = outline.map((p) => p.dy).reduce(math.min), bottom = outline.map((p) => p.dy).reduce(math.max);
    final cut = top + (bottom - top) * 0.35;
    return outline.where((p) => p.dy >= cut).toList();
  }

  // Matching (pure, tested)

  static T _nearest<T>(List<T> values, ui.Color Function(T) colour, ui.Color target) =>
      values.reduce((a, b) => colourDistance(target, colour(a)) <= colourDistance(target, colour(b)) ? a : b);

  static SkinTone nearestSkinTone(ui.Color c) => _nearest(SkinTone.values, (v) => v.color, c);
  static HairColor nearestHairColor(ui.Color c) => _nearest(HairColor.values, (v) => v.color, c);
  static EyeColor nearestEyeColor(ui.Color c) => _nearest(EyeColor.values, (v) => v.color, c);

  /// Hair by the neck is long; hair only as far as the jaw is a bob; otherwise short.
  static HairStyle hairStyleFor({required bool besideJaw, required bool belowJaw}) {
    if (belowJaw) return HairStyle.long;
    return besideJaw ? HairStyle.bob : HairStyle.short;
  }

  /// ML Kit's outline includes the forehead, so the whole face is about 1.25× as tall as wide.
  static FaceShape faceShapeFor(double widthToHeight) {
    if (widthToHeight >= 0.86) return FaceShape.wide;
    if (widthToHeight < 0.72) return FaceShape.oval;
    return FaceShape.round;
  }
}
