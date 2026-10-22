import 'dart:math' as math;

import '../../core/localization/localized.dart';
import '../../data/puzzle_content/puzzle_library.dart';
import '../../domain/models/app_language.dart';

// Content for AR Explorer's virtual play: animals placed in the room, the AR Adventure's worlds
// and treasures, and the items children collect for "My AR World". Names come from the shared
// Build the Picture vocabulary (`PuzzleLibrary`).

class ARExplorerAnimal {
  const ARExplorerAnimal({required this.id, required this.emoji, required this.names, required this.facts, this.call});
  final String id;
  final String emoji;
  final Map<AppLanguage, String> names;

  /// One short, true fact in every app language.
  final Map<AppLanguage, String> facts;

  /// The animal's call, spoken playfully when tapped. Null for quiet animals.
  final String? call;

  String name(AppLanguage language) => names[language] ?? names[AppLanguage.english] ?? id;
  String fact(AppLanguage language) => facts[language] ?? facts[AppLanguage.english] ?? '';
}

class ARExplorerWorldCatalog {
  /// Names in every language for a word in the shared vocabulary.
  static Map<AppLanguage, String> names(String wordID) => {
        for (final l in AppLanguage.values)
          if (PuzzleLibrary.puzzle(wordID, l) != null) l: PuzzleLibrary.puzzle(wordID, l)!.name(l),
      };

  static String? emoji(String wordID) => PuzzleLibrary.puzzle(wordID, AppLanguage.english)?.thumbnail;

  static final List<(String, Localized, String?)> _animalSpecs = [
    ('lion', L("Lions live in Africa, and in India's Gir forest."), 'Roooar!'),
    ('elephant', L('Elephants have a long trunk.'), 'Pawoo!'),
    ('giraffe', L('Giraffes have very long necks.'), null),
    ('tiger', L('Tigers have orange fur with black stripes.'), 'Grrrr!'),
    ('zebra', L('Zebras are black and white.'), null),
    ('monkey', L('Monkeys love to climb trees.'), 'Ooh ooh, aah aah!'),
    ('panda', L('Pandas love to eat bamboo.'), null),
    ('penguin', L('Penguins can swim, but they cannot fly.'), null),
  ];

  static final List<ARExplorerAnimal> animals = [
    for (final spec in _animalSpecs)
      if (emoji(spec.$1) != null)
        ARExplorerAnimal(id: spec.$1, emoji: emoji(spec.$1)!, names: names(spec.$1), facts: spec.$2.allLanguages(), call: spec.$3),
  ];

  static ARExplorerAnimal? animal(String id) => animals.where((a) => a.id == id).firstOrNull;

  /// The animal plus two others, shuffled, for "What animal is this?".
  static List<String> nameOptions(String id, math.Random random) {
    final others = (animals.map((a) => a.id).where((a) => a != id).toList()..shuffle(random)).take(2);
    return [id, ...others]..shuffle(random);
  }

  /// The item each Explorer Level adds to "My AR World" the first time it is finished.
  static const Map<int, String> levelRewards = {
    1: 'tree', 2: 'rainbow', 3: 'house', 4: 'rocket', 5: 'sunflower',
    6: 'glowingStar', 7: 'tent', 8: 'lion', 9: 'wave', 10: 'castle',
  };

  /// Every collectible, in level order.
  static List<String> get collectibleIDs => (levelRewards.keys.toList()..sort()).map((k) => levelRewards[k]!).toList();
}

/// The worlds behind the magic portal. Scenery is a handful of pictures stood around the portal.
enum ARAdventureWorld {
  forest('🌳', ['🌳', '🌲', '🍄', '🦋']),
  space('🚀', ['🪐', '🌙', '🛰️', '👽']),
  ocean('🌊', ['🐬', '🐠', '🐙', '🐚']),
  dinosaur('🦕', ['🦖', '🌋', '🌴', '🥚']),
  kingdom('🏰', ['🏰', '🦄', '👑', '🌈']);

  const ARAdventureWorld(this.emoji, this.scenery);
  final String emoji;
  final List<String> scenery;
}

/// Treasures hidden around the room in AR Adventure.
enum ARTreasure {
  star('⭐'),
  gem('💎'),
  candy('🍭'),
  key('🗝️'),
  gift('🎁');

  const ARTreasure(this.emoji);
  final String emoji;
}
