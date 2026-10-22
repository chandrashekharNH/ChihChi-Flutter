import '../../domain/models/home_game.dart';

/// What a purchase unlocks. Today there is one product; a future expansion pack is a new value
/// here plus its features, with no change to the rules below.
enum PremiumProduct {
  fullAdventure('com.chihchi.fulladventure');

  const PremiumProduct(this.id);
  final String id;

  static Set<String> get allIDs => {for (final p in values) p.id};

  static PremiumProduct? fromID(String id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Whether this device has a verified purchase. Only `premium` ever unlocks anything:
/// `checking` (the store hasn't answered yet, e.g. first launch offline) plays like free.
enum EntitlementState {
  checking,
  free,
  premium;

  bool get isPremium => this == EntitlementState.premium;
}

/// The free/premium line for each game. Plain rules, no store code, so they are easy to test.
class PremiumAccess {
  /// How many levels of each game are free. Games not listed have no levels to lock.
  static int? freeLevels(HomeGame game) {
    switch (game) {
      case HomeGame.catchLetter:
      case HomeGame.catchWorld:
      case HomeGame.learnBlaster:
      case HomeGame.buildPicture:
      case HomeGame.turboRace:
      case HomeGame.arHunt:
        return 10;
    }
  }

  /// May the child play `level` of `game`?
  static bool allows(HomeGame game, int level, EntitlementState state) {
    if (state.isPremium) return true;
    final free = freeLevels(game);
    if (free == null) return true;
    return level <= free;
  }

  /// The last free level of `game`, after which the unlock prompt appears once.
  static int? lastFreeLevel(HomeGame game) => freeLevels(game);
}
