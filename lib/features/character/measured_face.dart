import 'dart:math' as math;
import 'dart:ui';

import 'avatar_appearance.dart';

/// A colour as three numbers, so it can be saved with the look.
class Tint {
  const Tint(this.red, this.green, this.blue);
  Tint.of(Color c)
      : red = c.r,
        green = c.g,
        blue = c.b;
  final double red, green, blue;

  Color get color => Color.from(alpha: 1, red: red, green: green, blue: blue);

  Map<String, dynamic> toJson() => {'red': red, 'green': green, 'blue': blue};
  factory Tint.fromJson(Map<String, dynamic> j) =>
      Tint((j['red'] as num).toDouble(), (j['green'] as num).toDouble(), (j['blue'] as num).toDouble());

  @override
  bool operator ==(Object other) => other is Tint && other.red == red && other.green == green && other.blue == blue;
  @override
  int get hashCode => Object.hash(red, green, blue);
}

/// Face proportions. Widths are fractions of the face's width; heights are in eye-gaps (the
/// distance between the eye centres) below or above the eye line. The defaults are a typical
/// child's face, which draws the standard cartoon face.
class Proportions {
  Proportions({
    this.eyeSpacing = 0.44,
    this.eyeWidth = 0.2,
    this.eyeOpen = 0.36,
    this.eyeTilt = 0.0,
    this.browGap = 0.38,
    this.browLength = 0.33,
    this.browTilt = 0.0,
    this.noseWidth = 0.25,
    this.noseLength = 0.6,
    this.mouthWidth = 0.35,
    this.mouthDrop = 0.95,
    this.lipHeight = 0.28,
    this.faceLength = 1.75,
    this.jawWidth = 0.72,
  });

  double eyeSpacing, eyeWidth;

  /// Eye height over eye width: round eyes are higher.
  double eyeOpen;

  /// How much the outer corners sit above the inner ones (0 = level).
  double eyeTilt;
  double browGap, browLength, browTilt, noseWidth, noseLength, mouthWidth, mouthDrop, lipHeight, faceLength;

  /// Width of the jaw, two thirds of the way down to the chin.
  double jawWidth;

  static const _keys = [
    'eyeSpacing', 'eyeWidth', 'eyeOpen', 'eyeTilt', 'browGap', 'browLength', 'browTilt',
    'noseWidth', 'noseLength', 'mouthWidth', 'mouthDrop', 'lipHeight', 'faceLength', 'jawWidth',
  ];

  double operator [](String key) => switch (key) {
        'eyeSpacing' => eyeSpacing,
        'eyeWidth' => eyeWidth,
        'eyeOpen' => eyeOpen,
        'eyeTilt' => eyeTilt,
        'browGap' => browGap,
        'browLength' => browLength,
        'browTilt' => browTilt,
        'noseWidth' => noseWidth,
        'noseLength' => noseLength,
        'mouthWidth' => mouthWidth,
        'mouthDrop' => mouthDrop,
        'lipHeight' => lipHeight,
        'faceLength' => faceLength,
        'jawWidth' => jawWidth,
        _ => 0,
      };

  Map<String, dynamic> toJson() => {for (final k in _keys) k: this[k]};

  factory Proportions.fromJson(Map<String, dynamic> j) {
    double v(String k, double d) => (j[k] as num?)?.toDouble() ?? d;
    final t = Proportions();
    return Proportions(
      eyeSpacing: v('eyeSpacing', t.eyeSpacing),
      eyeWidth: v('eyeWidth', t.eyeWidth),
      eyeOpen: v('eyeOpen', t.eyeOpen),
      eyeTilt: v('eyeTilt', t.eyeTilt),
      browGap: v('browGap', t.browGap),
      browLength: v('browLength', t.browLength),
      browTilt: v('browTilt', t.browTilt),
      noseWidth: v('noseWidth', t.noseWidth),
      noseLength: v('noseLength', t.noseLength),
      mouthWidth: v('mouthWidth', t.mouthWidth),
      mouthDrop: v('mouthDrop', t.mouthDrop),
      lipHeight: v('lipHeight', t.lipHeight),
      faceLength: v('faceLength', t.faceLength),
      jawWidth: v('jawWidth', t.jawWidth),
    );
  }
}

/// The face's landmark points in photo pixels, measured from the top-left.
class Landmarks {
  List<Offset> leftEye = [], rightEye = [], leftBrow = [], rightBrow = [], nose = [], lips = [], contour = [];
}

/// What one photo says about a child's face, kept as plain numbers and colours — never a picture.
class MeasuredFace {
  MeasuredFace({
    Proportions? proportions,
    required this.skin,
    required this.skinMatch,
    this.hair,
    this.hairMatch,
    this.iris,
    this.irisMatch,
    this.lips,
  }) : proportions = proportions ?? Proportions();

  Proportions proportions;

  /// The sampled colours, each with the catalogue option it was matched to. The exact colour is
  /// used while the child keeps that option; picking another swatch wins.
  Tint skin;
  SkinTone skinMatch;
  Tint? hair;
  HairColor? hairMatch;
  Tint? iris;
  EyeColor? irisMatch;
  Tint? lips;

  static final typical = Proportions();

  Map<String, dynamic> toJson() => {
        'proportions': proportions.toJson(),
        'skin': skin.toJson(),
        'skinMatch': skinMatch.name,
        if (hair != null) 'hair': hair!.toJson(),
        if (hairMatch != null) 'hairMatch': hairMatch!.name,
        if (iris != null) 'iris': iris!.toJson(),
        if (irisMatch != null) 'irisMatch': irisMatch!.name,
        if (lips != null) 'lips': lips!.toJson(),
      };

  factory MeasuredFace.fromJson(Map<String, dynamic> j) {
    Tint? tint(String k) => j[k] is Map ? Tint.fromJson((j[k] as Map).cast<String, dynamic>()) : null;
    return MeasuredFace(
      proportions: j['proportions'] is Map ? Proportions.fromJson((j['proportions'] as Map).cast<String, dynamic>()) : null,
      skin: tint('skin') ?? Tint.of(SkinTone.tan.color),
      skinMatch: SkinTone.values.where((v) => v.name == j['skinMatch']).firstOrNull ?? SkinTone.tan,
      hair: tint('hair'),
      hairMatch: HairColor.values.where((v) => v.name == j['hairMatch']).firstOrNull,
      iris: tint('iris'),
      irisMatch: EyeColor.values.where((v) => v.name == j['irisMatch']).firstOrNull,
      lips: tint('lips'),
    );
  }

  /// How much bigger (above 1) or smaller a feature is drawn than on the standard face. The
  /// difference from a typical face is exaggerated a little, as a cartoonist would, and kept
  /// within friendly limits.
  double amount(String feature) {
    final t = typical[feature];
    if (t <= 0) return 1;
    final ratio = proportions[feature] / t;
    if (!ratio.isFinite || ratio <= 0) return 1;
    return math.pow(ratio, 1.5).toDouble().clamp(0.72, 1.38);
  }

  /// The face's width for its length, against a typical face: above 1 is a wider head.
  double get headWidth {
    final t = 1 / (typical.eyeSpacing * typical.faceLength);
    final own = 1 / (proportions.eyeSpacing * proportions.faceLength);
    if (!own.isFinite || own <= 0) return 1;
    return (own / t).clamp(0.92, 1.1);
  }

  /// Proportions from landmark points, with the head straightened so the eyes are level. Null
  /// when the eyes or the face outline are missing; any other part that is missing keeps its
  /// typical value.
  static Proportions? proportionsFrom(Landmarks marks) {
    final one = _centre(marks.leftEye), other = _centre(marks.rightEye);
    if (one == null || other == null) return null;
    final gap = (other - one).distance;
    if (gap <= 1) return null;
    final swapped = one.dx > other.dx;
    final first = swapped ? other : one, second = swapped ? one : other;
    final middle = Offset((first.dx + second.dx) / 2, (first.dy + second.dy) / 2);
    final angle = -math.atan2(second.dy - first.dy, second.dx - first.dx);
    final c = math.cos(angle), s = math.sin(angle);
    // Eye space: the point between the eyes is the origin, x to the right, y down.
    List<Offset> level(List<Offset> points) => [
          for (final p in points)
            Offset((p.dx - middle.dx) * c - (p.dy - middle.dy) * s, (p.dx - middle.dx) * s + (p.dy - middle.dy) * c)
        ];

    final contour = level(marks.contour);
    final width = _extent(contour, true);
    if (width == null || width <= gap || contour.isEmpty) return null;
    final chin = contour.map((p) => p.dy).reduce(math.max);
    if (chin <= 0) return null;

    final result = Proportions()
      ..eyeSpacing = gap / width
      ..faceLength = chin / gap;

    final eyes = [level(swapped ? marks.rightEye : marks.leftEye), level(swapped ? marks.leftEye : marks.rightEye)];
    final eyeWidths = eyes.map((e) => _extent(e, true)).whereType<double>().where((w) => w > 0).toList();
    if (eyeWidths.length == 2) {
      result.eyeWidth = (eyeWidths[0] + eyeWidths[1]) / 2 / width;
      final heights = eyes.map((e) => _extent(e, false) ?? 0).toList();
      result.eyeOpen = (heights[0] / eyeWidths[0] + heights[1] / eyeWidths[1]) / 2;
      result.eyeTilt = (_outerRise(eyes[0], true) + _outerRise(eyes[1], false)) / 2;
    }

    final brows = [level(swapped ? marks.rightBrow : marks.leftBrow), level(swapped ? marks.leftBrow : marks.rightBrow)];
    final left = _centre(brows[0]), right = _centre(brows[1]);
    final leftLength = _extent(brows[0], true), rightLength = _extent(brows[1], true);
    if (left != null && right != null && leftLength != null && rightLength != null) {
      result.browGap = -(left.dy + right.dy) / 2 / gap;
      result.browLength = (leftLength + rightLength) / 2 / width;
      result.browTilt = (_outerRise(brows[0], true) + _outerRise(brows[1], false)) / 2;
    }

    final nose = level(marks.nose);
    final noseWidth = _extent(nose, true);
    if (noseWidth != null && nose.isNotEmpty) {
      result.noseWidth = noseWidth / width;
      result.noseLength = nose.map((p) => p.dy).reduce(math.max) / gap;
    }

    final lips = level(marks.lips);
    final lipWidth = _extent(lips, true), lipHeight = _extent(lips, false), lipMiddle = _centre(lips);
    if (lipWidth != null && lipHeight != null && lipMiddle != null) {
      result.mouthWidth = lipWidth / width;
      result.mouthDrop = lipMiddle.dy / gap;
      result.lipHeight = lipHeight / gap;
    }

    final jaw = _extent(contour.where((p) => p.dy > chin * 0.55 && p.dy < chin * 0.8).toList(), true);
    if (jaw != null && jaw > 0) result.jawWidth = jaw / width;
    return result;
  }

  static Offset? _centre(List<Offset> points) {
    if (points.isEmpty) return null;
    var x = 0.0, y = 0.0;
    for (final p in points) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / points.length, y / points.length);
  }

  static double? _extent(List<Offset> points, bool horizontal) {
    if (points.length < 2) return null;
    final values = points.map((p) => horizontal ? p.dx : p.dy);
    return values.reduce(math.max) - values.reduce(math.min);
  }

  /// How far the outer end of an eye or brow sits above its inner end, as a share of its width.
  static double _outerRise(List<Offset> points, bool outerIsLeft) {
    if (points.isEmpty) return 0;
    final leftmost = points.reduce((a, b) => a.dx <= b.dx ? a : b);
    final rightmost = points.reduce((a, b) => a.dx >= b.dx ? a : b);
    if (rightmost.dx <= leftmost.dx) return 0;
    final outer = outerIsLeft ? leftmost : rightmost, inner = outerIsLeft ? rightmost : leftmost;
    return (inner.dy - outer.dy) / (rightmost.dx - leftmost.dx);
  }
}
