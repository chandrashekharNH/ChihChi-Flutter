import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// What the child should do next to get a good photo.
enum FaceGuidance { noFace, severalFaces, comeCloser, centre, moreLight, good }

enum CaptureState { starting, live, denied, unavailable }

/// The front camera for the character photo: shows a live preview, checks a few times a second
/// that one face is inside the circle, close and bright enough, and takes the photo. Frames stay
/// in memory; the photo file is deleted as soon as it has been read.
class FaceCaptureModel extends ChangeNotifier {
  CaptureState state = CaptureState.starting;
  FaceGuidance guidance = FaceGuidance.noFace;
  CameraController? controller;

  final _detector = FaceDetector(options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast));
  bool _busy = false;
  DateTime _lastCheck = DateTime.fromMillisecondsSinceEpoch(0);
  CameraDescription? _camera;

  Future<void> start() async {
    try {
      final cameras = await availableCameras();
      _camera = cameras.where((c) => c.lensDirection == CameraLensDirection.front).firstOrNull ?? cameras.firstOrNull;
      if (_camera == null) {
        _set(CaptureState.unavailable);
        return;
      }
      final c = CameraController(
        _camera!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      controller = c;
      await c.initialize();
      await c.startImageStream(_analyse);
      _set(CaptureState.live);
    } on CameraException catch (e) {
      final denied = e.code.contains('Denied') || e.code.contains('denied') || e.code.contains('Restricted');
      _set(denied ? CaptureState.denied : CaptureState.unavailable);
    } catch (_) {
      _set(CaptureState.unavailable);
    }
  }

  void _set(CaptureState s) {
    state = s;
    notifyListeners();
  }

  Future<void> stop() async {
    final c = controller;
    controller = null;
    guidance = FaceGuidance.noFace;
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
    await c.dispose();
  }

  /// Takes the photo. The caller deletes the file once it has been read.
  Future<String?> capture() async {
    final c = controller;
    if (c == null) return null;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
      final file = await c.takePicture();
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _analyse(CameraImage image) async {
    final now = DateTime.now();
    if (_busy || now.difference(_lastCheck) < const Duration(milliseconds: 250)) return;
    _busy = true;
    _lastCheck = now;
    try {
      final input = _inputImage(image);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      final next = _guidance(faces, image, input.metadata?.rotation ?? InputImageRotation.rotation0deg);
      if (next != guidance) {
        guidance = next;
        notifyListeners();
      }
    } catch (_) {
      // A frame that can't be read is simply skipped.
    } finally {
      _busy = false;
    }
  }

  InputImage? _inputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null || image.planes.isEmpty) return null;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null) return null;
    final plane = image.planes.first;
    final bytes = Platform.isAndroid && image.planes.length > 1
        ? Uint8List.fromList([for (final p in image.planes) ...p.bytes])
        : plane.bytes;
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: Platform.isIOS ? InputImageRotation.rotation0deg : rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// One face, centred in the circle, big enough and bright enough.
  FaceGuidance _guidance(List<Face> faces, CameraImage image, InputImageRotation rotation) {
    final sideways = rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg;
    final w = (sideways ? image.height : image.width).toDouble();
    final h = (sideways ? image.width : image.height).toDouble();
    final big = faces.where((f) => f.boundingBox.width / w > 0.12).toList();
    if (big.isEmpty) return FaceGuidance.noFace;
    if (big.length > 1) return FaceGuidance.severalFaces;
    final box = big.first.boundingBox;
    if (box.width / w < 0.3) return FaceGuidance.comeCloser;
    if ((box.center.dx / w - 0.5).abs() > 0.16 || (box.center.dy / h - 0.48).abs() > 0.18) return FaceGuidance.centre;
    if (_brightness(image) < 0.22) return FaceGuidance.moreLight;
    return FaceGuidance.good;
  }

  /// Rough average brightness from a sparse grid of pixels.
  static double _brightness(CameraImage image) {
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final bgra = image.format.group == ImageFormatGroup.bgra8888;
    var total = 0, count = 0;
    final stepY = math.max(1, image.height ~/ 24), stepX = math.max(1, image.width ~/ 24);
    for (var y = image.height ~/ 4; y < image.height * 3 ~/ 4; y += stepY) {
      for (var x = image.width ~/ 4; x < image.width * 3 ~/ 4; x += stepX) {
        if (bgra) {
          final i = y * plane.bytesPerRow + x * 4;
          if (i + 2 >= bytes.length) continue;
          total += (bytes[i] * 114 + bytes[i + 1] * 587 + bytes[i + 2] * 299) ~/ 1000;
        } else {
          // NV21 / YUV: the first plane is brightness.
          final i = y * plane.bytesPerRow + x;
          if (i >= bytes.length) continue;
          total += bytes[i];
        }
        count++;
      }
    }
    return count == 0 ? 1 : total / count / 255;
  }

  @override
  void dispose() {
    stop();
    _detector.close();
    super.dispose();
  }
}

/// Lets a locked-down device fall back quietly: the platform reports no camera.
bool isCameraPermissionError(Object e) => e is PlatformException && e.code.toLowerCase().contains('permission');
