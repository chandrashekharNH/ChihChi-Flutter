import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/kid_text.dart';
import '../../core/ui/palette.dart';
import '../../domain/models/ui_text.dart';
import '../../game/puzzle/puzzle_art_renderer.dart';
import '../../services/audio/audio_service.dart';

/// "My Photo Puzzle": the child takes a photo (or picks one) and plays it as a puzzle. The photo
/// is only held in memory for the puzzle and is never saved or shared.
class PhotoPuzzleCard extends StatefulWidget {
  const PhotoPuzzleCard({super.key, this.isCompact = false, this.isLocked = false, this.onLocked, required this.onPhoto});

  /// A single slim row (icons only) instead of the full card.
  final bool isCompact;

  /// Part of Full Adventure and not unlocked: the buttons show 👑 and call `onLocked` instead.
  final bool isLocked;
  final VoidCallback? onLocked;
  final void Function(ui.Image photo) onPhoto;

  @override
  State<PhotoPuzzleCard> createState() => _PhotoPuzzleCardState();
}

class _PhotoPuzzleCardState extends State<PhotoPuzzleCard> {
  bool _preparing = false;

  Future<void> _pick(ImageSource source) async {
    context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
    if (widget.isLocked) {
      widget.onLocked?.call();
      return;
    }
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: PuzzleArtRenderer.pixelSize, maxHeight: PuzzleArtRenderer.pixelSize);
      if (file == null) return;
      setState(() => _preparing = true);
      final image = await _prepared(await file.readAsBytes());
      if (!mounted) return;
      setState(() => _preparing = false);
      if (image != null) widget.onPhoto(image);
    } catch (_) {
      if (mounted) setState(() => _preparing = false);
    }
  }

  /// Shrinks photos to the puzzle's canvas size (orientation is already applied by the picker).
  static Future<ui.Image?> _prepared(List<int> bytes) async {
    try {
      final data = ui.ImmutableBuffer.fromUint8List(Uint8List.fromList(bytes));
      final descriptor = await ui.ImageDescriptor.encoded(await data);
      final longest = math.max(descriptor.width, descriptor.height).toDouble();
      final scale = longest > PuzzleArtRenderer.pixelSize ? PuzzleArtRenderer.pixelSize / longest : 1.0;
      final codec = await descriptor.instantiateCodec(
          targetWidth: (descriptor.width * scale).round(), targetHeight: (descriptor.height * scale).round());
      return (await codec.getNextFrame()).image;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    Widget pill(String title, IconData icon, ImageSource source) => Semantics(
          button: true,
          label: title,
          child: GestureDetector(
            onTap: _preparing ? null : () => _pick(source),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: widget.isCompact ? 8 : 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: rgb(0.85, 0.3, 0.35)),
                if (!widget.isCompact) ...[const SizedBox(width: 6), Text(title, style: kid(15, color: rgb(0.85, 0.3, 0.35)))],
              ]),
            ),
          ),
        );
    final buttons = Row(mainAxisSize: MainAxisSize.min, children: [
      if (widget.isLocked) ...[const Text('👑', style: TextStyle(fontSize: 18)), const SizedBox(width: 8)],
      pill(UIText.takePhoto.resolve(language), Icons.photo_camera, ImageSource.camera),
      const SizedBox(width: 8),
      pill(UIText.choosePhoto.resolve(language), Icons.photo_library, ImageSource.gallery),
      if (_preparing) ...[const SizedBox(width: 8), const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))],
    ]);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.isCompact ? 10 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [rgb(1, 0.45, 0.55), rgb(1, 0.65, 0.2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
      ),
      child: widget.isCompact
          ? Row(children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(UIText.myPhotoPuzzle.resolve(language), style: kid(16, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 4),
              buttons,
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(UIText.myPhotoPuzzle.resolve(language), style: kid(18, color: Colors.white)),
              const SizedBox(height: 10),
              Text(UIText.myPhotoPuzzleSubtitle.resolve(language), style: kid(13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
              const SizedBox(height: 10),
              buttons,
            ]),
    );
  }
}
