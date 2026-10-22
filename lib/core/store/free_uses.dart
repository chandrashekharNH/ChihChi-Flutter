import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/puzzle_models.dart';
import 'premium_access.dart';

/// Extra features that free players may try a few times before Full Adventure.
enum FreeFeature {
  /// Build the Picture's Free Play puzzles.
  freePlay,

  /// My Photo Puzzle (camera or photo library).
  photoPuzzle;

  /// Which feature a puzzle belongs to; adventure levels (with a level number) are not counted here.
  static FreeFeature? forPuzzle(PuzzleDefinition puzzle, int? level) {
    if (level != null) return null;
    return puzzle.id == PuzzleDefinition.photoPuzzleID ? FreeFeature.photoPuzzle : FreeFeature.freePlay;
  }
}

/// Counts free uses of each `FreeFeature` on this device (shared by all child profiles, so a new
/// profile doesn't start the count again). Full Adventure removes the limit.
class FreeUses extends ChangeNotifier {
  static const limit = 10;

  final Map<FreeFeature, int> _used = {};
  SharedPreferences? _prefs;

  Future<void> load([SharedPreferences? prefs]) async {
    _prefs = prefs ?? await SharedPreferences.getInstance();
    for (final feature in FreeFeature.values) {
      _used[feature] = _prefs!.getInt(_key(feature)) ?? 0;
    }
    notifyListeners();
  }

  int remaining(FreeFeature feature) => (limit - (_used[feature] ?? 0)).clamp(0, limit);

  bool allows(FreeFeature feature, EntitlementState state) => state.isPremium || remaining(feature) > 0;

  /// Call when a puzzle of `feature` starts. Nothing is counted after Full Adventure is bought.
  void recordUse(FreeFeature feature, EntitlementState state) {
    if (state.isPremium) return;
    final count = (_used[feature] ?? 0) + 1;
    _used[feature] = count;
    _prefs?.setInt(_key(feature), count);
    notifyListeners();
  }

  static String _key(FreeFeature feature) => 'freeUses.${feature.name}';
}
