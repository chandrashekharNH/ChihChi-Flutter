import 'dart:math' as math;

import '../../core/localization/content_names.dart';
import '../../domain/models/app_language.dart';

/// What the camera has to see: an object (classifier labels) or a colour.
sealed class ARHuntChallenge {
  const ARHuntChallenge();
}

class VisionChallenge extends ARHuntChallenge {
  const VisionChallenge(this.keywords);
  final List<String> keywords;
}

class ColorChallenge extends ARHuntChallenge {
  const ColorChallenge(this.targetHue, this.tolerance);
  final double targetHue;
  final double tolerance;
}

/// One thing to find in AR Hunt (also the shared vocabulary for Catch World and AR Explorer).
class ARHuntObject {
  ARHuntObject({
    required this.id,
    required this.emoji,
    required this.englishName,
    required this.kannadaName,
    required this.hindiName,
    List<String> visionKeywords = const [],
    double? targetHue,
    double tolerance = 0,
    int? difficulty,
  })  : challenge = targetHue == null ? VisionChallenge(visionKeywords) : ColorChallenge(targetHue, tolerance),
        difficulty = difficulty ?? (targetHue == null ? 1 : 2);

  final String id;
  final String emoji;
  final String englishName;
  final String kannadaName;
  final String hindiName;
  final ARHuntChallenge challenge;

  /// 1 = easy, 2 = medium, 3 = hard.
  final int difficulty;

  List<String> get visionKeywords {
    final c = challenge;
    return c is VisionChallenge ? c.keywords : const [];
  }

  String localizedName(AppLanguage language) => ContentNames.name(
      key: ContentNames.objectKey(englishName),
      english: englishName,
      kannada: kannadaName,
      hindi: hindiName,
      language: language);

  @override
  bool operator ==(Object other) => other is ARHuntObject && other.id == id && other.emoji == emoji;
  @override
  int get hashCode => Object.hash(id, emoji);
}

class ARHuntContent {
  static final easyObjects = <ARHuntObject>[
        // Fruit & food
        ARHuntObject(id: "apple",    emoji: "🍎", englishName: "Apple",    kannadaName: "ಸೇಬು",       hindiName: "सेब",
                     visionKeywords: ["apple", "granny smith", "fruit"]),
        ARHuntObject(id: "banana",   emoji: "🍌", englishName: "Banana",   kannadaName: "ಬಾಳೆಹಣ್ಣು", hindiName: "केला",
                     visionKeywords: ["banana"]),
        ARHuntObject(id: "orange",   emoji: "🍊", englishName: "Orange",   kannadaName: "ಕಿತ್ತಳೆ",    hindiName: "संतरा",
                     visionKeywords: ["orange", "citrus", "clementine", "tangerine"]),
        // School objects
        ARHuntObject(id: "book",     emoji: "📚", englishName: "Book",     kannadaName: "ಪುಸ್ತಕ",     hindiName: "किताब",
                     visionKeywords: ["book", "publication", "textbook", "novel"]),
        ARHuntObject(id: "pen",      emoji: "🖊️", englishName: "Pen",      kannadaName: "ಲೇಖನಿ",      hindiName: "कलम",
                     visionKeywords: ["pen", "ballpoint", "marker", "writing instrument"]),
        ARHuntObject(id: "pencil",   emoji: "✏️", englishName: "Pencil",   kannadaName: "ಪೆನ್ಸಿಲ್",  hindiName: "पेंसिल",
                     visionKeywords: ["pencil", "graphite pencil", "colored pencil", "drawing pencil"]),
        ARHuntObject(id: "notebook", emoji: "📓", englishName: "Notebook", kannadaName: "ನೋಟ್ಬುಕ್",  hindiName: "नोटबुक",
                     visionKeywords: ["notebook", "notepad", "journal", "spiral notebook", "composition book"]),
        ARHuntObject(id: "eraser",   emoji: "🧼", englishName: "Eraser",   kannadaName: "ಅಳಿಸುಗ",     hindiName: "रबर",
                     visionKeywords: ["eraser", "rubber eraser", "pencil eraser"]),
        ARHuntObject(id: "ruler",    emoji: "📏", englishName: "Ruler",    kannadaName: "ಅಳತೆಗೋಲು",  hindiName: "पैमाना",
                     visionKeywords: ["ruler", "rule", "measuring rule", "scale", "straight edge"]),
        ARHuntObject(id: "scissors", emoji: "✂️", englishName: "Scissors", kannadaName: "ಕತ್ತರಿ",     hindiName: "कैंची",
                     visionKeywords: ["scissors", "shears", "cutting tool"]),
        ARHuntObject(id: "crayon",   emoji: "🖍️", englishName: "Crayon",   kannadaName: "ಕ್ರೇಯಾನ್",  hindiName: "क्रेयॉन",
                     visionKeywords: ["crayon", "wax crayon", "colored crayon", "chalk"]),
        ARHuntObject(id: "bag",      emoji: "🎒", englishName: "Backpack", kannadaName: "ಶಾಲೆ ಚೀಲ",  hindiName: "बस्ता",
                     visionKeywords: ["bag", "backpack", "school bag", "satchel", "rucksack"]),
        // Household
        ARHuntObject(id: "cup",      emoji: "☕", englishName: "Cup",      kannadaName: "ಕಪ್",        hindiName: "कप",
                     visionKeywords: ["cup", "mug", "coffee cup", "teacup"]),
        ARHuntObject(id: "bottle",   emoji: "🍶", englishName: "Bottle",   kannadaName: "ಬಾಟಲಿ",      hindiName: "बोतल",
                     visionKeywords: ["bottle", "water bottle", "plastic bottle", "flask"]),
        ARHuntObject(id: "phone",    emoji: "📱", englishName: "Phone",    kannadaName: "ಫೋನ್",       hindiName: "फ़ोन",
                     visionKeywords: ["phone", "mobile phone", "smartphone", "iphone", "cellular"]),
        ARHuntObject(id: "chair",    emoji: "🪑", englishName: "Chair",    kannadaName: "ಕುರ್ಚಿ",     hindiName: "कुर्सी",
                     visionKeywords: ["chair", "armchair", "seat", "stool", "office chair"]),
        ARHuntObject(id: "table",    emoji: "🪵", englishName: "Table",    kannadaName: "ಮೇಜು",        hindiName: "मेज़",
                     visionKeywords: ["table", "desk", "dining table", "coffee table", "work surface"]),
        ARHuntObject(id: "sofa",     emoji: "🛋️", englishName: "Sofa",     kannadaName: "ಸೋಫಾ",       hindiName: "सोफा",
                     visionKeywords: ["sofa", "couch", "settee", "loveseat", "divan"]),
        ARHuntObject(id: "pillow",   emoji: "💤", englishName: "Pillow",   kannadaName: "ದಿಂಬು",      hindiName: "तकिया",
                     visionKeywords: ["pillow", "cushion", "bolster", "throw pillow"]),
        ARHuntObject(id: "door",     emoji: "🚪", englishName: "Door",     kannadaName: "ಬಾಗಿಲು",     hindiName: "दरवाज़ा",
                     visionKeywords: ["door", "doorway", "wood door", "entrance", "gate"]),
        ARHuntObject(id: "lamp",     emoji: "💡", englishName: "Lamp",     kannadaName: "ದೀಪ",        hindiName: "लैम्प",
                     visionKeywords: ["lamp", "light", "table lamp", "floor lamp", "light fixture"]),
        ARHuntObject(id: "spoon",    emoji: "🥄", englishName: "Spoon",    kannadaName: "ಚಮಚ",        hindiName: "चम्मच",
                     visionKeywords: ["spoon", "tablespoon", "teaspoon", "cutlery", "silverware"]),
        ARHuntObject(id: "plate",    emoji: "🍽️", englishName: "Plate",    kannadaName: "ತಟ್ಟೆ",       hindiName: "थाली",
                     visionKeywords: ["plate", "dish", "platter", "dinner plate", "saucer"]),
        ARHuntObject(id: "shoe",     emoji: "👟", englishName: "Shoe",     kannadaName: "ಶೂ",         hindiName: "जूता",
                     visionKeywords: ["shoe", "sneaker", "boot", "footwear", "sandal", "slipper"]),
        ARHuntObject(id: "ball",     emoji: "⚽", englishName: "Ball",     kannadaName: "ಚೆಂಡು",      hindiName: "गेंद",
                     visionKeywords: ["ball", "basketball", "soccer", "football", "tennis ball"]),
        ARHuntObject(id: "flower",   emoji: "🌸", englishName: "Flower",   kannadaName: "ಹೂವು",       hindiName: "फूल",
                     visionKeywords: ["flower", "rose", "daisy", "blossom", "petal", "bouquet"]),
        ARHuntObject(id: "plant",    emoji: "🌿", englishName: "Plant",    kannadaName: "ಸಸ್ಯ",       hindiName: "पौधा",
                     visionKeywords: ["plant", "houseplant", "potted plant", "succulent", "cactus"]),
        ARHuntObject(id: "cat",      emoji: "🐱", englishName: "Cat",      kannadaName: "ಬೆಕ್ಕು",     hindiName: "बिल्ली",
                     visionKeywords: ["cat", "kitten", "tabby", "feline", "domestic cat"]),
        ARHuntObject(id: "dog",      emoji: "🐶", englishName: "Dog",      kannadaName: "ನಾಯಿ",       hindiName: "कुत्ता",
                     visionKeywords: ["dog", "puppy", "canine", "hound", "labrador"]),
        ARHuntObject(id: "fork",     emoji: "🍴", englishName: "Fork",     kannadaName: "ಫೋರ್ಕ್",    hindiName: "काँटा",
                     visionKeywords: ["fork", "dinner fork", "cutlery", "silverware", "utensil"]),
  ];

  static final mediumObjects = <ARHuntObject>[
        ARHuntObject(id: "laptop",     emoji: "💻", englishName: "Laptop",    kannadaName: "ಲ್ಯಾಪ್‌ಟಾಪ್", hindiName: "लैपटॉप",
                     visionKeywords: ["laptop", "computer", "notebook computer", "macbook"], difficulty: 2),
        ARHuntObject(id: "clock",      emoji: "🕐", englishName: "Clock",     kannadaName: "ಗಡಿಯಾರ",      hindiName: "घड़ी",
                     visionKeywords: ["clock", "wall clock", "timepiece", "alarm clock"], difficulty: 2),
        ARHuntObject(id: "glasses",    emoji: "👓", englishName: "Glasses",   kannadaName: "ಕನ್ನಡಕ",     hindiName: "चश्मा",
                     visionKeywords: ["glasses", "eyeglasses", "spectacles", "sunglasses"], difficulty: 2),
        ARHuntObject(id: "key",        emoji: "🔑", englishName: "Key",       kannadaName: "ಕೀಲಿ",        hindiName: "चाबी",
                     visionKeywords: ["key", "door key", "house key", "car key"], difficulty: 2),
        ARHuntObject(id: "umbrella",   emoji: "☂️", englishName: "Umbrella",  kannadaName: "ಛತ್ರಿ",       hindiName: "छाता",
                     visionKeywords: ["umbrella", "parasol", "brolly"], difficulty: 2),
        ARHuntObject(id: "remote",     emoji: "🎛️", englishName: "Remote",    kannadaName: "ರಿಮೋಟ್",      hindiName: "रिमोट",
                     visionKeywords: ["remote", "remote control", "tv remote", "controller"], difficulty: 2),
        ARHuntObject(id: "television", emoji: "📺", englishName: "TV",        kannadaName: "ದೂರದರ್ಶನ",    hindiName: "टीवी",
                     visionKeywords: ["television", "tv set", "monitor", "screen", "flat screen"], difficulty: 2),
        ARHuntObject(id: "mirror",     emoji: "🪞", englishName: "Mirror",    kannadaName: "ಕನ್ನಡಿ",      hindiName: "दर्पण",
                     visionKeywords: ["mirror", "reflection", "looking glass", "bathroom mirror"], difficulty: 2),
        ARHuntObject(id: "towel",      emoji: "🧣", englishName: "Towel",     kannadaName: "ಟವಲ್",        hindiName: "तौलिया",
                     visionKeywords: ["towel", "hand towel", "bath towel", "washcloth"], difficulty: 2),
        ARHuntObject(id: "keyboard",   emoji: "⌨️", englishName: "Keyboard",  kannadaName: "ಕೀಬೋರ್ಡ್",   hindiName: "कीबोर्ड",
                     visionKeywords: ["keyboard", "computer keyboard", "qwerty", "typewriter"], difficulty: 2),
        ARHuntObject(id: "candle",     emoji: "🕯️", englishName: "Candle",    kannadaName: "ಮೇಣಬತ್ತಿ",   hindiName: "मोमबत्ती",
                     visionKeywords: ["candle", "candlestick", "taper candle", "wax candle"], difficulty: 2),
        // Color challenges
        ARHuntObject(id: "color_red",    emoji: "🔴", englishName: "Something RED",    kannadaName: "ಕೆಂಪು ವಸ್ತು",   hindiName: "लाल चीज़",
                     targetHue: 0.00, tolerance: 0.07, difficulty: 2),
        ARHuntObject(id: "color_blue",   emoji: "🔵", englishName: "Something BLUE",   kannadaName: "ನೀಲಿ ವಸ್ತು",    hindiName: "नीली चीज़",
                     targetHue: 0.60, tolerance: 0.08, difficulty: 2),
        ARHuntObject(id: "color_yellow", emoji: "🟡", englishName: "Something YELLOW", kannadaName: "ಹಳದಿ ವಸ್ತು",    hindiName: "पीली चीज़",
                     targetHue: 0.15, tolerance: 0.06, difficulty: 2),
        ARHuntObject(id: "color_green",  emoji: "🟢", englishName: "Something GREEN",  kannadaName: "ಹಸಿರು ವಸ್ತು",   hindiName: "हरी चीज़",
                     targetHue: 0.33, tolerance: 0.08, difficulty: 2),
        ARHuntObject(id: "color_orange", emoji: "🟠", englishName: "Something ORANGE", kannadaName: "ಕಿತ್ತಳೆ ವಸ್ತು",  hindiName: "नारंगी चीज़",
                     targetHue: 0.07, tolerance: 0.05, difficulty: 2),
  ];

  static final hardObjects = <ARHuntObject>[
        // Uncommon colors
        ARHuntObject(id: "color_purple", emoji: "🟣", englishName: "Something PURPLE", kannadaName: "ನೇರಳೆ ವಸ್ತು",   hindiName: "बैंगनी चीज़",
                     targetHue: 0.78, tolerance: 0.07, difficulty: 3),
        ARHuntObject(id: "color_pink",   emoji: "🩷", englishName: "Something PINK",   kannadaName: "ಗುಲಾಬಿ ವಸ್ತು",   hindiName: "गुलाबी चीज़",
                     targetHue: 0.93, tolerance: 0.05, difficulty: 3),
        // Abstract / conceptual shape challenges
        ARHuntObject(id: "round_thing",  emoji: "⭕", englishName: "A Round Thing",    kannadaName: "ದುಂಡಾದ ವಸ್ತು",  hindiName: "गोल चीज़",
                     visionKeywords: ["ball", "sphere", "wheel", "plate", "bowl", "disc", "coin", "orange", "apple", "circle", "clock", "button"],
                     difficulty: 3),
        ARHuntObject(id: "soft_thing",   emoji: "🧸", englishName: "Something Soft",   kannadaName: "ಮೃದುವಾದ ವಸ್ತು", hindiName: "मुलायम चीज़",
                     visionKeywords: ["teddy", "stuffed animal", "plush", "pillow", "blanket", "cushion", "soft toy", "fur", "towel", "sock"],
                     difficulty: 3),
        ARHuntObject(id: "tiny_thing",   emoji: "🔍", englishName: "Something Tiny",   kannadaName: "ಸಣ್ಣ ವಸ್ತು",    hindiName: "छोटी चीज़",
                     visionKeywords: ["coin", "button", "bead", "pebble", "pin", "eraser", "key", "clip", "ring", "magnet"],
                     difficulty: 3),
  ];

  static final alphabetWordObjects = <ARHuntObject>[
        ARHuntObject(id: "alpha_apple", emoji: "🍎", englishName: "Apple", kannadaName: "ಸೇಬು", hindiName: "सेब", visionKeywords: ["apple", "fruit"]),
        ARHuntObject(id: "alpha_ball", emoji: "⚽", englishName: "Ball", kannadaName: "ಚೆಂಡು", hindiName: "गेंद", visionKeywords: ["ball", "football", "soccer ball"]),
        ARHuntObject(id: "alpha_cat", emoji: "🐱", englishName: "Cat", kannadaName: "ಬೆಕ್ಕು", hindiName: "बिल्ली", visionKeywords: ["cat", "kitten"]),
        ARHuntObject(id: "alpha_dog", emoji: "🐶", englishName: "Dog", kannadaName: "ನಾಯಿ", hindiName: "कुत्ता", visionKeywords: ["dog", "puppy"]),
        ARHuntObject(id: "alpha_elephant", emoji: "🐘", englishName: "Elephant", kannadaName: "ಆನೆ", hindiName: "हाथी", visionKeywords: ["elephant"]),
        ARHuntObject(id: "alpha_fish", emoji: "🐟", englishName: "Fish", kannadaName: "ಮೀನು", hindiName: "मछली", visionKeywords: ["fish"]),
        ARHuntObject(id: "alpha_grapes", emoji: "🍇", englishName: "Grapes", kannadaName: "ದ್ರಾಕ್ಷಿ", hindiName: "अंगूर", visionKeywords: ["grapes", "grape"]),
        ARHuntObject(id: "alpha_hat", emoji: "🎩", englishName: "Hat", kannadaName: "ಟೋಪಿ", hindiName: "टोपी", visionKeywords: ["hat", "cap"]),
        ARHuntObject(id: "alpha_icecream", emoji: "🍦", englishName: "Ice Cream", kannadaName: "ಐಸ್ ಕ್ರೀಮ್", hindiName: "आइसक्रीम", visionKeywords: ["ice cream", "icecream"]),
        ARHuntObject(id: "alpha_juice", emoji: "🧃", englishName: "Juice", kannadaName: "ರಸ", hindiName: "जूस", visionKeywords: ["juice", "drink"]),
        ARHuntObject(id: "alpha_kite", emoji: "🪁", englishName: "Kite", kannadaName: "ಗಾಳಿಪಟ", hindiName: "पतंग", visionKeywords: ["kite"]),
        ARHuntObject(id: "alpha_lion", emoji: "🦁", englishName: "Lion", kannadaName: "ಸಿಂಹ", hindiName: "शेर", visionKeywords: ["lion"]),
        ARHuntObject(id: "alpha_mango", emoji: "🥭", englishName: "Mango", kannadaName: "ಮಾವು", hindiName: "आम", visionKeywords: ["mango", "fruit"]),
        ARHuntObject(id: "alpha_nest", emoji: "🪺", englishName: "Nest", kannadaName: "ಗೂಡು", hindiName: "घोंसला", visionKeywords: ["nest", "bird nest"]),
        ARHuntObject(id: "alpha_orange", emoji: "🍊", englishName: "Orange", kannadaName: "ಕಿತ್ತಳೆ", hindiName: "संतरा", visionKeywords: ["orange", "citrus"]),
        ARHuntObject(id: "alpha_pencil", emoji: "✏️", englishName: "Pencil", kannadaName: "ಪೆನ್ಸಿಲ್", hindiName: "पेंसिल", visionKeywords: ["pencil"]),
        ARHuntObject(id: "alpha_queen", emoji: "👑", englishName: "Queen", kannadaName: "ರಾಣಿ", hindiName: "रानी", visionKeywords: ["queen", "crown"]),
        ARHuntObject(id: "alpha_rabbit", emoji: "🐰", englishName: "Rabbit", kannadaName: "ಮೊಲ", hindiName: "खरगोश", visionKeywords: ["rabbit", "bunny"]),
        ARHuntObject(id: "alpha_sun", emoji: "☀️", englishName: "Sun", kannadaName: "ಸೂರ್ಯ", hindiName: "सूरज", visionKeywords: ["sun"]),
        ARHuntObject(id: "alpha_tiger", emoji: "🐯", englishName: "Tiger", kannadaName: "ಹುಲಿ", hindiName: "बाघ", visionKeywords: ["tiger"]),
        ARHuntObject(id: "alpha_umbrella", emoji: "☂️", englishName: "Umbrella", kannadaName: "ಛತ್ರಿ", hindiName: "छाता", visionKeywords: ["umbrella"]),
        ARHuntObject(id: "alpha_van", emoji: "🚐", englishName: "Van", kannadaName: "ವ್ಯಾನ್", hindiName: "वैन", visionKeywords: ["van", "minivan"]),
        ARHuntObject(id: "alpha_watch", emoji: "⌚", englishName: "Watch", kannadaName: "ಗಡಿಯಾರ", hindiName: "घड़ी", visionKeywords: ["watch", "wristwatch"]),
        ARHuntObject(id: "alpha_xylophone", emoji: "🎼", englishName: "Xylophone", kannadaName: "ಕ್ಸೈಲೋಫೋನ್", hindiName: "ज़ाइलोफोन", visionKeywords: ["xylophone"]),
        ARHuntObject(id: "alpha_yoyo", emoji: "🪀", englishName: "Yo-Yo", kannadaName: "ಯೋ-ಯೋ", hindiName: "यो-यो", visionKeywords: ["yo-yo", "yoyo"]),
        ARHuntObject(id: "alpha_zebra", emoji: "🦓", englishName: "Zebra", kannadaName: "ಜೀಬ್ರಾ", hindiName: "ज़ेब्रा", visionKeywords: ["zebra"])
  ];

  static List<ARHuntObject> get allObjects => [...easyObjects, ...mediumObjects, ...hardObjects];

  /// Returns `count` shuffled objects appropriate for the given game level.
  /// - Level 0–2: easy objects only
  /// - Level 3–5: easy + up to 2 medium (colors/harder items)
  /// - Level 6+:  easy + 2 medium + 2 hard (abstract challenges)
  static List<ARHuntObject> randomObjects(int count, {int level = 0, math.Random? random}) {
    final r = random ?? math.Random();
    final easy = [...easyObjects]..shuffle(r);
    final medium = [...mediumObjects]..shuffle(r);
    final hard = [...hardObjects]..shuffle(r);
    List<ARHuntObject> selected;
    if (level <= 2) {
      selected = easy.take(count).toList();
    } else if (level <= 5) {
      final med = math.min(2, medium.length);
      selected = [...easy.take(math.max(0, count - med)), ...medium.take(med)];
    } else {
      final h = math.min(2, hard.length);
      final med = math.min(2, medium.length);
      selected = [...easy.take(math.max(0, count - h - med)), ...medium.take(med), ...hard.take(h)];
    }
    return selected..shuffle(r);
  }
}
