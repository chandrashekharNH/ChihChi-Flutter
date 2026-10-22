// Renders sample characters to PNG files for a visual check (not part of the normal suite):
//   flutter test test/visual/render_character_test.dart --dart-define=OUT=/some/folder
import 'dart:io';
import 'dart:ui' as ui;

import 'package:chihchi/features/character/avatar_appearance.dart';
import 'package:chihchi/features/character/character_model.dart';
import 'package:chihchi/features/character/character_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const out = String.fromEnvironment('OUT');
  test('render characters', () async {
    if (out.isEmpty) return;
    final looks = {
      'default': AvatarAppearance(),
      'girl': AvatarAppearance(hairStyle: HairStyle.ponytail, top: Top.dress, topColor: Outfit.pink, hat: Hat.bow, eyes: Eyes.sparkle, skinTone: SkinTone.brown),
      'boy': AvatarAppearance(hairStyle: HairStyle.spiky, top: Top.hoodie, bottoms: Bottoms.pants, glasses: Glasses.round, hat: Hat.cap, backpack: true),
      'curly': AvatarAppearance(hairStyle: HairStyle.curly, hairColor: HairColor.ginger, top: Top.jersey, glasses: Glasses.star, skinTone: SkinTone.porcelain),
    };
    for (final entry in looks.entries) {
      for (final (yaw, pose) in [(0.0, CharacterAnimation.idle), (0.7, CharacterAnimation.wave), (3.1, CharacterAnimation.idle)]) {
        final rig = CharacterModel.build(entry.value);
        poseCharacter(rig, pose, 0.6);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 360), Paint()..color = const Color(0xFF8FD3FF));
        CharacterPainter(rig, yaw: yaw).paint(canvas, const Size(300, 360));
        final image = await recorder.endRecording().toImage(300, 360);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/${entry.key}_${yaw.toStringAsFixed(1)}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    }
  });
}
