import 'dart:math' as math;

import '../../core/localization/content_names.dart';
import '../../core/localization/localized.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/puzzle_models.dart';
import '../../domain/models/run_collect.dart';
import '../game_content/run_collect_content.dart';

class _Item {
  const _Item(this.id, this.emoji, this.en, this.kn, this.hi);
  final String id, emoji, en, kn, hi;
}

/// Puzzle and world for an adventure level.
class AdventureLevel {
  const AdventureLevel(this.puzzle, this.world, this.step);
  final PuzzleDefinition puzzle;
  final PuzzleWorld world;
  final int step;
}

/// Every "Build the Picture" puzzle. Pictures are drawn at runtime from this data
/// (see `PuzzleArtRenderer`), so adding a puzzle is adding a row here.
class PuzzleLibrary {
  static const totalLevels = 100;

  /// All puzzles for a language (letters follow that language's alphabet).
  static List<PuzzleDefinition> all(AppLanguage language) => _catalog(language).all;

  static List<PuzzleDefinition> puzzles(PuzzleCategory category, AppLanguage language) =>
      all(language).where((p) => p.category == category).toList();

  static PuzzleDefinition? puzzle(String id, AppLanguage language) => _catalog(language).byID[id];

  static final Map<AppLanguage, ({List<PuzzleDefinition> all, Map<String, PuzzleDefinition> byID})> _catalogs = {};

  static ({List<PuzzleDefinition> all, Map<String, PuzzleDefinition> byID}) _catalog(AppLanguage language) =>
      _catalogs.putIfAbsent(language, () {
        final all = [..._objectPuzzles, ..._scenePuzzles, ..._letterPuzzles(language), ..._numberPuzzles, ..._colorPuzzles, ..._wordPuzzles];
        final byID = <String, PuzzleDefinition>{};
        for (final p in all) {
          byID.putIfAbsent(p.id, () => p);
        }
        return (all: all, byID: byID);
      });

  /// The 10 adventure worlds (10 puzzles each) for a language.
  static List<PuzzleWorld> worlds(AppLanguage language) {
    final letterIDs = _letterPuzzles(language).take(10).map((p) => p.id).toList();
    return [
      const PuzzleWorld(id: 1, category: PuzzleCategory.animals, puzzleIDs: [
        'cat', 'dog', 'rabbit', 'lion', 'elephant', 'monkey', 'giraffe', 'panda', 'scene.farm', 'scene.zoo']),
      const PuzzleWorld(id: 2, category: PuzzleCategory.nature, puzzleIDs: [
        'sun', 'flower', 'tree', 'rainbow', 'sunflower',
        'scene.rainbowMeadow', 'scene.garden', 'scene.snowyDay', 'scene.mountainSunrise', 'scene.nightSky']),
      const PuzzleWorld(id: 3, category: PuzzleCategory.vehicles, puzzleIDs: [
        'car', 'bus', 'steamTrain', 'airplane', 'fireTruck', 'helicopter', 'ship',
        'scene.cityStreet', 'scene.airport', 'scene.harbour']),
      const PuzzleWorld(id: 4, category: PuzzleCategory.food, puzzleIDs: [
        'apple', 'banana', 'mango', 'watermelon', 'pizza', 'cake', 'iceCream',
        'scene.fruitBasket', 'scene.picnic', 'scene.birthday']),
      const PuzzleWorld(id: 5, category: PuzzleCategory.space, puzzleIDs: [
        'moon', 'star', 'earth', 'planet', 'rocket', 'astronaut',
        'scene.solarSystem', 'scene.rocketLaunch', 'scene.moonwalk', 'scene.ufoVisit']),
      const PuzzleWorld(id: 6, category: PuzzleCategory.dinosaurs, puzzleIDs: [
        'tRex', 'longNeck', 'scene.dinoFriends', 'scene.tRexJungle', 'scene.longNeckLake',
        'scene.dinoEggs', 'scene.volcanoValley', 'scene.fossilDig', 'scene.dinoBeach', 'scene.dinoNight']),
      PuzzleWorld(id: 7, category: PuzzleCategory.letters, puzzleIDs: letterIDs),
      PuzzleWorld(id: 8, category: PuzzleCategory.numbers, puzzleIDs: [for (var i = 1; i <= 10; i++) 'number.$i']),
      PuzzleWorld(
          id: 9, category: PuzzleCategory.colors, puzzleIDs: PuzzleColor.values.take(10).map((c) => 'color.${c.name}').toList()),
      const PuzzleWorld(id: 10, category: PuzzleCategory.india, puzzleIDs: [
        'diya', 'temple', 'scene.indianVillage', 'scene.diwali', 'scene.kiteFestival',
        'scene.peacockGarden', 'scene.lotusPond', 'scene.indianTrain', 'scene.cricketMatch', 'scene.elephantFestival']),
    ];
  }

  /// Puzzle and world for an adventure level (1…100).
  static AdventureLevel? adventure(int requested, AppLanguage language) {
    final level = math.max(1, math.min(requested, totalLevels));
    final ws = worlds(language);
    final world = ws[(level - 1) ~/ PuzzleWorld.puzzlesPerWorld];
    final step = (level - 1) % PuzzleWorld.puzzlesPerWorld;
    if (step >= world.puzzleIDs.length) return null;
    final p = puzzle(world.puzzleIDs[step], language);
    if (p == null) return null;
    return AdventureLevel(p, world, step);
  }

  /// Next puzzle to play: the next adventure level, or another puzzle from the same category.
  static (PuzzleDefinition, int?)? next(PuzzleDefinition puzzle, int? level, AppLanguage language) {
    if (level != null) {
      if (level >= totalLevels) return null;
      final n = adventure(level + 1, language);
      return n == null ? null : (n.puzzle, level + 1);
    }
    final others = puzzles(puzzle.category, language).where((p) => p.id != puzzle.id).toList();
    if (others.isEmpty) return null;
    return (others[math.Random().nextInt(others.length)], null);
  }

  /// The same puzzle in another language. Letter puzzles map to the letter at the same position
  /// in that language's alphabet; everything else is shared.
  static PuzzleDefinition? equivalent(PuzzleDefinition puzzle, AppLanguage language) {
    if (puzzle.category != PuzzleCategory.letters) return PuzzleLibrary.puzzle(puzzle.id, language);
    var source = <PuzzleDefinition>[];
    for (final l in AppLanguage.values) {
      final list = _letterPuzzles(l);
      if (list.contains(puzzle)) {
        source = list;
        break;
      }
    }
    final target = _letterPuzzles(language);
    final index = source.indexOf(puzzle);
    if (index < 0 || target.isEmpty) return target.isEmpty ? null : target.first;
    return target[math.min(index, target.length - 1)];
  }

  // Objects (one big picture)

  static const List<(PuzzleCategory, PuzzleBackdrop, List<_Item>)> _items = [
    (PuzzleCategory.animals, PuzzleBackdrop.meadow, [
      _Item('lion', '🦁', 'Lion', 'ಸಿಂಹ', 'शेर'),
      _Item('tiger', '🐯', 'Tiger', 'ಹುಲಿ', 'बाघ'),
      _Item('elephant', '🐘', 'Elephant', 'ಆನೆ', 'हाथी'),
      _Item('giraffe', '🦒', 'Giraffe', 'ಜಿರಾಫೆ', 'जिराफ़'),
      _Item('zebra', '🦓', 'Zebra', 'ಜೀಬ್ರಾ', 'ज़ेब्रा'),
      _Item('monkey', '🐒', 'Monkey', 'ಕೋತಿ', 'बंदर'),
      _Item('gorilla', '🦍', 'Gorilla', 'ಗೊರಿಲ್ಲಾ', 'गोरिल्ला'),
      _Item('panda', '🐼', 'Panda', 'ಪಾಂಡಾ', 'पांडा'),
      _Item('bear', '🐻', 'Bear', 'ಕರಡಿ', 'भालू'),
      _Item('polarBear', '🐻‍❄️', 'Polar Bear', 'ಹಿಮ ಕರಡಿ', 'ध्रुवीय भालू'),
      _Item('koala', '🐨', 'Koala', 'ಕೋಆಲಾ', 'कोआला'),
      _Item('fox', '🦊', 'Fox', 'ನರಿ', 'लोमड़ी'),
      _Item('wolf', '🐺', 'Wolf', 'ತೋಳ', 'भेड़िया'),
      _Item('deer', '🦌', 'Deer', 'ಜಿಂಕೆ', 'हिरण'),
      _Item('kangaroo', '🦘', 'Kangaroo', 'ಕಾಂಗರೂ', 'कंगारू'),
      _Item('horse', '🐴', 'Horse', 'ಕುದುರೆ', 'घोड़ा'),
      _Item('unicorn', '🦄', 'Unicorn', 'ಯೂನಿಕಾರ್ನ್', 'यूनिकॉर्न'),
      _Item('cow', '🐄', 'Cow', 'ಹಸು', 'गाय'),
      _Item('ox', '🐂', 'Ox', 'ಎತ್ತು', 'बैल'),
      _Item('buffalo', '🐃', 'Buffalo', 'ಎಮ್ಮೆ', 'भैंस'),
      _Item('pig', '🐷', 'Pig', 'ಹಂದಿ', 'सूअर'),
      _Item('goat', '🐐', 'Goat', 'ಮೇಕೆ', 'बकरी'),
      _Item('sheep', '🐑', 'Sheep', 'ಕುರಿ', 'भेड़'),
      _Item('camel', '🐫', 'Camel', 'ಒಂಟೆ', 'ऊँट'),
      _Item('llama', '🦙', 'Llama', 'ಲಾಮಾ', 'लामा'),
      _Item('rabbit', '🐰', 'Rabbit', 'ಮೊಲ', 'खरगोश'),
      _Item('mouse', '🐭', 'Mouse', 'ಇಲಿ', 'चूहा'),
      _Item('hamster', '🐹', 'Hamster', 'ಹ್ಯಾಮ್ಸ್ಟರ್', 'हैम्स्टर'),
      _Item('squirrel', '🐿️', 'Squirrel', 'ಅಳಿಲು', 'गिलहरी'),
      _Item('hedgehog', '🦔', 'Hedgehog', 'ಮುಳ್ಳುಹಂದಿ', 'साही'),
      _Item('bat', '🦇', 'Bat', 'ಬಾವಲಿ', 'चमगादड़'),
      _Item('dog', '🐶', 'Dog', 'ನಾಯಿ', 'कुत्ता'),
      _Item('cat', '🐱', 'Cat', 'ಬೆಕ್ಕು', 'बिल्ली'),
      _Item('rhino', '🦏', 'Rhino', 'ಘೇಂಡಾಮೃಗ', 'गैंडा'),
      _Item('hippo', '🦛', 'Hippo', 'ನೀರುಕುದುರೆ', 'दरियाई घोड़ा'),
      _Item('leopard', '🐆', 'Leopard', 'ಚಿರತೆ', 'तेंदुआ'),
      _Item('sloth', '🦥', 'Sloth', 'ಸ್ಲಾತ್', 'स्लॉथ'),
      _Item('otter', '🦦', 'Otter', 'ನೀರುನಾಯಿ', 'ऊदबिलाव'),
      _Item('skunk', '🦨', 'Skunk', 'ಸ್ಕಂಕ್', 'स्कंक'),
      _Item('beaver', '🦫', 'Beaver', 'ಬೀವರ್', 'बीवर'),
      _Item('bison', '🦬', 'Bison', 'ಕಾಡುಕೋಣ', 'बाइसन'),
      _Item('mammoth', '🦣', 'Mammoth', 'ಮ್ಯಾಮತ್', 'मैमथ'),
      _Item('orangutan', '🦧', 'Orangutan', 'ಒರಾಂಗುಟಾನ್', 'ओरंगुटान'),
      _Item('frog', '🐸', 'Frog', 'ಕಪ್ಪೆ', 'मेंढक'),
      _Item('turtle', '🐢', 'Turtle', 'ಆಮೆ', 'कछुआ'),
      _Item('snake', '🐍', 'Snake', 'ಹಾವು', 'साँप'),
      _Item('lizard', '🦎', 'Lizard', 'ಹಲ್ಲಿ', 'छिपकली'),
      _Item('crocodile', '🐊', 'Crocodile', 'ಮೊಸಳೆ', 'मगरमच्छ'),
      _Item('snail', '🐌', 'Snail', 'ಬಸವನಹುಳು', 'घोंघा'),
      _Item('butterfly', '🦋', 'Butterfly', 'ಚಿಟ್ಟೆ', 'तितली'),
      _Item('bee', '🐝', 'Bee', 'ಜೇನುಹುಳು', 'मधुमक्खी'),
      _Item('ladybug', '🐞', 'Ladybug', 'ಲೇಡಿಬಗ್', 'लेडीबग'),
      _Item('ant', '🐜', 'Ant', 'ಇರುವೆ', 'चींटी'),
      _Item('beetle', '🪲', 'Beetle', 'ದುಂಬಿ', 'भृंग'),
      _Item('caterpillar', '🐛', 'Caterpillar', 'ಕಂಬಳಿಹುಳು', 'इल्ली'),
      _Item('cricketBug', '🦗', 'Cricket', 'ಮಿಡತೆ', 'झींगुर'),
      _Item('worm', '🪱', 'Worm', 'ಎರೆಹುಳು', 'केंचुआ'),
      _Item('bird', '🐦', 'Bird', 'ಹಕ್ಕಿ', 'चिड़िया'),
      _Item('parrot', '🦜', 'Parrot', 'ಗಿಳಿ', 'तोता'),
      _Item('peacock', '🦚', 'Peacock', 'ನವಿಲು', 'मोर'),
      _Item('owl', '🦉', 'Owl', 'ಗೂಬೆ', 'उल्लू'),
      _Item('eagle', '🦅', 'Eagle', 'ಹದ್ದು', 'चील'),
      _Item('duck', '🦆', 'Duck', 'ಬಾತುಕೋಳಿ', 'बत्तख'),
      _Item('swan', '🦢', 'Swan', 'ಹಂಸ', 'हंस'),
      _Item('flamingo', '🦩', 'Flamingo', 'ಫ್ಲೆಮಿಂಗೋ', 'राजहंस'),
      _Item('penguin', '🐧', 'Penguin', 'ಪೆಂಗ್ವಿನ್', 'पेंगुइन'),
      _Item('chicken', '🐔', 'Chicken', 'ಕೋಳಿ', 'मुर्गी'),
      _Item('rooster', '🐓', 'Rooster', 'ಹುಂಜ', 'मुर्गा'),
      _Item('chick', '🐤', 'Chick', 'ಕೋಳಿಮರಿ', 'चूज़ा'),
      _Item('turkey', '🦃', 'Turkey', 'ಟರ್ಕಿ ಕೋಳಿ', 'टर्की'),
      _Item('dove', '🕊️', 'Dove', 'ಪಾರಿವಾಳ', 'कबूतर'),
      _Item('fish', '🐟', 'Fish', 'ಮೀನು', 'मछली'),
      _Item('tropicalFish', '🐠', 'Tropical Fish', 'ಬಣ್ಣದ ಮೀನು', 'रंगीन मछली'),
      _Item('pufferFish', '🐡', 'Puffer Fish', 'ಪಫರ್ ಮೀನು', 'पफ़र मछली'),
      _Item('shark', '🦈', 'Shark', 'ಶಾರ್ಕ್', 'शार्क'),
      _Item('dolphin', '🐬', 'Dolphin', 'ಡಾಲ್ಫಿನ್', 'डॉल्फ़िन'),
      _Item('whale', '🐳', 'Whale', 'ತಿಮಿಂಗಿಲ', 'व्हेल'),
      _Item('octopus', '🐙', 'Octopus', 'ಅಷ್ಟಪದಿ', 'ऑक्टोपस'),
      _Item('crab', '🦀', 'Crab', 'ಏಡಿ', 'केकड़ा'),
      _Item('lobster', '🦞', 'Lobster', 'ಲಾಬ್‌ಸ್ಟರ್', 'लॉबस्टर'),
      _Item('shrimp', '🦐', 'Shrimp', 'ಸೀಗಡಿ', 'झींगा'),
      _Item('squid', '🦑', 'Squid', 'ಸ್ಕ್ವಿಡ್', 'स्क्विड'),
      _Item('seal', '🦭', 'Seal', 'ಸೀಲ್', 'सील'),
      _Item('jellyfish', '🪼', 'Jellyfish', 'ಜೆಲ್ಲಿ ಮೀನು', 'जेलीफ़िश'),
      _Item('shell', '🐚', 'Shell', 'ಕಪ್ಪೆಚಿಪ್ಪು', 'सीप'),
      _Item('coral', '🪸', 'Coral', 'ಹವಳ', 'मूंगा'),
    ]),
    (PuzzleCategory.nature, PuzzleBackdrop.sky, [
      _Item('tree', '🌳', 'Tree', 'ಮರ', 'पेड़'),
      _Item('pineTree', '🌲', 'Pine Tree', 'ಪೈನ್ ಮರ', 'चीड़ का पेड़'),
      _Item('palmTree', '🌴', 'Palm Tree', 'ತಾಳೆ ಮರ', 'ताड़ का पेड़'),
      _Item('cactus', '🌵', 'Cactus', 'ಕಳ್ಳಿ ಗಿಡ', 'कैक्टस'),
      _Item('flower', '🌸', 'Flower', 'ಹೂವು', 'फूल'),
      _Item('rose', '🌹', 'Rose', 'ಗುಲಾಬಿ', 'गुलाब'),
      _Item('sunflower', '🌻', 'Sunflower', 'ಸೂರ್ಯಕಾಂತಿ', 'सूरजमुखी'),
      _Item('tulip', '🌷', 'Tulip', 'ಟ್ಯೂಲಿಪ್', 'ट्यूलिप'),
      _Item('hibiscus', '🌺', 'Hibiscus', 'ದಾಸವಾಳ', 'गुड़हल'),
      _Item('lotus', '🪷', 'Lotus', 'ಕಮಲ', 'कमल'),
      _Item('mapleLeaf', '🍁', 'Leaf', 'ಎಲೆ', 'पत्ता'),
      _Item('fallenLeaf', '🍂', 'Dry Leaf', 'ಒಣ ಎಲೆ', 'सूखा पत्ता'),
      _Item('herb', '🌿', 'Plant', 'ಗಿಡ', 'पौधा'),
      _Item('clover', '🍀', 'Clover', 'ಕ್ಲೋವರ್', 'तिपतिया'),
      _Item('mushroom', '🍄', 'Mushroom', 'ಅಣಬೆ', 'मशरूम'),
      _Item('sun', '☀️', 'Sun', 'ಸೂರ್ಯ', 'सूरज'),
      _Item('cloud', '☁️', 'Cloud', 'ಮೋಡ', 'बादल'),
      _Item('rain', '🌧️', 'Rain', 'ಮಳೆ', 'बारिश'),
      _Item('snowflake', '❄️', 'Snowflake', 'ಹಿಮದ ಹರಳು', 'बर्फ़ का टुकड़ा'),
      _Item('snowman', '⛄', 'Snowman', 'ಹಿಮ ಮನುಷ್ಯ', 'बर्फ़ का पुतला'),
      _Item('rainbow', '🌈', 'Rainbow', 'ಕಾಮನಬಿಲ್ಲು', 'इंद्रधनुष'),
      _Item('lightning', '⚡', 'Lightning', 'ಮಿಂಚು', 'बिजली'),
      _Item('volcano', '🌋', 'Volcano', 'ಜ್ವಾಲಾಮುಖಿ', 'ज्वालामुखी'),
      _Item('mountain', '⛰️', 'Mountain', 'ಬೆಟ್ಟ', 'पहाड़'),
      _Item('snowMountain', '🏔️', 'Snow Mountain', 'ಹಿಮ ಪರ್ವತ', 'बर्फ़ीला पहाड़'),
      _Item('wave', '🌊', 'Wave', 'ಅಲೆ', 'लहर'),
      _Item('fire', '🔥', 'Fire', 'ಬೆಂಕಿ', 'आग'),
      _Item('rock', '🪨', 'Rock', 'ಕಲ್ಲು', 'पत्थर'),
      _Item('wood', '🪵', 'Wood', 'ಮರದ ದಿಮ್ಮಿ', 'लकड़ी'),
      _Item('seedling', '🌱', 'Seedling', 'ಸಸಿ', 'अंकुर'),
      _Item('nest', '🪺', 'Nest', 'ಗೂಡು', 'घोंसला'),
      _Item('droplet', '💧', 'Water Drop', 'ನೀರಿನ ಹನಿ', 'पानी की बूँद'),
      _Item('bouquet', '💐', 'Bouquet', 'ಹೂಗುಚ್ಛ', 'गुलदस्ता'),
      _Item('paddy', '🌾', 'Paddy', 'ಭತ್ತದ ತೆನೆ', 'धान की बाली'),
    ]),
    (PuzzleCategory.vehicles, PuzzleBackdrop.city, [
      _Item('car', '🚗', 'Car', 'ಕಾರು', 'कार'),
      _Item('taxi', '🚕', 'Taxi', 'ಟ್ಯಾಕ್ಸಿ', 'टैक्सी'),
      _Item('bus', '🚌', 'Bus', 'ಬಸ್', 'बस'),
      _Item('policeCar', '🚓', 'Police Car', 'ಪೊಲೀಸ್ ಕಾರು', 'पुलिस की गाड़ी'),
      _Item('ambulance', '🚑', 'Ambulance', 'ಆಂಬ್ಯುಲೆನ್ಸ್', 'एम्बुलेंस'),
      _Item('fireTruck', '🚒', 'Fire Truck', 'ಅಗ್ನಿಶಾಮಕ ವಾಹನ', 'दमकल गाड़ी'),
      _Item('truck', '🚚', 'Truck', 'ಲಾರಿ', 'ट्रक'),
      _Item('tractor', '🚜', 'Tractor', 'ಟ್ರ್ಯಾಕ್ಟರ್', 'ट्रैक्टर'),
      _Item('raceCar', '🏎️', 'Race Car', 'ರೇಸ್ ಕಾರು', 'रेस कार'),
      _Item('motorcycle', '🏍️', 'Motorcycle', 'ಮೋಟಾರ್ ಸೈಕಲ್', 'मोटरसाइकिल'),
      _Item('scooter', '🛵', 'Scooter', 'ಸ್ಕೂಟರ್', 'स्कूटर'),
      _Item('bicycle', '🚲', 'Bicycle', 'ಸೈಕಲ್', 'साइकिल'),
      _Item('kickScooter', '🛴', 'Kick Scooter', 'ಕಿಕ್ ಸ್ಕೂಟರ್', 'किक स्कूटर'),
      _Item('autoRickshaw', '🛺', 'Auto Rickshaw', 'ಆಟೋ ರಿಕ್ಷಾ', 'ऑटो रिक्शा'),
      _Item('train', '🚆', 'Train', 'ರೈಲು', 'रेलगाड़ी'),
      _Item('steamTrain', '🚂', 'Steam Train', 'ಉಗಿಬಂಡಿ', 'भाप का इंजन'),
      _Item('metro', '🚇', 'Metro', 'ಮೆಟ್ರೋ', 'मेट्रो'),
      _Item('tram', '🚊', 'Tram', 'ಟ್ರಾಮ್', 'ट्राम'),
      _Item('bulletTrain', '🚄', 'Bullet Train', 'ಬುಲೆಟ್ ರೈಲು', 'बुलेट ट्रेन'),
      _Item('airplane', '✈️', 'Airplane', 'ವಿಮಾನ', 'हवाई जहाज़'),
      _Item('helicopter', '🚁', 'Helicopter', 'ಹೆಲಿಕಾಪ್ಟರ್', 'हेलीकॉप्टर'),
      _Item('ship', '🚢', 'Ship', 'ಹಡಗು', 'जहाज़'),
      _Item('sailboat', '⛵', 'Sailboat', 'ಹಾಯಿದೋಣಿ', 'पाल वाली नाव'),
      _Item('speedboat', '🚤', 'Speedboat', 'ಸ್ಪೀಡ್ ಬೋಟ್', 'स्पीडबोट'),
      _Item('canoe', '🛶', 'Canoe', 'ದೋಣಿ', 'डोंगी'),
      _Item('ferry', '⛴️', 'Ferry', 'ಫೆರಿ ಹಡಗು', 'फ़ेरी'),
      _Item('parachute', '🪂', 'Parachute', 'ಪ್ಯಾರಾಚೂಟ್', 'पैराशूट'),
      _Item('cableCar', '🚡', 'Cable Car', 'ಕೇಬಲ್ ಕಾರ್', 'केबल कार'),
      _Item('van', '🚐', 'Van', 'ವ್ಯಾನ್', 'वैन'),
      _Item('pickupTruck', '🛻', 'Pickup Truck', 'ಪಿಕಪ್ ಟ್ರಕ್', 'पिकअप ट्रक'),
    ]),
    (PuzzleCategory.food, PuzzleBackdrop.indoor, [
      _Item('apple', '🍎', 'Apple', 'ಸೇಬು', 'सेब'),
      _Item('greenApple', '🍏', 'Green Apple', 'ಹಸಿರು ಸೇಬು', 'हरा सेब'),
      _Item('banana', '🍌', 'Banana', 'ಬಾಳೆಹಣ್ಣು', 'केला'),
      _Item('mango', '🥭', 'Mango', 'ಮಾವು', 'आम'),
      _Item('orange', '🍊', 'Orange', 'ಕಿತ್ತಳೆ', 'संतरा'),
      _Item('lemon', '🍋', 'Lemon', 'ನಿಂಬೆಹಣ್ಣು', 'नींबू'),
      _Item('grapes', '🍇', 'Grapes', 'ದ್ರಾಕ್ಷಿ', 'अंगूर'),
      _Item('watermelon', '🍉', 'Watermelon', 'ಕಲ್ಲಂಗಡಿ', 'तरबूज़'),
      _Item('melon', '🍈', 'Melon', 'ಕರಬೂಜ', 'खरबूजा'),
      _Item('pineapple', '🍍', 'Pineapple', 'ಅನಾನಸ್', 'अनानास'),
      _Item('strawberry', '🍓', 'Strawberry', 'ಸ್ಟ್ರಾಬೆರಿ', 'स्ट्रॉबेरी'),
      _Item('blueberries', '🫐', 'Blueberries', 'ಬ್ಲೂಬೆರಿ', 'ब्लूबेरी'),
      _Item('cherries', '🍒', 'Cherries', 'ಚೆರ್ರಿ', 'चेरी'),
      _Item('peach', '🍑', 'Peach', 'ಪೀಚ್', 'आड़ू'),
      _Item('pear', '🍐', 'Pear', 'ಮರಸೇಬು', 'नाशपाती'),
      _Item('kiwi', '🥝', 'Kiwi', 'ಕಿವಿ ಹಣ್ಣು', 'कीवी'),
      _Item('coconut', '🥥', 'Coconut', 'ತೆಂಗಿನಕಾಯಿ', 'नारियल'),
      _Item('avocado', '🥑', 'Avocado', 'ಬೆಣ್ಣೆಹಣ್ಣು', 'एवोकाडो'),
      _Item('tomato', '🍅', 'Tomato', 'ಟೊಮೆಟೊ', 'टमाटर'),
      _Item('carrot', '🥕', 'Carrot', 'ಗಜ್ಜರಿ', 'गाजर'),
      _Item('corn', '🌽', 'Corn', 'ಮೆಕ್ಕೆಜೋಳ', 'मक्का'),
      _Item('potato', '🥔', 'Potato', 'ಆಲೂಗಡ್ಡೆ', 'आलू'),
      _Item('brinjal', '🍆', 'Brinjal', 'ಬದನೆಕಾಯಿ', 'बैंगन'),
      _Item('cucumber', '🥒', 'Cucumber', 'ಸೌತೆಕಾಯಿ', 'खीरा'),
      _Item('broccoli', '🥦', 'Broccoli', 'ಬ್ರೊಕೊಲಿ', 'ब्रोकली'),
      _Item('chilli', '🌶️', 'Chilli', 'ಮೆಣಸಿನಕಾಯಿ', 'मिर्च'),
      _Item('capsicum', '🫑', 'Capsicum', 'ದೊಣ್ಣೆ ಮೆಣಸಿನಕಾಯಿ', 'शिमला मिर्च'),
      _Item('onion', '🧅', 'Onion', 'ಈರುಳ್ಳಿ', 'प्याज़'),
      _Item('garlic', '🧄', 'Garlic', 'ಬೆಳ್ಳುಳ್ಳಿ', 'लहसुन'),
      _Item('peas', '🫛', 'Peas', 'ಬಟಾಣಿ', 'मटर'),
      _Item('ginger', '🫚', 'Ginger', 'ಶುಂಠಿ', 'अदरक'),
      _Item('peanuts', '🥜', 'Peanuts', 'ಕಡಲೆಕಾಯಿ', 'मूंगफली'),
      _Item('bread', '🍞', 'Bread', 'ಬ್ರೆಡ್', 'ब्रेड'),
      _Item('cheese', '🧀', 'Cheese', 'ಚೀಸ್', 'चीज़'),
      _Item('egg', '🥚', 'Egg', 'ಮೊಟ್ಟೆ', 'अंडा'),
      _Item('pancakes', '🥞', 'Pancakes', 'ಪ್ಯಾನ್‌ಕೇಕ್', 'पैनकेक'),
      _Item('pizza', '🍕', 'Pizza', 'ಪಿಜ್ಜಾ', 'पिज़्ज़ा'),
      _Item('burger', '🍔', 'Burger', 'ಬರ್ಗರ್', 'बर्गर'),
      _Item('fries', '🍟', 'French Fries', 'ಫ್ರೆಂಚ್ ಫ್ರೈಸ್', 'फ्रेंच फ्राइज़'),
      _Item('sandwich', '🥪', 'Sandwich', 'ಸ್ಯಾಂಡ್‌ವಿಚ್', 'सैंडविच'),
      _Item('rice', '🍚', 'Rice', 'ಅನ್ನ', 'चावल'),
      _Item('curryRice', '🍛', 'Curry Rice', 'ಅನ್ನ ಸಾರು', 'करी चावल'),
      _Item('noodles', '🍜', 'Noodles', 'ನೂಡಲ್ಸ್', 'नूडल्स'),
      _Item('popcorn', '🍿', 'Popcorn', 'ಪಾಪ್‌ಕಾರ್ನ್', 'पॉपकॉर्न'),
      _Item('cake', '🎂', 'Cake', 'ಕೇಕ್', 'केक'),
      _Item('cupcake', '🧁', 'Cupcake', 'ಕಪ್‌ಕೇಕ್', 'कपकेक'),
      _Item('cookie', '🍪', 'Cookie', 'ಬಿಸ್ಕತ್ತು', 'बिस्कुट'),
      _Item('donut', '🍩', 'Donut', 'ಡೋನಟ್', 'डोनट'),
      _Item('iceCream', '🍦', 'Ice Cream', 'ಐಸ್ ಕ್ರೀಮ್', 'आइसक्रीम'),
      _Item('lollipop', '🍭', 'Lollipop', 'ಲಾಲಿಪಾಪ್', 'लॉलीपॉप'),
      _Item('candy', '🍬', 'Candy', 'ಕ್ಯಾಂಡಿ', 'टॉफ़ी'),
      _Item('chocolate', '🍫', 'Chocolate', 'ಚಾಕೊಲೇಟ್', 'चॉकलेट'),
      _Item('honey', '🍯', 'Honey', 'ಜೇನುತುಪ್ಪ', 'शहद'),
      _Item('milk', '🥛', 'Milk', 'ಹಾಲು', 'दूध'),
      _Item('juice', '🧃', 'Juice', 'ಜ್ಯೂಸ್', 'जूस'),
      _Item('tea', '☕', 'Tea', 'ಚಹಾ', 'चाय'),
    ]),
    (PuzzleCategory.space, PuzzleBackdrop.space, [
      _Item('rocket', '🚀', 'Rocket', 'ರಾಕೆಟ್', 'रॉकेट'),
      _Item('satellite', '🛰️', 'Satellite', 'ಉಪಗ್ರಹ', 'उपग्रह'),
      _Item('ufo', '🛸', 'Flying Saucer', 'ಹಾರುವ ತಟ್ಟೆ', 'उड़न तश्तरी'),
      _Item('moon', '🌙', 'Moon', 'ಚಂದ್ರ', 'चाँद'),
      _Item('fullMoon', '🌕', 'Full Moon', 'ಹುಣ್ಣಿಮೆ ಚಂದ್ರ', 'पूरा चाँद'),
      _Item('star', '⭐', 'Star', 'ನಕ್ಷತ್ರ', 'तारा'),
      _Item('glowingStar', '🌟', 'Shining Star', 'ಹೊಳೆಯುವ ನಕ್ಷತ್ರ', 'चमकता तारा'),
      _Item('comet', '☄️', 'Comet', 'ಧೂಮಕೇತು', 'धूमकेतु'),
      _Item('earth', '🌍', 'Earth', 'ಭೂಮಿ', 'पृथ्वी'),
      _Item('planet', '🪐', 'Planet', 'ಗ್ರಹ', 'ग्रह'),
      _Item('astronaut', '🧑‍🚀', 'Astronaut', 'ಗಗನಯಾತ್ರಿ', 'अंतरिक्ष यात्री'),
      _Item('telescope', '🔭', 'Telescope', 'ದೂರದರ್ಶಕ', 'दूरबीन'),
      _Item('alien', '👽', 'Alien', 'ಅನ್ಯಗ್ರಹ ಜೀವಿ', 'एलियन'),
      _Item('milkyWay', '🌌', 'Milky Way', 'ಆಕಾಶಗಂಗೆ', 'आकाशगंगा'),
      _Item('shootingStar', '🌠', 'Shooting Star', 'ಉಲ್ಕೆ', 'टूटता तारा'),
    ]),
    (PuzzleCategory.dinosaurs, PuzzleBackdrop.jungle, [
      _Item('tRex', '🦖', 'T-Rex', 'ಟಿ-ರೆಕ್ಸ್', 'टी-रेक्स'),
      _Item('longNeck', '🦕', 'Long-Neck Dinosaur', 'ಉದ್ದ ಕತ್ತಿನ ಡೈನೋಸಾರ್', 'लंबी गर्दन वाला डायनासोर'),
    ]),
    (PuzzleCategory.objects, PuzzleBackdrop.indoor, [
      _Item('ball', '⚽', 'Ball', 'ಚೆಂಡು', 'गेंद'),
      _Item('basketball', '🏀', 'Basketball', 'ಬ್ಯಾಸ್ಕೆಟ್‌ಬಾಲ್', 'बास्केटबॉल'),
      _Item('cricketBat', '🏏', 'Cricket', 'ಕ್ರಿಕೆಟ್', 'क्रिकेट'),
      _Item('tennisBall', '🎾', 'Tennis Ball', 'ಟೆನಿಸ್ ಚೆಂಡು', 'टेनिस बॉल'),
      _Item('volleyball', '🏐', 'Volleyball', 'ವಾಲಿಬಾಲ್', 'वॉलीबॉल'),
      _Item('badminton', '🏸', 'Badminton', 'ಬ್ಯಾಡ್ಮಿಂಟನ್', 'बैडमिंटन'),
      _Item('kite', '🪁', 'Kite', 'ಗಾಳಿಪಟ', 'पतंग'),
      _Item('yoyo', '🪀', 'Yo-Yo', 'ಯೋ-ಯೋ', 'यो-यो'),
      _Item('teddyBear', '🧸', 'Teddy Bear', 'ಟೆಡ್ಡಿ ಬೇರ್', 'टेडी बियर'),
      _Item('balloon', '🎈', 'Balloon', 'ಬಲೂನು', 'गुब्बारा'),
      _Item('gift', '🎁', 'Gift', 'ಉಡುಗೊರೆ', 'तोहफ़ा'),
      _Item('puzzlePiece', '🧩', 'Puzzle', 'ಒಗಟು', 'पहेली'),
      _Item('robot', '🤖', 'Robot', 'ರೋಬೋಟ್', 'रोबोट'),
      _Item('dice', '🎲', 'Dice', 'ದಾಳ', 'पासा'),
      _Item('drum', '🥁', 'Drum', 'ಡ್ರಮ್', 'ढोल'),
      _Item('guitar', '🎸', 'Guitar', 'ಗಿಟಾರ್', 'गिटार'),
      _Item('piano', '🎹', 'Piano', 'ಪಿಯಾನೋ', 'पियानो'),
      _Item('trumpet', '🎺', 'Trumpet', 'ತುತ್ತೂರಿ', 'तुरही'),
      _Item('violin', '🎻', 'Violin', 'ಪಿಟೀಲು', 'वायलिन'),
      _Item('flute', '🪈', 'Flute', 'ಕೊಳಲು', 'बाँसुरी'),
      _Item('microphone', '🎤', 'Microphone', 'ಮೈಕ್', 'माइक'),
      _Item('headphones', '🎧', 'Headphones', 'ಹೆಡ್‌ಫೋನ್', 'हेडफ़ोन'),
      _Item('book', '📕', 'Book', 'ಪುಸ್ತಕ', 'किताब'),
      _Item('books', '📚', 'Books', 'ಪುಸ್ತಕಗಳು', 'किताबें'),
      _Item('notebook', '📓', 'Notebook', 'ನೋಟ್‌ಬುಕ್', 'कॉपी'),
      _Item('pencil', '✏️', 'Pencil', 'ಪೆನ್ಸಿಲ್', 'पेंसिल'),
      _Item('pen', '🖊️', 'Pen', 'ಪೆನ್ನು', 'पेन'),
      _Item('crayon', '🖍️', 'Crayon', 'ಬಣ್ಣದ ಕಡ್ಡಿ', 'क्रेयॉन'),
      _Item('paintbrush', '🖌️', 'Paintbrush', 'ಕುಂಚ', 'ब्रश'),
      _Item('ruler', '📏', 'Ruler', 'ಅಳತೆಪಟ್ಟಿ', 'स्केल'),
      _Item('scissors', '✂️', 'Scissors', 'ಕತ್ತರಿ', 'कैंची'),
      _Item('backpack', '🎒', 'School Bag', 'ಶಾಲಾ ಚೀಲ', 'बस्ता'),
      _Item('magnifier', '🔍', 'Magnifying Glass', 'ಭೂತಗನ್ನಡಿ', 'आवर्धक लेंस'),
      _Item('alarmClock', '⏰', 'Clock', 'ಗಡಿಯಾರ', 'घड़ी'),
      _Item('watch', '⌚', 'Watch', 'ಕೈಗಡಿಯಾರ', 'कलाई घड़ी'),
      _Item('umbrella', '☂️', 'Umbrella', 'ಛತ್ರಿ', 'छाता'),
      _Item('key', '🔑', 'Key', 'ಬೀಗದ ಕೈ', 'चाबी'),
      _Item('bulb', '💡', 'Light Bulb', 'ಬಲ್ಬ್', 'बल्ब'),
      _Item('candle', '🕯️', 'Candle', 'ಮೇಣದಬತ್ತಿ', 'मोमबत्ती'),
      _Item('chair', '🪑', 'Chair', 'ಕುರ್ಚಿ', 'कुर्सी'),
      _Item('bed', '🛏️', 'Bed', 'ಹಾಸಿಗೆ', 'बिस्तर'),
      _Item('sofa', '🛋️', 'Sofa', 'ಸೋಫಾ', 'सोफ़ा'),
      _Item('door', '🚪', 'Door', 'ಬಾಗಿಲು', 'दरवाज़ा'),
      _Item('window', '🪟', 'Window', 'ಕಿಟಕಿ', 'खिड़की'),
      _Item('mirror', '🪞', 'Mirror', 'ಕನ್ನಡಿ', 'शीशा'),
      _Item('bathtub', '🛁', 'Bathtub', 'ಸ್ನಾನದ ತೊಟ್ಟಿ', 'बाथटब'),
      _Item('toothbrush', '🪥', 'Toothbrush', 'ಹಲ್ಲುಜ್ಜುವ ಬ್ರಷ್', 'टूथब्रश'),
      _Item('soap', '🧼', 'Soap', 'ಸೋಪು', 'साबुन'),
      _Item('broom', '🧹', 'Broom', 'ಪೊರಕೆ', 'झाड़ू'),
      _Item('bucket', '🪣', 'Bucket', 'ಬಕೆಟ್', 'बाल्टी'),
      _Item('basket', '🧺', 'Basket', 'ಬುಟ್ಟಿ', 'टोकरी'),
      _Item('teapot', '🫖', 'Teapot', 'ಟೀಪಾಟ್', 'केतली'),
      _Item('spoon', '🥄', 'Spoon', 'ಚಮಚ', 'चम्मच'),
      _Item('plate', '🍽️', 'Plate', 'ತಟ್ಟೆ', 'थाली'),
      _Item('bowl', '🥣', 'Bowl', 'ಬಟ್ಟಲು', 'कटोरी'),
      _Item('babyBottle', '🍼', 'Milk Bottle', 'ಹಾಲಿನ ಬಾಟಲಿ', 'दूध की बोतल'),
      _Item('television', '📺', 'Television', 'ಟಿವಿ', 'टीवी'),
      _Item('computer', '💻', 'Computer', 'ಕಂಪ್ಯೂಟರ್', 'कंप्यूटर'),
      _Item('phone', '📱', 'Phone', 'ಫೋನ್', 'फ़ोन'),
      _Item('camera', '📷', 'Camera', 'ಕ್ಯಾಮೆರಾ', 'कैमरा'),
      _Item('radio', '📻', 'Radio', 'ರೇಡಿಯೋ', 'रेडियो'),
      _Item('tophat', '🎩', 'Hat', 'ಟೋಪಿ', 'टोपी'),
      _Item('cap', '🧢', 'Cap', 'ಕ್ಯಾಪ್', 'कैप'),
      _Item('crown', '👑', 'Crown', 'ಕಿರೀಟ', 'मुकुट'),
      _Item('glasses', '👓', 'Glasses', 'ಕನ್ನಡಕ', 'चश्मा'),
      _Item('tshirt', '👕', 'T-Shirt', 'ಟಿ-ಶರ್ಟ್', 'टी-शर्ट'),
      _Item('dress', '👗', 'Dress', 'ಫ್ರಾಕ್', 'फ्रॉक'),
      _Item('shoe', '👟', 'Shoe', 'ಶೂ', 'जूता'),
      _Item('socks', '🧦', 'Socks', 'ಕಾಲುಚೀಲ', 'मोज़े'),
      _Item('gloves', '🧤', 'Gloves', 'ಕೈಗವಸು', 'दस्ताने'),
      _Item('scarf', '🧣', 'Scarf', 'ಮಫ್ಲರ್', 'मफ़लर'),
      _Item('handbag', '👜', 'Bag', 'ಕೈಚೀಲ', 'थैला'),
      _Item('ring', '💍', 'Ring', 'ಉಂಗುರ', 'अँगूठी'),
      _Item('trophy', '🏆', 'Trophy', 'ಟ್ರೋಫಿ', 'ट्रॉफ़ी'),
      _Item('medal', '🥇', 'Medal', 'ಪದಕ', 'पदक'),
      _Item('bell', '🔔', 'Bell', 'ಗಂಟೆ', 'घंटी'),
      _Item('magnet', '🧲', 'Magnet', 'ಅಯಸ್ಕಾಂತ', 'चुंबक'),
      _Item('hammer', '🔨', 'Hammer', 'ಸುತ್ತಿಗೆ', 'हथौड़ा'),
      _Item('ladder', '🪜', 'Ladder', 'ಏಣಿ', 'सीढ़ी'),
      _Item('tent', '⛺', 'Tent', 'ಡೇರೆ', 'तंबू'),
    ]),
    (PuzzleCategory.places, PuzzleBackdrop.sky, [
      _Item('house', '🏠', 'House', 'ಮನೆ', 'घर'),
      _Item('school', '🏫', 'School', 'ಶಾಲೆ', 'स्कूल'),
      _Item('hospital', '🏥', 'Hospital', 'ಆಸ್ಪತ್ರೆ', 'अस्पताल'),
      _Item('castle', '🏰', 'Castle', 'ಕೋಟೆ', 'किला'),
      _Item('stadium', '🏟️', 'Stadium', 'ಕ್ರೀಡಾಂಗಣ', 'स्टेडियम'),
      _Item('ferrisWheel', '🎡', 'Giant Wheel', 'ಜಯಂಟ್ ವೀಲ್', 'बड़ा झूला'),
      _Item('carousel', '🎠', 'Merry-Go-Round', 'ಮೆರ್ರಿ-ಗೋ-ರೌಂಡ್', 'मेरी-गो-राउंड'),
      _Item('rollerCoaster', '🎢', 'Roller Coaster', 'ರೋಲರ್ ಕೋಸ್ಟರ್', 'रोलर कोस्टर'),
      _Item('statueOfLiberty', '🗽', 'Statue of Liberty', 'ಸ್ವಾತಂತ್ರ್ಯ ಪ್ರತಿಮೆ', 'स्टैच्यू ऑफ़ लिबर्टी'),
      _Item('tower', '🗼', 'Tower', 'ಗೋಪುರ', 'मीनार'),
      _Item('mountFuji', '🗻', 'Mount Fuji', 'ಫ್ಯೂಜಿ ಪರ್ವತ', 'फ़ूजी पर्वत'),
      _Item('cityscape', '🏙️', 'City', 'ನಗರ', 'शहर'),
      _Item('bridge', '🌉', 'Bridge', 'ಸೇತುವೆ', 'पुल'),
      _Item('fountain', '⛲', 'Fountain', 'ಕಾರಂಜಿ', 'फव्वारा'),
      _Item('circus', '🎪', 'Circus', 'ಸರ್ಕಸ್', 'सर्कस'),
      _Item('camping', '🏕️', 'Camping', 'ಶಿಬಿರ', 'कैंपिंग'),
      _Item('beach', '🏖️', 'Beach', 'ಕಡಲತೀರ', 'समुद्र तट'),
      _Item('island', '🏝️', 'Island', 'ದ್ವೀಪ', 'द्वीप'),
      _Item('desert', '🏜️', 'Desert', 'ಮರುಭೂಮಿ', 'रेगिस्तान'),
      _Item('park', '🏞️', 'Park', 'ಉದ್ಯಾನ', 'उद्यान'),
      _Item('postOffice', '🏤', 'Post Office', 'ಅಂಚೆ ಕಚೇರಿ', 'डाकघर'),
      _Item('bank', '🏦', 'Bank', 'ಬ್ಯಾಂಕ್', 'बैंक'),
      _Item('hotel', '🏨', 'Hotel', 'ಹೋಟೆಲ್', 'होटल'),
      _Item('factory', '🏭', 'Factory', 'ಕಾರ್ಖಾನೆ', 'कारख़ाना'),
      _Item('hut', '🛖', 'Hut', 'ಗುಡಿಸಲು', 'झोपड़ी'),
    ]),
    (PuzzleCategory.india, PuzzleBackdrop.festival, [
      _Item('diya', '🪔', 'Diya', 'ದೀಪ', 'दीया'),
      _Item('temple', '🛕', 'Temple', 'ದೇವಾಲಯ', 'मंदिर'),
      _Item('sari', '🥻', 'Sari', 'ಸೀರೆ', 'साड़ी'),
    ]),
  ];

  static final List<PuzzleDefinition> _objectPuzzles = [
    for (final (category, backdrop, list) in _items)
      for (final item in list)
        PuzzleDefinition(
          id: item.id,
          category: category,
          subject: ObjectSubject(item.emoji, backdrop),
          names: ContentNames.names(key: ContentNames.objectKey(item.en), english: item.en, kannada: item.kn, hindi: item.hi),
        ),
  ];

  /// Every picture object (id, emoji, English name).
  static List<(String id, String emoji, String name)> get artworkObjects =>
      [for (final g in _items) for (final i in g.$3) (i.id, i.emoji, i.en)];

  static final Map<String, _Item> _itemsByID = () {
    final map = <String, _Item>{};
    for (final g in _items) {
      for (final i in g.$3) {
        map.putIfAbsent(i.id, () => i);
      }
    }
    return map;
  }();

  // Scenes

  static PuzzleDefinition _scene(String id, PuzzleCategory category, PuzzleBackdrop backdrop, String en, String kn,
          String hi, List<PuzzleSceneElement> elements) =>
      PuzzleDefinition(
        id: 'scene.$id',
        category: category,
        subject: SceneSubject(backdrop, elements),
        names: ContentNames.names(key: ContentNames.sceneKey(en), english: en, kannada: kn, hindi: hi),
      );

  static final List<PuzzleDefinition> _scenePuzzles = [
    _scene('farm', PuzzleCategory.animals, PuzzleBackdrop.farm, 'Farm', 'ಹೊಲ', 'खेत', [PuzzleSceneElement('☀️', 0.85, 0.14, 0.16), PuzzleSceneElement('🏠', 0.22, 0.42, 0.26), PuzzleSceneElement('🌳', 0.8, 0.42, 0.24), PuzzleSceneElement('🐄', 0.3, 0.74, 0.24), PuzzleSceneElement('🐖', 0.66, 0.78, 0.18), PuzzleSceneElement('🐔', 0.86, 0.72, 0.14)]),
    _scene('zoo', PuzzleCategory.animals, PuzzleBackdrop.meadow, 'Zoo', 'ಮೃಗಾಲಯ', 'चिड़ियाघर', [PuzzleSceneElement('🦒', 0.2, 0.45, 0.3), PuzzleSceneElement('🐘', 0.55, 0.62, 0.28), PuzzleSceneElement('🦁', 0.82, 0.76, 0.2), PuzzleSceneElement('🌴', 0.86, 0.36, 0.22), PuzzleSceneElement('☁️', 0.5, 0.14, 0.16)]),
    _scene('jungle', PuzzleCategory.animals, PuzzleBackdrop.jungle, 'Jungle', 'ಕಾಡು', 'जंगल', [PuzzleSceneElement('🌴', 0.16, 0.4, 0.3), PuzzleSceneElement('🐒', 0.5, 0.32, 0.2), PuzzleSceneElement('🦜', 0.82, 0.22, 0.16), PuzzleSceneElement('🐯', 0.6, 0.74, 0.28), PuzzleSceneElement('🌿', 0.14, 0.84, 0.18)]),
    _scene('safari', PuzzleCategory.animals, PuzzleBackdrop.desert, 'Safari', 'ಸಫಾರಿ', 'सफ़ारी', [PuzzleSceneElement('☀️', 0.84, 0.14, 0.18), PuzzleSceneElement('🦓', 0.25, 0.68, 0.26), PuzzleSceneElement('🦒', 0.62, 0.52, 0.3), PuzzleSceneElement('🌳', 0.88, 0.62, 0.2)]),
    _scene('duckPond', PuzzleCategory.animals, PuzzleBackdrop.meadow, 'Duck Pond', 'ಬಾತುಕೋಳಿ ಕೊಳ', 'बत्तखों का तालाब', [PuzzleSceneElement('🦆', 0.35, 0.66, 0.22), PuzzleSceneElement('🐸', 0.7, 0.8, 0.16), PuzzleSceneElement('🪷', 0.18, 0.84, 0.14), PuzzleSceneElement('🌳', 0.82, 0.4, 0.26), PuzzleSceneElement('☀️', 0.16, 0.14, 0.14)]),
    _scene('arctic', PuzzleCategory.animals, PuzzleBackdrop.snow, 'Snowy Land', 'ಹಿಮ ನಾಡು', 'बर्फ़ीला देश', [PuzzleSceneElement('🐧', 0.28, 0.7, 0.24), PuzzleSceneElement('🐻‍❄️', 0.66, 0.66, 0.3), PuzzleSceneElement('❄️', 0.2, 0.2, 0.1), PuzzleSceneElement('❄️', 0.8, 0.16, 0.12)]),
    _scene('oceanFloor', PuzzleCategory.animals, PuzzleBackdrop.underwater, 'Under the Sea', 'ಸಮುದ್ರದ ಅಡಿಯಲ್ಲಿ', 'समुद्र के नीचे', [PuzzleSceneElement('🐠', 0.3, 0.3, 0.18), PuzzleSceneElement('🐙', 0.7, 0.48, 0.24), PuzzleSceneElement('🦀', 0.28, 0.82, 0.16), PuzzleSceneElement('🪸', 0.82, 0.84, 0.2), PuzzleSceneElement('🐚', 0.55, 0.88, 0.1)]),
    _scene('coralReef', PuzzleCategory.animals, PuzzleBackdrop.underwater, 'Coral Reef', 'ಹವಳದ ದಂಡೆ', 'मूंगे की चट्टान', [PuzzleSceneElement('🐬', 0.35, 0.3, 0.26), PuzzleSceneElement('🐢', 0.7, 0.55, 0.22), PuzzleSceneElement('🐟', 0.2, 0.6, 0.14), PuzzleSceneElement('🪸', 0.2, 0.86, 0.2), PuzzleSceneElement('🪸', 0.8, 0.86, 0.18)]),
    _scene('forestFriends', PuzzleCategory.animals, PuzzleBackdrop.meadow, 'Forest Friends', 'ಕಾಡಿನ ಗೆಳೆಯರು', 'जंगल के दोस्त', [PuzzleSceneElement('🌲', 0.15, 0.4, 0.28), PuzzleSceneElement('🦊', 0.45, 0.7, 0.22), PuzzleSceneElement('🐰', 0.75, 0.74, 0.18), PuzzleSceneElement('🍄', 0.88, 0.86, 0.1), PuzzleSceneElement('🦔', 0.2, 0.84, 0.14)]),
    _scene('owlNight', PuzzleCategory.animals, PuzzleBackdrop.night, 'Owl at Night', 'ರಾತ್ರಿಯ ಗೂಬೆ', 'रात का उल्लू', [PuzzleSceneElement('🌙', 0.8, 0.16, 0.18), PuzzleSceneElement('🌳', 0.4, 0.58, 0.5), PuzzleSceneElement('🦉', 0.45, 0.46, 0.18), PuzzleSceneElement('⭐', 0.2, 0.14, 0.08)]),
    _scene('rainbowMeadow', PuzzleCategory.nature, PuzzleBackdrop.meadow, 'Rainbow Meadow', 'ಕಾಮನಬಿಲ್ಲಿನ ಹುಲ್ಲುಗಾವಲು', 'इंद्रधनुष वाला मैदान', [PuzzleSceneElement('🌈', 0.5, 0.26, 0.5), PuzzleSceneElement('☀️', 0.14, 0.14, 0.14), PuzzleSceneElement('🌸', 0.2, 0.8, 0.14), PuzzleSceneElement('🌷', 0.5, 0.84, 0.14), PuzzleSceneElement('🦋', 0.78, 0.62, 0.14)]),
    _scene('garden', PuzzleCategory.nature, PuzzleBackdrop.meadow, 'Garden', 'ತೋಟ', 'बगीचा', [PuzzleSceneElement('🌻', 0.2, 0.6, 0.26), PuzzleSceneElement('🌹', 0.5, 0.72, 0.2), PuzzleSceneElement('🌷', 0.8, 0.7, 0.2), PuzzleSceneElement('🐝', 0.62, 0.34, 0.12), PuzzleSceneElement('🦋', 0.3, 0.26, 0.14)]),
    _scene('snowyDay', PuzzleCategory.nature, PuzzleBackdrop.snow, 'Snowy Day', 'ಹಿಮದ ದಿನ', 'बर्फ़ का दिन', [PuzzleSceneElement('⛄', 0.4, 0.66, 0.34), PuzzleSceneElement('🌲', 0.82, 0.58, 0.26), PuzzleSceneElement('❄️', 0.18, 0.2, 0.1), PuzzleSceneElement('❄️', 0.62, 0.16, 0.08), PuzzleSceneElement('☁️', 0.4, 0.14, 0.16)]),
    _scene('mountainSunrise', PuzzleCategory.nature, PuzzleBackdrop.sky, 'Mountain Sunrise', 'ಬೆಟ್ಟದ ಸೂರ್ಯೋದಯ', 'पहाड़ों पर सूर्योदय', [PuzzleSceneElement('☀️', 0.5, 0.3, 0.22), PuzzleSceneElement('🏔️', 0.3, 0.68, 0.44), PuzzleSceneElement('⛰️', 0.74, 0.72, 0.36), PuzzleSceneElement('🦅', 0.8, 0.2, 0.12)]),
    _scene('rainyDay', PuzzleCategory.nature, PuzzleBackdrop.sky, 'Rainy Day', 'ಮಳೆಯ ದಿನ', 'बारिश का दिन', [PuzzleSceneElement('🌧️', 0.3, 0.2, 0.24), PuzzleSceneElement('🌧️', 0.72, 0.16, 0.2), PuzzleSceneElement('☂️', 0.45, 0.6, 0.3), PuzzleSceneElement('🐸', 0.8, 0.84, 0.14)]),
    _scene('autumn', PuzzleCategory.nature, PuzzleBackdrop.meadow, 'Autumn', 'ಶರತ್ಕಾಲ', 'पतझड़', [PuzzleSceneElement('🌳', 0.35, 0.46, 0.44), PuzzleSceneElement('🍂', 0.7, 0.8, 0.12), PuzzleSceneElement('🍁', 0.2, 0.84, 0.12), PuzzleSceneElement('🐿️', 0.76, 0.66, 0.18)]),
    _scene('desertDay', PuzzleCategory.nature, PuzzleBackdrop.desert, 'Desert', 'ಮರುಭೂಮಿ', 'रेगिस्तान', [PuzzleSceneElement('☀️', 0.82, 0.16, 0.18), PuzzleSceneElement('🌵', 0.22, 0.62, 0.3), PuzzleSceneElement('🐫', 0.64, 0.7, 0.3)]),
    _scene('sunnyBeach', PuzzleCategory.nature, PuzzleBackdrop.beach, 'Sunny Beach', 'ಬಿಸಿಲಿನ ಕಡಲತೀರ', 'धूप वाला समुद्र तट', [PuzzleSceneElement('☀️', 0.16, 0.14, 0.16), PuzzleSceneElement('🌴', 0.8, 0.44, 0.3), PuzzleSceneElement('⛱️', 0.36, 0.7, 0.24), PuzzleSceneElement('🐚', 0.66, 0.86, 0.1), PuzzleSceneElement('⛵', 0.4, 0.34, 0.12)]),
    _scene('nightSky', PuzzleCategory.nature, PuzzleBackdrop.night, 'Night Sky', 'ರಾತ್ರಿಯ ಆಕಾಶ', 'रात का आसमान', [PuzzleSceneElement('🌙', 0.72, 0.24, 0.24), PuzzleSceneElement('⭐', 0.2, 0.2, 0.1), PuzzleSceneElement('🌟', 0.42, 0.4, 0.1), PuzzleSceneElement('⭐', 0.3, 0.6, 0.08), PuzzleSceneElement('🏠', 0.3, 0.84, 0.2)]),
    _scene('cityStreet', PuzzleCategory.vehicles, PuzzleBackdrop.city, 'City Street', 'ನಗರದ ರಸ್ತೆ', 'शहर की सड़क', [PuzzleSceneElement('🏙️', 0.5, 0.36, 0.5), PuzzleSceneElement('🚗', 0.24, 0.8, 0.2), PuzzleSceneElement('🚌', 0.6, 0.8, 0.24), PuzzleSceneElement('🚕', 0.88, 0.82, 0.14)]),
    _scene('raceDay', PuzzleCategory.vehicles, PuzzleBackdrop.city, 'Race Day', 'ಓಟದ ದಿನ', 'रेस का दिन', [PuzzleSceneElement('🏎️', 0.3, 0.72, 0.26), PuzzleSceneElement('🏎️', 0.7, 0.62, 0.22), PuzzleSceneElement('🏁', 0.8, 0.26, 0.2)]),
    _scene('airport', PuzzleCategory.vehicles, PuzzleBackdrop.sky, 'Airport', 'ವಿಮಾನ ನಿಲ್ದಾಣ', 'हवाई अड्डा', [PuzzleSceneElement('✈️', 0.4, 0.34, 0.34), PuzzleSceneElement('🚁', 0.8, 0.2, 0.16), PuzzleSceneElement('☁️', 0.18, 0.16, 0.14), PuzzleSceneElement('☁️', 0.72, 0.52, 0.12)]),
    _scene('harbour', PuzzleCategory.vehicles, PuzzleBackdrop.beach, 'Harbour', 'ಬಂದರು', 'बंदरगाह', [PuzzleSceneElement('🚢', 0.4, 0.46, 0.36), PuzzleSceneElement('⛵', 0.8, 0.5, 0.16), PuzzleSceneElement('🚤', 0.2, 0.62, 0.14), PuzzleSceneElement('☀️', 0.84, 0.14, 0.14)]),
    _scene('trainJourney', PuzzleCategory.vehicles, PuzzleBackdrop.meadow, 'Train Journey', 'ರೈಲು ಪ್ರಯಾಣ', 'रेल यात्रा', [PuzzleSceneElement('⛰️', 0.7, 0.4, 0.36), PuzzleSceneElement('🚂', 0.36, 0.72, 0.3), PuzzleSceneElement('🌳', 0.12, 0.62, 0.18), PuzzleSceneElement('☁️', 0.3, 0.16, 0.14)]),
    _scene('fireRescue', PuzzleCategory.vehicles, PuzzleBackdrop.city, 'Fire Rescue', 'ಅಗ್ನಿ ರಕ್ಷಣೆ', 'आग से बचाव', [PuzzleSceneElement('🚒', 0.4, 0.74, 0.32), PuzzleSceneElement('🏠', 0.76, 0.52, 0.26), PuzzleSceneElement('🧑‍🚒', 0.14, 0.76, 0.16)]),
    _scene('construction', PuzzleCategory.vehicles, PuzzleBackdrop.desert, 'Building Site', 'ಕಟ್ಟಡ ನಿರ್ಮಾಣ', 'निर्माण स्थल', [PuzzleSceneElement('🏗️', 0.7, 0.42, 0.4), PuzzleSceneElement('🚜', 0.3, 0.74, 0.26), PuzzleSceneElement('🚚', 0.72, 0.82, 0.2)]),
    _scene('fruitBasket', PuzzleCategory.food, PuzzleBackdrop.indoor, 'Fruit Basket', 'ಹಣ್ಣಿನ ಬುಟ್ಟಿ', 'फलों की टोकरी', [PuzzleSceneElement('🧺', 0.5, 0.7, 0.44), PuzzleSceneElement('🍎', 0.36, 0.46, 0.16), PuzzleSceneElement('🍌', 0.56, 0.42, 0.18), PuzzleSceneElement('🍇', 0.7, 0.5, 0.16)]),
    _scene('picnic', PuzzleCategory.food, PuzzleBackdrop.meadow, 'Picnic', 'ವನಭೋಜನ', 'पिकनिक', [PuzzleSceneElement('🧺', 0.3, 0.74, 0.24), PuzzleSceneElement('🍉', 0.6, 0.78, 0.2), PuzzleSceneElement('🥪', 0.82, 0.8, 0.14), PuzzleSceneElement('🌳', 0.76, 0.4, 0.3), PuzzleSceneElement('☀️', 0.16, 0.14, 0.14)]),
    _scene('birthday', PuzzleCategory.food, PuzzleBackdrop.festival, 'Birthday Party', 'ಹುಟ್ಟುಹಬ್ಬದ ಸಂಭ್ರಮ', 'जन्मदिन की पार्टी', [PuzzleSceneElement('🎂', 0.5, 0.7, 0.34), PuzzleSceneElement('🎈', 0.16, 0.3, 0.2), PuzzleSceneElement('🎈', 0.84, 0.28, 0.2), PuzzleSceneElement('🎁', 0.18, 0.8, 0.16), PuzzleSceneElement('🎉', 0.82, 0.78, 0.16)]),
    _scene('breakfast', PuzzleCategory.food, PuzzleBackdrop.indoor, 'Breakfast', 'ಬೆಳಗಿನ ಉಪಾಹಾರ', 'नाश्ता', [PuzzleSceneElement('🥛', 0.22, 0.56, 0.22), PuzzleSceneElement('🍞', 0.52, 0.64, 0.24), PuzzleSceneElement('🥚', 0.8, 0.66, 0.14), PuzzleSceneElement('🍌', 0.66, 0.34, 0.16)]),
    _scene('solarSystem', PuzzleCategory.space, PuzzleBackdrop.space, 'Solar System', 'ಸೌರವ್ಯೂಹ', 'सौरमंडल', [PuzzleSceneElement('☀️', 0.2, 0.5, 0.3), PuzzleSceneElement('🌍', 0.52, 0.5, 0.16), PuzzleSceneElement('🪐', 0.8, 0.34, 0.2), PuzzleSceneElement('🌙', 0.62, 0.3, 0.08), PuzzleSceneElement('⭐', 0.84, 0.82, 0.06)]),
    _scene('rocketLaunch', PuzzleCategory.space, PuzzleBackdrop.space, 'Rocket Launch', 'ರಾಕೆಟ್ ಉಡಾವಣೆ', 'रॉकेट लॉन्च', [PuzzleSceneElement('🚀', 0.5, 0.48, 0.4), PuzzleSceneElement('🌍', 0.2, 0.84, 0.2), PuzzleSceneElement('✨', 0.8, 0.2, 0.12), PuzzleSceneElement('⭐', 0.18, 0.2, 0.08)]),
    _scene('moonwalk', PuzzleCategory.space, PuzzleBackdrop.space, 'Walk on the Moon', 'ಚಂದ್ರನ ಮೇಲೆ ನಡಿಗೆ', 'चाँद पर सैर', [PuzzleSceneElement('🌕', 0.5, 0.86, 0.6), PuzzleSceneElement('🧑‍🚀', 0.46, 0.46, 0.28), PuzzleSceneElement('🌍', 0.82, 0.18, 0.14), PuzzleSceneElement('⭐', 0.18, 0.2, 0.08)]),
    _scene('ufoVisit', PuzzleCategory.space, PuzzleBackdrop.night, 'Space Visitors', 'ಅಂತರಿಕ್ಷದ ಅತಿಥಿಗಳು', 'अंतरिक्ष के मेहमान', [PuzzleSceneElement('🛸', 0.5, 0.34, 0.34), PuzzleSceneElement('👽', 0.34, 0.76, 0.2), PuzzleSceneElement('👽', 0.66, 0.78, 0.18), PuzzleSceneElement('⭐', 0.16, 0.16, 0.08)]),
    _scene('cometNight', PuzzleCategory.space, PuzzleBackdrop.space, 'Comet Night', 'ಧೂಮಕೇತುವಿನ ರಾತ್ರಿ', 'धूमकेतु की रात', [PuzzleSceneElement('☄️', 0.5, 0.4, 0.34), PuzzleSceneElement('🌌', 0.24, 0.8, 0.22), PuzzleSceneElement('⭐', 0.82, 0.76, 0.1)]),
    _scene('satelliteEarth', PuzzleCategory.space, PuzzleBackdrop.space, 'Satellite', 'ಉಪಗ್ರಹ ಮತ್ತು ಭೂಮಿ', 'उपग्रह और पृथ्वी', [PuzzleSceneElement('🌍', 0.42, 0.62, 0.46), PuzzleSceneElement('🛰️', 0.78, 0.22, 0.18), PuzzleSceneElement('🌙', 0.16, 0.18, 0.1)]),
    _scene('dinoFriends', PuzzleCategory.dinosaurs, PuzzleBackdrop.jungle, 'Dino Friends', 'ಡೈನೋ ಗೆಳೆಯರು', 'डायनो दोस्त', [PuzzleSceneElement('🦖', 0.3, 0.66, 0.32), PuzzleSceneElement('🦕', 0.7, 0.6, 0.36), PuzzleSceneElement('☀️', 0.84, 0.14, 0.14)]),
    _scene('tRexJungle', PuzzleCategory.dinosaurs, PuzzleBackdrop.jungle, 'T-Rex in the Jungle', 'ಕಾಡಿನಲ್ಲಿ ಟಿ-ರೆಕ್ಸ್', 'जंगल में टी-रेक्स', [PuzzleSceneElement('🦖', 0.5, 0.64, 0.42), PuzzleSceneElement('🌴', 0.14, 0.44, 0.28), PuzzleSceneElement('🌿', 0.86, 0.82, 0.18)]),
    _scene('longNeckLake', PuzzleCategory.dinosaurs, PuzzleBackdrop.beach, 'Dino Lake', 'ಡೈನೋ ಕೆರೆ', 'डायनो झील', [PuzzleSceneElement('🦕', 0.46, 0.5, 0.46), PuzzleSceneElement('🌴', 0.86, 0.46, 0.24), PuzzleSceneElement('☀️', 0.14, 0.14, 0.14)]),
    _scene('dinoEggs', PuzzleCategory.dinosaurs, PuzzleBackdrop.jungle, 'Dino Eggs', 'ಡೈನೋ ಮೊಟ್ಟೆಗಳು', 'डायनो के अंडे', [PuzzleSceneElement('🥚', 0.36, 0.76, 0.16), PuzzleSceneElement('🥚', 0.52, 0.8, 0.16), PuzzleSceneElement('🦕', 0.66, 0.46, 0.34), PuzzleSceneElement('🌿', 0.14, 0.8, 0.16)]),
    _scene('volcanoValley', PuzzleCategory.dinosaurs, PuzzleBackdrop.volcano, 'Volcano Valley', 'ಜ್ವಾಲಾಮುಖಿ ಕಣಿವೆ', 'ज्वालामुखी की घाटी', [PuzzleSceneElement('🌋', 0.62, 0.42, 0.4), PuzzleSceneElement('🦖', 0.24, 0.72, 0.28), PuzzleSceneElement('🦕', 0.8, 0.78, 0.2)]),
    _scene('fossilDig', PuzzleCategory.dinosaurs, PuzzleBackdrop.desert, 'Fossil Dig', 'ಪಳೆಯುಳಿಕೆ ಹುಡುಕಾಟ', 'जीवाश्म की खोज', [PuzzleSceneElement('🦴', 0.36, 0.72, 0.24), PuzzleSceneElement('🦴', 0.64, 0.8, 0.18), PuzzleSceneElement('🪨', 0.8, 0.62, 0.18), PuzzleSceneElement('🦖', 0.3, 0.34, 0.2)]),
    _scene('dinoBeach', PuzzleCategory.dinosaurs, PuzzleBackdrop.beach, 'Dino Beach', 'ಡೈನೋ ಕಡಲತೀರ', 'डायनो का समुद्र तट', [PuzzleSceneElement('🦕', 0.34, 0.56, 0.36), PuzzleSceneElement('🏝️', 0.78, 0.46, 0.24), PuzzleSceneElement('🐚', 0.7, 0.86, 0.1)]),
    _scene('dinoNight', PuzzleCategory.dinosaurs, PuzzleBackdrop.night, 'Dino Night', 'ಡೈನೋ ರಾತ್ರಿ', 'डायनो की रात', [PuzzleSceneElement('🦕', 0.44, 0.64, 0.4), PuzzleSceneElement('🌙', 0.8, 0.18, 0.16), PuzzleSceneElement('⭐', 0.2, 0.18, 0.08)]),
    _scene('indianVillage', PuzzleCategory.india, PuzzleBackdrop.farm, 'Indian Village', 'ಹಳ್ಳಿ', 'गाँव', [PuzzleSceneElement('🛖', 0.26, 0.5, 0.28), PuzzleSceneElement('🐄', 0.62, 0.7, 0.24), PuzzleSceneElement('🌾', 0.2, 0.84, 0.16), PuzzleSceneElement('🌳', 0.84, 0.46, 0.24), PuzzleSceneElement('☀️', 0.84, 0.12, 0.14)]),
    _scene('diwali', PuzzleCategory.india, PuzzleBackdrop.festival, 'Diwali', 'ದೀಪಾವಳಿ', 'दीवाली', [PuzzleSceneElement('🪔', 0.3, 0.76, 0.2), PuzzleSceneElement('🪔', 0.7, 0.76, 0.2), PuzzleSceneElement('🎆', 0.3, 0.26, 0.26), PuzzleSceneElement('🎇', 0.74, 0.3, 0.24)]),
    _scene('kiteFestival', PuzzleCategory.india, PuzzleBackdrop.sky, 'Kite Festival', 'ಗಾಳಿಪಟ ಹಬ್ಬ', 'पतंग उत्सव', [PuzzleSceneElement('🪁', 0.3, 0.3, 0.24), PuzzleSceneElement('🪁', 0.72, 0.22, 0.2), PuzzleSceneElement('🏠', 0.3, 0.8, 0.2), PuzzleSceneElement('☀️', 0.84, 0.66, 0.12)]),
    _scene('templeFlowers', PuzzleCategory.india, PuzzleBackdrop.sky, 'Temple', 'ದೇವಾಲಯ', 'मंदिर', [PuzzleSceneElement('🛕', 0.5, 0.52, 0.46), PuzzleSceneElement('🌺', 0.16, 0.84, 0.14), PuzzleSceneElement('🪔', 0.84, 0.84, 0.14)]),
    _scene('peacockGarden', PuzzleCategory.india, PuzzleBackdrop.meadow, 'Peacock Garden', 'ನವಿಲಿನ ತೋಟ', 'मोर का बगीचा', [PuzzleSceneElement('🦚', 0.44, 0.6, 0.4), PuzzleSceneElement('🌸', 0.84, 0.8, 0.14), PuzzleSceneElement('🌳', 0.84, 0.36, 0.24)]),
    _scene('lotusPond', PuzzleCategory.india, PuzzleBackdrop.meadow, 'Lotus Pond', 'ಕಮಲದ ಕೊಳ', 'कमल का तालाब', [PuzzleSceneElement('🪷', 0.3, 0.72, 0.22), PuzzleSceneElement('🪷', 0.7, 0.78, 0.18), PuzzleSceneElement('🐟', 0.5, 0.86, 0.12), PuzzleSceneElement('🦆', 0.72, 0.52, 0.16)]),
    _scene('indianTrain', PuzzleCategory.india, PuzzleBackdrop.farm, 'Train Ride', 'ರೈಲು ಸವಾರಿ', 'रेल की सवारी', [PuzzleSceneElement('🚂', 0.4, 0.66, 0.32), PuzzleSceneElement('🌴', 0.84, 0.5, 0.24), PuzzleSceneElement('🌾', 0.14, 0.84, 0.16), PuzzleSceneElement('☀️', 0.16, 0.14, 0.14)]),
    _scene('cricketMatch', PuzzleCategory.india, PuzzleBackdrop.meadow, 'Cricket Match', 'ಕ್ರಿಕೆಟ್ ಪಂದ್ಯ', 'क्रिकेट मैच', [PuzzleSceneElement('🏏', 0.4, 0.62, 0.32), PuzzleSceneElement('🏟️', 0.72, 0.32, 0.3), PuzzleSceneElement('🏆', 0.8, 0.8, 0.14)]),
    _scene('elephantFestival', PuzzleCategory.india, PuzzleBackdrop.festival, 'Elephant Festival', 'ಆನೆ ಉತ್ಸವ', 'हाथी उत्सव', [PuzzleSceneElement('🐘', 0.46, 0.62, 0.42), PuzzleSceneElement('🌺', 0.16, 0.3, 0.14), PuzzleSceneElement('✨', 0.84, 0.24, 0.12), PuzzleSceneElement('🪔', 0.84, 0.84, 0.12)]),
    _scene('mangoOrchard', PuzzleCategory.india, PuzzleBackdrop.farm, 'Mango Orchard', 'ಮಾವಿನ ತೋಪು', 'आम का बाग़', [PuzzleSceneElement('🌳', 0.3, 0.46, 0.36), PuzzleSceneElement('🥭', 0.62, 0.72, 0.16), PuzzleSceneElement('🥭', 0.78, 0.8, 0.14), PuzzleSceneElement('🐒', 0.78, 0.42, 0.18)]),
    _scene('autoRide', PuzzleCategory.india, PuzzleBackdrop.city, 'Auto Ride', 'ಆಟೋ ಸವಾರಿ', 'ऑटो की सवारी', [PuzzleSceneElement('🛺', 0.44, 0.72, 0.34), PuzzleSceneElement('🏙️', 0.6, 0.32, 0.36)]),
    _scene('playground', PuzzleCategory.places, PuzzleBackdrop.meadow, 'Playground', 'ಆಟದ ಮೈದಾನ', 'खेल का मैदान', [PuzzleSceneElement('🛝', 0.36, 0.64, 0.32), PuzzleSceneElement('⚽', 0.76, 0.82, 0.12), PuzzleSceneElement('🌳', 0.84, 0.46, 0.24), PuzzleSceneElement('☀️', 0.16, 0.14, 0.14)]),
    _scene('funFair', PuzzleCategory.places, PuzzleBackdrop.sky, 'Fun Fair', 'ಜಾತ್ರೆ', 'मेला', [PuzzleSceneElement('🎡', 0.3, 0.48, 0.4), PuzzleSceneElement('🎢', 0.74, 0.58, 0.3), PuzzleSceneElement('🎈', 0.8, 0.2, 0.14)]),
  ];

  // Letters, numbers, colours, words

  static final Map<AppLanguage, List<PuzzleDefinition>> _letterCache = {};

  static List<PuzzleDefinition> _letterPuzzles(AppLanguage language) => _letterCache.putIfAbsent(language, () {
        final List<RunCollectTarget> letters;
        switch (language) {
          case AppLanguage.english:
            letters = RunCollectContent.englishLetters;
          case AppLanguage.kannada:
            letters = RunCollectContent.kannadaLetters;
          case AppLanguage.hindi:
            letters = RunCollectContent.hindiLetters;
          default:
            letters = RunCollectContent.targets(language, RunCollectTargetMode.letter);
        }
        return letters.map((letter) {
          final symbol = letter.localizedSymbol(language);
          final word = letter.localizedName(language);
          return PuzzleDefinition(
            id: 'letter.${language.code}.${letter.id}',
            category: PuzzleCategory.letters,
            subject: LetterSubject(symbol, letter.emoji),
            names: {language: '$symbol – $word'},
          );
        }).toList();
      });

  static const _countingEmojis = ['🍎', '⭐', '🎈', '🐟', '🌸', '🚗', '🐤', '⚽', '🍓', '🦋'];

  /// 1…100. The voice reads the digits in the chosen language.
  static final List<PuzzleDefinition> _numberPuzzles = [
    for (var value = 1; value <= 100; value++)
      PuzzleDefinition(
        id: 'number.$value',
        category: PuzzleCategory.numbers,
        subject: NumberSubject(value, _countingEmojis[(value - 1) % _countingEmojis.length]),
        names: {for (final l in AppLanguage.values) l: '$value'},
      ),
  ];

  static String colorName(PuzzleColor color, AppLanguage language) {
    const names = {
      PuzzleColor.red: 'Red',
      PuzzleColor.blue: 'Blue',
      PuzzleColor.green: 'Green',
      PuzzleColor.yellow: 'Yellow',
      PuzzleColor.orange: 'Orange',
      PuzzleColor.purple: 'Purple',
      PuzzleColor.pink: 'Pink',
      PuzzleColor.brown: 'Brown',
      PuzzleColor.black: 'Black',
      PuzzleColor.white: 'White',
      PuzzleColor.gray: 'Gray',
      PuzzleColor.skyBlue: 'Sky Blue',
    };
    return L(names[color]!).resolve(language);
  }

  static final List<PuzzleDefinition> _colorPuzzles = [
    for (final color in PuzzleColor.values)
      PuzzleDefinition(
        id: 'color.${color.name}',
        category: PuzzleCategory.colors,
        subject: ColorSubject(color),
        names: {for (final l in AppLanguage.values) l: colorName(color, l)},
      ),
  ];

  /// Short, familiar words for reading puzzles.
  static const _wordIDs = ['cat', 'dog', 'cow', 'pig', 'fish', 'bird', 'bee', 'ant', 'owl', 'duck', 'lion', 'tiger', 'frog', 'goat', 'sheep', 'horse', 'monkey', 'rabbit', 'bear', 'fox', 'sun', 'moon', 'star', 'tree', 'rose', 'rain', 'cloud', 'leaf', 'rock', 'fire', 'car', 'bus', 'ship', 'train', 'truck', 'van', 'taxi', 'canoe', 'airplane', 'bicycle', 'apple', 'mango', 'banana', 'egg', 'milk', 'cake', 'rice', 'corn', 'tea', 'pizza', 'ball', 'book', 'pen', 'key', 'bell', 'drum', 'kite', 'cap', 'shoe', 'house'];

  static final List<PuzzleDefinition> _wordPuzzles = [
    for (final id in _wordIDs)
      if ((_itemsByID[id] ?? _itemsByID[id == 'leaf' ? 'mapleLeaf' : id]) case final item?)
        PuzzleDefinition(
          id: 'word.$id',
          category: PuzzleCategory.words,
          subject: WordSubject(item.emoji),
          names: ContentNames.names(key: ContentNames.objectKey(item.en), english: item.en, kannada: item.kn, hindi: item.hi),
        ),
  ];
}
