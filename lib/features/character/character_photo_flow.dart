import 'dart:io';
import 'package:chihchi/core/ui/emoji_text.dart';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/kid_text.dart';
import '../../core/ui/palette.dart';
import '../../domain/models/app_language.dart';
import '../../services/audio/audio_service.dart';
import '../parent/parent_gate_view.dart';
import 'avatar_appearance.dart';
import 'character_text.dart';
import 'face_capture_model.dart';
import 'face_feature_reader.dart';

enum _Step { gate, intro, camera, confirm, creating, failed, noCamera }

/// "From my photo": grown-up check → why we want a photo → front camera with a circle guide →
/// "Is this a good photo?" → a playful moment while the face is read on the device → back to the
/// studio with colours filled in and the face drawn to the child's own measurements. The photo is
/// dropped at the end, whatever happens; popping with null means "carry on without it".
class CharacterPhotoFlow extends StatefulWidget {
  const CharacterPhotoFlow({super.key, required this.start});
  final AvatarAppearance start;

  @override
  State<CharacterPhotoFlow> createState() => _CharacterPhotoFlowState();
}

class _CharacterPhotoFlowState extends State<CharacterPhotoFlow> with SingleTickerProviderStateMixin {
  _Step _step = _Step.gate;
  final _camera = FaceCaptureModel();
  String? _photo;
  FaceReadFailure? _failure;
  int _stage = 0;
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    _camera.addListener(() => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _camera.dispose();
    _spin.dispose();
    _dropPhoto();
    super.dispose();
  }

  void _dropPhoto() {
    final p = _photo;
    _photo = null;
    if (p != null) {
      try {
        File(p).deleteSync();
      } catch (_) {}
    }
  }

  void _finish(AvatarAppearance? result) {
    _camera.stop();
    _dropPhoto();
    Navigator.of(context).pop(result);
  }

  Future<void> _startCamera() async {
    setState(() => _step = _Step.camera);
    await _camera.start();
    if (!mounted) return;
    if (_camera.state == CaptureState.denied || _camera.state == CaptureState.unavailable) {
      setState(() => _step = _Step.noCamera);
    }
  }

  Future<void> _capture() async {
    if (_camera.guidance != FaceGuidance.good) return;
    context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
    final path = await _camera.capture();
    await _camera.stop();
    if (!mounted) return;
    if (path == null) {
      setState(() => _step = _Step.noCamera);
      return;
    }
    _dropPhoto();
    setState(() {
      _photo = path;
      _step = _Step.confirm;
    });
  }

  /// Reads the face while the loader plays (kept playful even though reading is quick), then hands
  /// back only choices and measurements.
  Future<void> _create() async {
    final photo = _photo;
    if (photo == null) return;
    setState(() {
      _step = _Step.creating;
      _stage = 0;
    });
    if (!MediaQuery.of(context).disableAnimations) _spin.repeat();
    final result = await FaceFeatureReader.read(photo);
    _dropPhoto();
    for (var next = 1; next <= 3; next++) {
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() => _stage = next);
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _spin.stop();
    final hints = result.hints;
    if (hints != null) {
      context.read<AppState>().audioService.playEffect(SoundEffect.levelComplete);
      _finish(hints.appliedTo(widget.start));
    } else {
      setState(() {
        _failure = result.failure;
        _step = _Step.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    if (_step == _Step.gate) {
      return ParentGateView(onSuccess: () => setState(() => _step = _Step.intro), onClose: () => _finish(null));
    }
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [rgb(0.55, 0.78, 1), rgb(0.72, 0.6, 1)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(key: ValueKey(_step), child: _body(language)),
          ),
        ),
      ),
    );
  }

  Widget _body(AppLanguage language) {
    switch (_step) {
      case _Step.gate:
        return const SizedBox.shrink();
      case _Step.intro:
        return _message(CharacterText.letsCreate.resolve(language), '🎨', CharacterText.letsCreateSubtitle.resolve(language), [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
            child: Text('🔒 ${CharacterText.photoPrivacyNote.resolve(language)}',
                textAlign: TextAlign.center,
                style: kid(13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
          ),
          _big('📸 ${CharacterText.takePhoto.resolve(language)}', Colors.green, _startCamera),
          _small(CharacterText.maybeLater.resolve(language), () => _finish(null)),
        ]);
      case _Step.camera:
        return _cameraScreen(language);
      case _Step.confirm:
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Text(CharacterText.isThisGood.resolve(language), textAlign: TextAlign.center, style: kid(26, color: Colors.white)),
              const SizedBox(height: 18),
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5)),
                child: ClipOval(
                  child: _photo == null
                      ? const SizedBox()
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.diagonal3Values(-1, 1, 1),
                          child: Image.file(File(_photo!), fit: BoxFit.cover),
                        ),
                ),
              ),
              const SizedBox(height: 18),
              _big(CharacterText.useThisPhoto.resolve(language), Colors.green, _create),
              _big(CharacterText.retake.resolve(language), Colors.orange, () {
                _dropPhoto();
                _startCamera();
              }),
              _small(CharacterText.cancel.resolve(language), () => _finish(null)),
            ]),
          ),
        );
      case _Step.creating:
        final lines = [
          CharacterText.lookingAtPhoto,
          CharacterText.designing,
          CharacterText.addingStyle,
          CharacterText.gettingReady,
        ];
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(CharacterText.creating.resolve(language), style: kid(26, color: Colors.white)),
            const SizedBox(height: 20),
            ExcludeSemantics(
              child: SizedBox(
                width: 140,
                height: 140,
                child: RotationTransition(
                  turns: _spin,
                  child: Stack(alignment: Alignment.center, children: [
                    for (var i = 0; i < 6; i++)
                      Transform.rotate(
                        angle: i * math.pi / 3,
                        child: Transform.translate(
                          offset: const Offset(0, -55),
                          child: EmojiText(['✨', '🎨', '⭐', '💫', '🌈', '🎉'][i], size: 30),
                        ),
                      ),
                    const EmojiText('🐼', size: 54),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(lines[math.min(_stage, lines.length - 1)].resolve(language),
                  key: ValueKey(_stage), style: kid(18, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
            ),
          ]),
        );
      case _Step.failed:
        final tip = switch (_failure) {
          FaceReadFailure.severalFaces => CharacterText.oneFacePlease,
          FaceReadFailure.tooDark => CharacterText.moreLight,
          _ => CharacterText.oopsFaceHelp,
        };
        return _message(CharacterText.oopsFace.resolve(language), '🙈', tip.resolve(language), [
          _big(CharacterText.tryAgain.resolve(language), Colors.green, _startCamera),
          _big(CharacterText.makeItMyself.resolve(language), Colors.orange, () => _finish(null)),
          _small(CharacterText.skip.resolve(language), () => _finish(null)),
        ]);
      case _Step.noCamera:
        return _message(CharacterText.oopsNoCamera.resolve(language), '📷', null, [
          _big(CharacterText.makeItMyself.resolve(language), Colors.green, () => _finish(null)),
        ]);
    }
  }

  Widget _cameraScreen(AppLanguage language) {
    final good = _camera.guidance == FaceGuidance.good;
    final text = switch (_camera.guidance) {
      FaceGuidance.noFace || FaceGuidance.centre => CharacterText.putFaceInCircle,
      FaceGuidance.severalFaces => CharacterText.oneFacePlease,
      FaceGuidance.comeCloser => CharacterText.comeCloser,
      FaceGuidance.moreLight => CharacterText.moreLight,
      FaceGuidance.good => CharacterText.looksGreat,
    };
    final controller = _camera.controller;
    return Center(
      child: SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 56,
              child: Center(
                child: Text(text.resolve(language), textAlign: TextAlign.center, style: kid(20, color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 290,
            height: 290,
            child: Stack(fit: StackFit.expand, children: [
              ClipOval(
                child: controller != null && controller.value.isInitialized
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller.value.previewSize?.height ?? 290,
                          height: controller.value.previewSize?.width ?? 290,
                          child: CameraPreview(controller),
                        ),
                      )
                    : const ColoredBox(color: Colors.black),
              ),
              IgnorePointer(
                child: CustomPaint(painter: _GuideRingPainter(good)),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          Semantics(
            button: true,
            enabled: good,
            label: CharacterText.takePhoto.resolve(language),
            child: GestureDetector(
              onTap: good ? _capture : null,
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: good ? Colors.white : Colors.white.withValues(alpha: 0.4),
                  border: Border.all(color: good ? Colors.green : Colors.transparent, width: 6),
                ),
                child: const Text('📸', style: TextStyle(fontSize: 34)),
              ),
            ),
          ),
          _small(CharacterText.cancel.resolve(language), () => _finish(null)),
        ]),
      ),
    );
  }

  Widget _message(String title, String emoji, String? detail, List<Widget> buttons) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              Text(emoji, style: const TextStyle(fontSize: 80)),
              const SizedBox(height: 18),
              Text(title, textAlign: TextAlign.center, style: kid(26, color: Colors.white)),
              if (detail != null) ...[
                const SizedBox(height: 18),
                Text(detail,
                    textAlign: TextAlign.center,
                    style: kid(17, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.92))),
              ],
              for (final b in buttons) ...[const SizedBox(height: 18), b],
            ]),
          ),
        ),
      );

  Widget _big(String title, Color colour, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Semantics(
          button: true,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(40),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Text(title, textAlign: TextAlign.center, style: kid(20, color: Colors.white)),
            ),
          ),
        ),
      );

  Widget _small(String title, VoidCallback onTap) =>
      TextButton(onPressed: onTap, child: Text(title, style: kid(17, weight: FontWeight.w700, color: Colors.white)));
}

/// A dashed ring that turns solid green when the face is just right.
class _GuideRingPainter extends CustomPainter {
  _GuideRingPainter(this.good);
  final bool good;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = good ? Colors.green : Colors.white;
    final rect = Offset.zero & size;
    final r = size.shortestSide / 2 - 4;
    if (good) {
      canvas.drawCircle(rect.center, r, paint);
      return;
    }
    const dashes = 36;
    for (var i = 0; i < dashes; i++) {
      final start = i * 2 * math.pi / dashes;
      canvas.drawArc(Rect.fromCircle(center: rect.center, radius: r), start, 2 * math.pi / dashes * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_GuideRingPainter old) => old.good != good;
}
