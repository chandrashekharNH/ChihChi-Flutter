import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../services/progress/child_profile_files.dart';
import 'avatar_appearance.dart';

/// Draws a small picture of a look (set by the character feature once it can paint).
typedef PortraitRenderer = Future<Uint8List?> Function(AvatarAppearance look);

/// The child's own character: whether it is on, the chosen look and a cached portrait. Saved as a
/// small JSON file plus a PNG on this device, so the shared `PlayerProgress` does not change. No
/// photo is ever stored here — only choices and the face measurements that go with them.
class PlayerCharacterStore extends ChangeNotifier {
  PlayerCharacterStore({Directory? directory, PortraitRenderer? renderPortrait})
      : _directory = directory ?? Directory('${ChildProfileFiles.activeDirectory.path}/Character'),
        _renderPortrait = renderPortrait ?? defaultRenderer {
    try {
      if (_file.existsSync()) {
        final saved = (jsonDecode(_file.readAsStringSync()) as Map).cast<String, dynamic>();
        _isEnabled = saved['isEnabled'] == true;
        _appearance = AvatarAppearance.fromJson((saved['appearance'] as Map).cast<String, dynamic>());
        _version = (saved['version'] as num?)?.toInt() ?? 0;
      }
      if (_portraitFile.existsSync()) portrait = _portraitFile.readAsBytesSync();
    } catch (_) {}
  }

  /// Set once at start-up by the character feature (it knows how to paint a look).
  static PortraitRenderer defaultRenderer = (_) async => null;

  final Directory _directory;
  final PortraitRenderer _renderPortrait;

  bool _isEnabled = false;
  AvatarAppearance _appearance = AvatarAppearance();
  int _version = 0;

  /// A PNG of the character's face, for small places (Parent Zone, lists).
  Uint8List? portrait;

  /// On: the child's character is the hero. Off (or never made): ChihChi is, as always.
  bool get isEnabled => _isEnabled;
  AvatarAppearance get appearance => _appearance;

  /// Bumped on every save, so views showing the character know to refresh.
  int get version => _version;

  /// A character was made at some point (it may be turned off now).
  bool get hasCharacter => _version > 0;

  File get _file => File('${_directory.path}/character.json');
  File get _portraitFile => File('${_directory.path}/portrait.png');

  /// "Use This Character": saves the look, switches it on and redraws the portrait.
  Future<void> save(AvatarAppearance look) async {
    _appearance = look.copy();
    _isEnabled = true;
    _version += 1;
    _write();
    notifyListeners();
    final image = await _renderPortrait(look);
    if (image != null) _storePortrait(image);
  }

  /// Back to ChihChi as the hero; the look is kept for later.
  void turnOff() {
    _isEnabled = false;
    _write();
    notifyListeners();
  }

  void turnOn() {
    if (!hasCharacter) return;
    _isEnabled = true;
    _write();
    notifyListeners();
  }

  /// Forgets the character entirely (Parent Zone, or "restore default").
  void deleteEverything() {
    try {
      if (_file.existsSync()) _file.deleteSync();
      if (_portraitFile.existsSync()) _portraitFile.deleteSync();
    } catch (_) {}
    _isEnabled = false;
    _appearance = AvatarAppearance();
    _version = 0;
    portrait = null;
    notifyListeners();
  }

  void _write() {
    try {
      _directory.createSync(recursive: true);
      _file.writeAsStringSync(
          jsonEncode({'isEnabled': _isEnabled, 'appearance': _appearance.toJson(), 'version': _version}),
          flush: true);
    } catch (_) {
      // Stays in memory for this session; the game keeps working.
    }
  }

  void _storePortrait(Uint8List image) {
    portrait = image;
    try {
      _directory.createSync(recursive: true);
      _portraitFile.writeAsBytesSync(image, flush: true);
    } catch (_) {}
    notifyListeners();
  }
}
