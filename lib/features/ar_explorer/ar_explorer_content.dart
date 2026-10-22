import '../../core/localization/content_names.dart';
import '../../core/localization/localized.dart';
import '../../data/puzzle_content/puzzle_library.dart';
import '../../domain/models/app_language.dart';
import 'ar_hunt_content.dart';

// Data for ChihChi AR Explorer. Object names come from the shared `ARHuntContent` vocabulary
// (also used by Catch World). This file adds what AR Explorer needs on top: first letters, known
// shapes and mystery clues.

/// Colours judged from the hue of the pixels the child tapped. Brown, black, white and grey are
/// left out on purpose: hue alone cannot tell them apart reliably.
enum ExplorerColor {
  red('🔴'),
  orange('🟠'),
  yellow('🟡'),
  green('🟢'),
  blue('🔵'),
  purple('🟣'),
  pink('🩷');

  const ExplorerColor(this.emoji);
  final String emoji;

  /// Colour for a hue in 0..<1 (cyan counts as blue).
  static ExplorerColor forHue(double hue) {
    if (hue < 0.04 || hue >= 0.96) return red;
    if (hue < 0.10) return orange;
    if (hue < 0.19) return yellow;
    if (hue < 0.46) return green;
    if (hue < 0.68) return blue;
    if (hue < 0.83) return purple;
    return pink;
  }

  static ExplorerColor? fromRaw(String? raw) => values.where((c) => c.name == raw).firstOrNull;
}

/// Shapes come from what the object is ("balls are round"), never from measuring its outline.
enum ExplorerShape {
  round('⚪'),
  rectangle('▭'),
  long('📏');

  const ExplorerShape(this.emoji);
  final String emoji;
}

class ARExplorerObject {
  const ARExplorerObject({
    required this.id,
    required this.emoji,
    required this.names,
    required this.keywords,
    this.shape,
  });

  final String id;
  final String emoji;
  final Map<AppLanguage, String> names;

  /// Recogniser labels (lower case) that mean this object.
  final List<String> keywords;
  final ExplorerShape? shape;

  String name(AppLanguage language) => names[language] ?? names[AppLanguage.english] ?? id;

  /// First letter of the name in that language: "B" for Ball, "ಚ" for ಚೆಂಡು, "ग" for गेंद.
  String firstLetter(AppLanguage language) {
    final n = name(language);
    if (n.isEmpty) return '';
    return String.fromCharCode(n.runes.first).toUpperCase();
  }

  @override
  bool operator ==(Object other) => other is ARExplorerObject && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

class ARExplorerCatalog {
  /// Everyday objects AR Explorer can recognise and teach.
  static final List<ARExplorerObject> objects = () {
    final source = [...ARHuntContent.easyObjects, ...ARHuntContent.mediumObjects];
    final seen = <String>{};
    final household = <ARExplorerObject>[];
    for (final item in source) {
      final labels = recognitionLabels[item.id];
      if (labels == null || !seen.add(item.id)) continue;
      household.add(ARExplorerObject(
        id: item.id,
        emoji: item.emoji,
        names: ContentNames.names(
            key: ContentNames.objectKey(item.englishName),
            english: item.englishName,
            kannada: item.kannadaName,
            hindi: item.hindiName),
        keywords: labels,
        shape: _shapes[item.id],
      ));
    }
    // Fruit and vegetables, named from Build the Picture's word list.
    final food = <ARExplorerObject>[];
    final foodIDs = foodLabels.keys.toList()..sort();
    for (final id in foodIDs) {
      if (seen.contains(id)) continue;
      final english = PuzzleLibrary.puzzle(id, AppLanguage.english);
      if (english == null) continue;
      food.add(ARExplorerObject(
        id: id,
        emoji: english.thumbnail,
        names: {
          for (final l in AppLanguage.values) l: PuzzleLibrary.puzzle(id, l)?.name(l) ?? english.name(AppLanguage.english)
        },
        keywords: foodLabels[id]!,
        shape: _shapes[id],
      ));
    }
    // A fan, named here (it is not in the other word lists).
    final fan = ARExplorerObject(
      id: 'fan',
      emoji: '🌀',
      names: ContentNames.names(key: ContentNames.objectKey('Fan'), english: 'Fan', kannada: 'ಫ್ಯಾನ್', hindi: 'पंखा'),
      keywords: const ['electric_fan', 'fan', 'ceiling fan'],
    );
    return [...household, ...food, fan];
  }();

  /// Recogniser labels for fruit and vegetables that Build the Picture already names.
  static const Map<String, List<String>> foodLabels = {
    'mango': ['mango'],
    'lemon': ['lemon'],
    'grapes': ['grape', 'grapes'],
    'watermelon': ['watermelon'],
    'pineapple': ['pineapple'],
    'strawberry': ['strawberry'],
    'cherries': ['cherry'],
    'peach': ['peach'],
    'pear': ['pear'],
    'kiwi': ['kiwi'],
    'coconut': ['coconut'],
    'tomato': ['tomato'],
    'carrot': ['carrot'],
    'potato': ['potato'],
    'onion': ['onion'],
  };

  /// Labels per object: the ones Apple's classifier uses on iOS plus the names ML Kit's
  /// on-device labeller gives the same things. Only specific labels: general ones such as
  /// "tableware" or "fruit" are shared by many objects and would cause wrong answers.
  static const Map<String, List<String>> recognitionLabels = {
    'apple': ['apple'],
    'banana': ['banana'],
    'orange': ['oranges', 'orange'],
    'book': ['book'],
    'pen': ['pen'],
    'scissors': ['scissors'],
    'bag': ['backpack', 'bag', 'purse', 'handbag', 'luggage'],
    'cup': ['cup', 'mug', 'coffee cup', 'teacup'],
    'bottle': ['bottle', 'water bottle'],
    'phone': ['phone', 'mobile phone', 'cell phone', 'telephone'],
    'chair': ['chair', 'chair_other', 'folding_chair', 'high_chair', 'swivel_chair', 'armchair'],
    'table': ['table', 'desk'],
    'sofa': ['sofa', 'couch'],
    'pillow': ['pillow', 'cushion'],
    'door': ['door'],
    'lamp': ['lamp'],
    'spoon': ['spoon'],
    'fork': ['fork'],
    'plate': ['plate'],
    'shoe': ['shoes', 'shoe', 'sneaker', 'sneakers', 'boot', 'sandal', 'footwear'],
    'ball': ['ball', 'golf_ball', 'basketball', 'football', 'volleyball', 'softball', 'soccer ball'],
    'flower': ['flower', 'flower_arrangement', 'rose', 'sunflower', 'petal'],
    'plant': ['plant', 'decorative_plant', 'houseplant', 'flowerpot'],
    'cat': ['cat', 'adult_cat', 'kitten'],
    'dog': ['dog', 'puppy'],
    'laptop': ['laptop'],
    'clock': ['clock', 'wall clock', 'alarm clock'],
    'glasses': ['eyeglasses', 'sunglasses', 'glasses'],
    'umbrella': ['umbrella'],
    'television': ['television', 'monitor'],
    'keyboard': ['computer_keyboard', 'computer keyboard', 'keyboard'],
    'candle': ['candle'],
  };

  static ARExplorerObject? object(String id) => objects.where((o) => o.id == id).firstOrNull;

  /// Objects found in most homes, used for memory rounds and mystery objects.
  static const commonIDs = ['cup', 'book', 'bottle', 'chair', 'shoe', 'spoon', 'ball', 'pillow', 'table', 'clock', 'phone', 'plate'];

  static List<ARExplorerObject> get commonObjects => commonIDs.map(object).whereType<ARExplorerObject>().toList();

  /// What we know about each object's shape. Objects without an entry are never used for shapes.
  static const Map<String, ExplorerShape> _shapes = {
    'ball': ExplorerShape.round, 'orange': ExplorerShape.round, 'apple': ExplorerShape.round,
    'plate': ExplorerShape.round, 'clock': ExplorerShape.round,
    'book': ExplorerShape.rectangle, 'notebook': ExplorerShape.rectangle, 'phone': ExplorerShape.rectangle,
    'laptop': ExplorerShape.rectangle, 'television': ExplorerShape.rectangle, 'door': ExplorerShape.rectangle,
    'mirror': ExplorerShape.rectangle, 'keyboard': ExplorerShape.rectangle, 'remote': ExplorerShape.rectangle,
    'pencil': ExplorerShape.long, 'pen': ExplorerShape.long, 'ruler': ExplorerShape.long, 'spoon': ExplorerShape.long,
    'fork': ExplorerShape.long, 'crayon': ExplorerShape.long, 'banana': ExplorerShape.long,
    'candle': ExplorerShape.long, 'umbrella': ExplorerShape.long, 'carrot': ExplorerShape.long,
    'tomato': ExplorerShape.round, 'coconut': ExplorerShape.round, 'onion': ExplorerShape.round,
    'peach': ExplorerShape.round,
  };

  /// Letters with at least two objects to find, in the given language.
  static List<String> huntableLetters(AppLanguage language) {
    final counts = <String, int>{};
    for (final o in objects) {
      final letter = o.firstLetter(language);
      counts[letter] = (counts[letter] ?? 0) + 1;
    }
    return (counts.entries.where((e) => e.value >= 2 && e.key.isNotEmpty).map((e) => e.key).toList())..sort();
  }

  static List<ARExplorerObject> startingWith(String letter, AppLanguage language) =>
      objects.where((o) => o.firstLetter(language) == letter).toList();

  static List<ARExplorerObject> shaped(ExplorerShape shape) => objects.where((o) => o.shape == shape).toList();

  /// Three clues per mystery object, easiest last, in every app language.
  static final Map<String, List<Localized>> mysteryClues = {
    'ball': [L('It is round.'), L('You can play with it.'), L('It can bounce!')],
    'cup': [L('You hold it in your hand.'), L('It has a handle.'), L('You drink milk from it.')],
    'book': [L('It has many pages.'), L('It has stories and pictures.'), L('You read it!')],
    'chair': [L('It has four legs.'), L('It is not an animal!'), L('You sit on it.')],
    'clock': [L('It is often on a wall.'), L('It has numbers on it.'), L('It tells the time.')],
    'spoon': [L('It lives in the kitchen.'), L('It is long and shiny.'), L('You eat rice with it.')],
    'shoe': [L('There are usually two of them.'), L('You wear it.'), L('It goes on your foot.')],
    'bottle': [L('It can hold water.'), L('It has a cap on top.'), L('You take it to school.')],
  };

  static List<ARExplorerObject> get mysteryObjects =>
      (mysteryClues.keys.toList()..sort()).map(object).whereType<ARExplorerObject>().toList();

  static String? clue(int index, String objectID, AppLanguage language) {
    final clues = mysteryClues[objectID];
    if (clues == null || index < 0 || index >= clues.length) return null;
    return clues[index].resolve(language);
  }
}
