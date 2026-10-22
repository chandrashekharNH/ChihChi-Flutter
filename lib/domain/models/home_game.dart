import 'dart:ui';

import '../../core/ui/palette.dart';

/// Every playable game, each with its own tile colours. Titles live in the home feature
/// (`HomeGameText`), which knows every game's text.
enum HomeGame {
  catchLetter('🔤'),
  catchWorld('🌍'),
  learnBlaster('🚀'),
  buildPicture('🧩'),
  arHunt('🌎'),
  turboRace('🏎️');

  const HomeGame(this.icon);
  final String icon;

  /// Saved name, same as iOS's raw value.
  String get rawValue => name;

  static HomeGame? fromRaw(String? raw) {
    for (final g in values) {
      if (g.name == raw) return g;
    }
    return null;
  }

  List<Color> get colors {
    switch (this) {
      case HomeGame.catchLetter:
        return [rgb(1.0, 0.55, 0.3), rgb(0.93, 0.25, 0.45)];
      case HomeGame.catchWorld:
        return [rgb(0.3, 0.8, 0.55), rgb(0.1, 0.55, 0.7)];
      case HomeGame.learnBlaster:
        return [rgb(0.4, 0.6, 1.0), rgb(0.45, 0.3, 0.9)];
      case HomeGame.buildPicture:
        return [rgb(1.0, 0.78, 0.2), rgb(1.0, 0.45, 0.2)];
      case HomeGame.arHunt:
        return [rgb(0.85, 0.45, 0.95), rgb(0.55, 0.25, 0.8)];
      case HomeGame.turboRace:
        return [rgb(1.0, 0.4, 0.3), rgb(0.2, 0.25, 0.6)];
    }
  }
}
