import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show Rect, Offset, Size;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path_provider/path_provider.dart';

import 'ar_explorer_content.dart';

// Recognition for AR Explorer. Runs only when the child taps (never on every frame), looks only at
// the area around the tap, and stays on the device: pictures are deleted straight after and never
// uploaded. Wrong teaching is worse than none, so an object is only named when one candidate
// clearly wins.

/// What a supported object is called in the recogniser's labels.
class RecognitionCandidate {
  const RecognitionCandidate(this.id, this.keywords);
  final String id;
  final List<String> keywords;
}

enum RecognitionCertainty {
  /// Safe to teach.
  confident,

  /// Probably this object: ask the child to confirm before teaching.
  probable,

  /// Don't name anything.
  unsure,
}

typedef Labels = List<(String, double)>;

class RecognitionDecision {
  const RecognitionDecision(this.objectID, this.certainty);
  final String? objectID;
  final RecognitionCertainty certainty;
  static const unsure = RecognitionDecision(null, RecognitionCertainty.unsure);
}

/// Decisions (pure, testable).
class ARExplorerRecognitionRules {
  // ML Kit's labeller scores higher than Apple's classifier (right answers usually 0.6–0.9, guesses
  // around 0.5), so these bars are higher than on iOS.
  /// Label confidence needed to teach without asking.
  static const confidentScore = 0.6;

  /// Below this, nothing is named at all.
  static const probableScore = 0.4;

  /// The best object must clearly beat the next object.
  static const confidentMargin = 2.0;
  static const probableMargin = 1.3;

  /// To ask "is this a …?", the object must be nearly as strong as any other thing in view.
  static const probableAgainstOther = 0.8;

  /// Find Things: the target's own label score needed (with it beating every other object).
  static const targetScoreNeeded = 0.3;

  /// Real things the recogniser can see that AR Explorer does not teach. When one of these is
  /// clearly what the picture shows, naming one of our own objects would be wrong.
  static const otherThings = {
    'cabinet', 'refrigerator', 'bed', 'bedding', 'bookshelf', 'closet', 'stool', 'bench', 'crib', //
    'curtain', 'window', 'stairs', 'fireplace', 'toilet seat', 'washbasin', 'shower', 'bath', 'kitchen sink',
    'kitchen faucet', 'bathroom faucet', 'frame', 'painting', 'whiteboard', 'chalkboard', 'calendar',
    'stove', 'kitchen oven', 'oven', 'microwave', 'toaster', 'toaster oven', 'dishwasher', 'laundry machine',
    'blender', 'kettle', 'teapot', 'pot cooking', 'pan', 'bowl', 'knife', 'ladle', 'spatula', 'whisk',
    'chopsticks', 'cutting board', 'jar', 'jug', 'vase', 'drinking glass', 'bucket', 'trash can',
    'cardboard box', 'basket container',
    'toy', 'stuffed animals', 'stuffed toy', 'doll', 'blocks', 'puzzles', 'vehicle toy', 'train toy', 'figurine', 'balloon',
    'hat', 'baseball hat', 'helmet', 'sock', 'glove', 'jacket', 'jeans', 'scarf', 'necktie', 'watch', 'wallet',
    'newspaper', 'envelope', 'broom', 'mop', 'vacuum', 'iron clothing', 'hammer', 'screwdriver', 'wrench',
    'pliers', 'toolbox',
    'computer monitor', 'computer mouse', 'computer tower', 'printer', 'speakers music', 'headphones',
    'camera', 'gamepad', 'calculator', 'keypad', 'light bulb', 'chandelier',
    'bicycle', 'tricycle', 'stroller', 'car', 'motorcycle', 'scooter', 'skateboard', 'guitar', 'piano', 'drum',
    'bird', 'fish', 'rabbit', 'hamster',
    'bread', 'cake', 'pizza', 'rice', 'egg', 'cookie', 'biscuit', 'sandwich', 'cucumber', 'corn', 'garlic',
    'eggplant', 'broccoli', 'cauliflower', 'bell pepper', 'pumpkin', 'mushroom', 'avocado', 'papaya', 'guava',
    'pomegranate', 'lime', 'melon', 'cantaloupe', 'plum', 'fig',
    // People: ML Kit names faces and bodies; when one fills the tapped picture, it is not our object.
    'person', 'selfie', 'beard', 'moustache', 'skin', 'smile', 'hair', 'ear', 'eyelash', 'flesh', 'muscle',
    'tattoo', 'hand', 'nail', 'baby', 'child',
  };

  static String normalize(String text) => text.toLowerCase().replaceAll('_', ' ').trim();

  /// Each object's score (strongest first), and the score of the strongest other thing.
  static (List<(String, double)>, double) _scores(Labels labels, List<RecognitionCandidate> candidates) {
    final strongest = <String, double>{};
    for (final (label, confidence) in labels) {
      final key = normalize(label);
      strongest[key] = math.max(strongest[key] ?? 0, confidence);
    }
    final scores = [
      for (final c in candidates)
        (c.id, c.keywords.map((k) => strongest[normalize(k)] ?? 0.0).fold(0.0, math.max)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    var other = 0.0;
    for (final o in otherThings) {
      other = math.max(other, strongest[o] ?? 0);
    }
    return (scores, other);
  }

  /// Picks the object the labels point to, if one clearly wins.
  static RecognitionDecision decideLabels(Labels labels, List<RecognitionCandidate> candidates) {
    final (scores, other) = _scores(labels, candidates);
    if (scores.isEmpty || scores.first.$2 <= 0) return RecognitionDecision.unsure;
    final best = scores.first;
    final runnerUp = scores.length > 1 ? scores[1].$2 : 0.0;
    if (best.$2 >= confidentScore && best.$2 >= runnerUp * confidentMargin && best.$2 >= other) {
      return RecognitionDecision(best.$1, RecognitionCertainty.confident);
    }
    if (best.$2 >= probableScore && best.$2 >= runnerUp * probableMargin && best.$2 >= other * probableAgainstOther) {
      return RecognitionDecision(best.$1, RecognitionCertainty.probable);
    }
    return RecognitionDecision.unsure;
  }

  /// The picture clearly shows a thing we don't teach, far more than any of our objects.
  static bool pointsElsewhere(Labels labels, List<RecognitionCandidate> candidates) {
    final (scores, other) = _scores(labels, candidates);
    return other >= confidentScore && other >= (scores.isEmpty ? 0 : scores.first.$2) * confidentMargin;
  }

  /// Checks label sets from tightest to widest crop: the first confident answer wins; otherwise
  /// the first probable one; otherwise nothing.
  static RecognitionDecision decide(List<Labels> crops, List<RecognitionCandidate> candidates) {
    String? probable;
    for (final labels in crops) {
      final d = decideLabels(labels, candidates);
      if (d.certainty == RecognitionCertainty.confident) return d;
      if (d.certainty == RecognitionCertainty.probable) probable ??= d.objectID;
      if (pointsElsewhere(labels, candidates)) break;
    }
    return probable == null ? RecognitionDecision.unsure : RecognitionDecision(probable, RecognitionCertainty.probable);
  }

  /// Find Things: what the camera thinks the tapped thing is, knowing the child is looking for
  /// `target`. `closeCrops` is how many of the first crops show just the tapped object.
  static String? check(String target, List<Labels> crops, List<RecognitionCandidate> candidates, int closeCrops) {
    var targetBest = 0.0;
    for (var i = 0; i < crops.length; i++) {
      final (scores, other) = _scores(crops[i], candidates);
      final targetScore = scores.where((s) => s.$1 == target).firstOrNull?.$2 ?? 0;
      targetBest = math.max(targetBest, targetScore);
      if (i < closeCrops &&
          targetScore >= targetScoreNeeded &&
          scores.isNotEmpty &&
          scores.first.$1 == target &&
          targetScore >= other * probableAgainstOther) {
        return target;
      }
    }
    final d = decide(crops, candidates);
    if (d.objectID == target && d.certainty != RecognitionCertainty.unsure) return target;
    if (d.certainty == RecognitionCertainty.confident && targetBest < probableScore) return d.objectID;
    return null;
  }

  /// One clear colour from RGBA8 pixels, or null when the area is grey, dark or mixed.
  static ExplorerColor? dominantColor(Uint8List rgba) {
    var sinSum = 0.0, cosSum = 0.0, colourful = 0;
    final count = rgba.length ~/ 4;
    if (count == 0) return null;
    for (var i = 0; i < count; i++) {
      final r = rgba[i * 4] / 255, g = rgba[i * 4 + 1] / 255, b = rgba[i * 4 + 2] / 255;
      final maxC = math.max(r, math.max(g, b)), minC = math.min(r, math.min(g, b)), delta = maxC - minC;
      if (delta <= 0.25 || maxC <= 0.25) continue;
      double hue;
      if (maxC == r) {
        hue = ((g - b) / delta) % 6;
      } else if (maxC == g) {
        hue = (b - r) / delta + 2;
      } else {
        hue = (r - g) / delta + 4;
      }
      hue = (hue / 6) % 1;
      if (hue < 0) hue += 1;
      sinSum += math.sin(hue * 2 * math.pi);
      cosSum += math.cos(hue * 2 * math.pi);
      colourful++;
    }
    // Most of the area must be colourful, and the colours must agree.
    if (colourful < count * 0.35) return null;
    final agreement = math.sqrt(sinSum * sinSum + cosSum * cosSum) / colourful;
    if (agreement < 0.75) return null;
    var mean = math.atan2(sinSum, cosSum) / (2 * math.pi);
    if (mean < 0) mean += 1;
    return ExplorerColor.forHue(mean);
  }
}

/// Pictures cut out of one camera photo where the child tapped.
class TapCrops {
  TapCrops(this.objectFiles, this.colorPixels, this.cutoutFiles);

  /// Squares around the tap from tight to wide, as files for the on-device recogniser.
  final List<String> objectFiles;
  final Uint8List colorPixels;

  /// The tapped object's own box, when one was found.
  final List<String> cutoutFiles;

  Future<void> delete() async {
    for (final path in [...objectFiles, ...cutoutFiles]) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }
}

/// ML Kit's on-device labeller and object finder. Works offline; nothing leaves the device.
class ARObjectRecognizer {
  final _labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.05));
  final _objects = ObjectDetector(
      options: ObjectDetectorOptions(mode: DetectionMode.single, classifyObjects: false, multipleObjects: true));
  int _counter = 0;

  void close() {
    _labeler.close();
    _objects.close();
  }

  Future<Labels> classify(String path) async {
    try {
      final labels = await _labeler.processImage(InputImage.fromFilePath(path));
      return [for (final l in labels) (l.label, l.confidence)];
    } catch (_) {
      return const [];
    }
  }

  /// Cuts squares out of a camera photo around `tap` (in a view of `viewSize` that shows the
  /// camera aspect-filled), plus the tapped object's box when the object finder sees one there.
  Future<TapCrops?> crops(String photoPath, Offset tap, Size viewSize) async {
    try {
      final bytes = await File(photoPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      final width = image.width.toDouble(), height = image.height.toDouble();
      if (width <= 0 || height <= 0 || viewSize.isEmpty) return null;
      // The view shows the picture aspect-filled and centred.
      final scale = math.max(viewSize.width / width, viewSize.height / height);
      final x = (tap.dx + (width * scale - viewSize.width) / 2) / scale;
      final y = (tap.dy + (height * scale - viewSize.height) / 2) / scale;
      final centre = Offset(x, y);
      final short = math.min(width, height);
      final bounds = Rect.fromLTWH(0, 0, width, height);
      final dir = await getTemporaryDirectory();

      final objectFiles = <String>[];
      for (final fraction in const [0.35, 0.5, 0.7]) {
        final path = await _save(image, _square(centre, short * fraction, bounds), dir);
        if (path != null) objectFiles.add(path);
      }
      final colorRect = _square(centre, short * 0.08, bounds);
      final tiny = await _crop(image, colorRect, 24);
      final pixels = (await tiny.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      tiny.dispose();

      // The tapped object on its own: find boxes in a wider square, keep the one under the finger.
      final cutouts = <String>[];
      final sourceRect = _square(centre, short * 0.8, bounds);
      final sourcePath = await _save(image, sourceRect, dir, maxSide: 640);
      if (sourcePath != null) {
        final found = await _objects.processImage(InputImage.fromFilePath(sourcePath));
        final s = math.min(640 / sourceRect.width, 1.0);
        final tapIn = (centre - sourceRect.topLeft) * s;
        final area = sourceRect.width * sourceRect.height * s * s;
        Rect? best;
        var bestDistance = double.infinity;
        for (final o in found) {
          final box = o.boundingBox;
          final share = box.width * box.height / area;
          if (share < 0.01 || share > 0.85) continue;
          final reach = 0.06 * sourceRect.shortestSide * s;
          final d = box.contains(tapIn) ? 0.0 : _distance(box, tapIn);
          if (d <= reach && d < bestDistance) {
            bestDistance = d;
            best = box;
          }
        }
        if (best != null) {
          final pad = 0.1 * math.max(best.width, best.height);
          final inImage = Rect.fromLTRB(
            sourceRect.left + (best.left - pad) / s,
            sourceRect.top + (best.top - pad) / s,
            sourceRect.left + (best.right + pad) / s,
            sourceRect.top + (best.bottom + pad) / s,
          ).intersect(bounds);
          if (!inImage.isEmpty) {
            final path = await _save(image, inImage, dir);
            if (path != null) cutouts.add(path);
          }
        }
        try {
          await File(sourcePath).delete();
        } catch (_) {}
      }
      image.dispose();
      return TapCrops(objectFiles, pixels, cutouts);
    } catch (_) {
      return null;
    } finally {
      try {
        await File(photoPath).delete();
      } catch (_) {}
    }
  }

  static double _distance(Rect r, Offset p) {
    final dx = math.max(math.max(r.left - p.dx, 0), p.dx - r.right);
    final dy = math.max(math.max(r.top - p.dy, 0), p.dy - r.bottom);
    return math.sqrt(dx * dx + dy * dy);
  }

  static Rect _square(Offset centre, double side, Rect bounds) {
    final s = math.min(side, math.min(bounds.width, bounds.height));
    final left = (centre.dx - s / 2).clamp(bounds.left, bounds.right - s);
    final top = (centre.dy - s / 2).clamp(bounds.top, bounds.bottom - s);
    return Rect.fromLTWH(left.roundToDouble(), top.roundToDouble(), s.roundToDouble(), s.roundToDouble());
  }

  static Future<ui.Image> _crop(ui.Image image, Rect rect, double maxSide) async {
    final scale = math.min(1.0, maxSide / math.max(rect.width, rect.height));
    final w = math.max(1, (rect.width * scale).round()), h = math.max(1, (rect.height * scale).round());
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(image, rect, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium);
    final picture = recorder.endRecording();
    final out = await picture.toImage(w, h);
    picture.dispose();
    return out;
  }

  Future<String?> _save(ui.Image image, Rect rect, Directory dir, {double maxSide = 448}) async {
    if (rect.isEmpty) return null;
    final cropped = await _crop(image, rect, maxSide);
    final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();
    if (png == null) return null;
    final path = '${dir.path}/ar-crop-${DateTime.now().microsecondsSinceEpoch}-${_counter++}.png';
    await File(path).writeAsBytes(png.buffer.asUint8List(), flush: true);
    return path;
  }
}
