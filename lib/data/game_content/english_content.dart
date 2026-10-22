import '../../domain/models/app_language.dart';
import '../../domain/models/game_object.dart';
import '../../domain/models/letter_lesson.dart';
import 'game_content_provider.dart';

class EnglishContentProvider extends GameContentProviding {
  @override
  AppLanguage get language => AppLanguage.english;

  @override
  final List<GameObject> allObjects = const [
    GameObject(id: 'apple', emoji: '🍎', category: ObjectCategory.fruit),
    GameObject(id: 'ball', emoji: '⚽', category: ObjectCategory.toy),
    GameObject(id: 'cat', emoji: '🐱', category: ObjectCategory.animal),
    GameObject(id: 'dog', emoji: '🐶', category: ObjectCategory.animal),
    GameObject(id: 'elephant', emoji: '🐘', category: ObjectCategory.animal),
    GameObject(id: 'fish', emoji: '🐟', category: ObjectCategory.animal),
    GameObject(id: 'grapes', emoji: '🍇', category: ObjectCategory.fruit),
    GameObject(id: 'hat', emoji: '🎩', category: ObjectCategory.toy),
    GameObject(id: 'ice_cream', emoji: '🍦', category: ObjectCategory.food),
    GameObject(id: 'jellyfish', emoji: '🪼', category: ObjectCategory.animal),
    GameObject(id: 'kite', emoji: '🪁', category: ObjectCategory.toy),
    GameObject(id: 'lion', emoji: '🦁', category: ObjectCategory.animal),
    GameObject(id: 'mango', emoji: '🥭', category: ObjectCategory.fruit),
    GameObject(id: 'nest', emoji: '🪺', category: ObjectCategory.nature),
    GameObject(id: 'orange', emoji: '🍊', category: ObjectCategory.fruit),
    GameObject(id: 'pig', emoji: '🐷', category: ObjectCategory.animal),
    GameObject(id: 'queen', emoji: '👑', category: ObjectCategory.toy),
    GameObject(id: 'rabbit', emoji: '🐰', category: ObjectCategory.animal),
    GameObject(id: 'sun', emoji: '☀️', category: ObjectCategory.nature),
    GameObject(id: 'tiger', emoji: '🐯', category: ObjectCategory.animal),
    GameObject(id: 'umbrella', emoji: '☂️', category: ObjectCategory.toy),
    GameObject(id: 'violin', emoji: '🎻', category: ObjectCategory.toy),
    GameObject(id: 'whale', emoji: '🐳', category: ObjectCategory.animal),
    GameObject(id: 'xylophone', emoji: '🎶', category: ObjectCategory.toy),
    GameObject(id: 'yak', emoji: '🦬', category: ObjectCategory.animal),
    GameObject(id: 'zebra', emoji: '🦓', category: ObjectCategory.animal),
    GameObject(id: 'banana', emoji: '🍌', category: ObjectCategory.fruit),
    GameObject(id: 'strawberry', emoji: '🍓', category: ObjectCategory.fruit),
    GameObject(id: 'butterfly', emoji: '🦋', category: ObjectCategory.animal),
    GameObject(id: 'flower', emoji: '🌸', category: ObjectCategory.nature),
    GameObject(id: 'star', emoji: '⭐', category: ObjectCategory.nature),
    GameObject(id: 'moon', emoji: '🌙', category: ObjectCategory.nature),
    GameObject(id: 'rocket', emoji: '🚀', category: ObjectCategory.vehicle),
    GameObject(id: 'car', emoji: '🚗', category: ObjectCategory.vehicle),
    GameObject(id: 'house', emoji: '🏠', category: ObjectCategory.nature),
    GameObject(id: 'tree', emoji: '🌳', category: ObjectCategory.nature),
    GameObject(id: 'cake', emoji: '🎂', category: ObjectCategory.food),
    GameObject(id: 'bird', emoji: '🐦', category: ObjectCategory.animal),
    GameObject(id: 'frog', emoji: '🐸', category: ObjectCategory.animal),
    GameObject(id: 'cow', emoji: '🐄', category: ObjectCategory.animal),
  ];

  static const Map<String, String> _objectNames = {
    'apple': 'Apple',
    'ball': 'Ball',
    'cat': 'Cat',
    'dog': 'Dog',
    'elephant': 'Elephant',
    'fish': 'Fish',
    'grapes': 'Grapes',
    'hat': 'Hat',
    'ice_cream': 'Ice Cream',
    'jellyfish': 'Jellyfish',
    'kite': 'Kite',
    'lion': 'Lion',
    'mango': 'Mango',
    'nest': 'Nest',
    'orange': 'Orange',
    'pig': 'Pig',
    'queen': 'Queen',
    'rabbit': 'Rabbit',
    'sun': 'Sun',
    'tiger': 'Tiger',
    'umbrella': 'Umbrella',
    'violin': 'Violin',
    'whale': 'Whale',
    'xylophone': 'Xylophone',
    'yak': 'Yak',
    'zebra': 'Zebra',
    'banana': 'Banana',
    'strawberry': 'Strawberry',
    'butterfly': 'Butterfly',
    'flower': 'Flower',
    'star': 'Star',
    'moon': 'Moon',
    'rocket': 'Rocket',
    'car': 'Car',
    'house': 'House',
    'tree': 'Tree',
    'cake': 'Cake',
    'bird': 'Bird',
    'frog': 'Frog',
    'cow': 'Cow',
  };

  static const _data = [
    ('en_A', 'A', 'A', 'apple', ['ball', 'cat', 'dog', 'flower']),
    ('en_B', 'B', 'B', 'ball', ['apple', 'cat', 'elephant', 'frog']),
    ('en_C', 'C', 'C', 'cat', ['dog', 'apple', 'rabbit', 'fish']),
    ('en_D', 'D', 'D', 'dog', ['cat', 'elephant', 'fish', 'cow']),
    ('en_E', 'E', 'E', 'elephant', ['dog', 'cat', 'lion', 'rabbit']),
    ('en_F', 'F', 'F', 'fish', ['cat', 'elephant', 'rabbit', 'frog']),
    ('en_G', 'G', 'G', 'grapes', ['apple', 'orange', 'mango', 'banana']),
    ('en_H', 'H', 'H', 'hat', ['umbrella', 'kite', 'sun', 'ball']),
    ('en_I', 'I', 'I', 'ice_cream', ['mango', 'orange', 'grapes', 'cake']),
    ('en_J', 'J', 'J', 'jellyfish', ['fish', 'whale', 'cat', 'frog']),
    ('en_K', 'K', 'K', 'kite', ['hat', 'umbrella', 'star', 'ball']),
    ('en_L', 'L', 'L', 'lion', ['tiger', 'cat', 'elephant', 'dog']),
    ('en_M', 'M', 'M', 'mango', ['apple', 'orange', 'grapes', 'banana']),
    ('en_N', 'N', 'N', 'nest', ['house', 'tree', 'flower', 'moon']),
    ('en_O', 'O', 'O', 'orange', ['apple', 'mango', 'grapes', 'banana']),
    ('en_P', 'P', 'P', 'pig', ['dog', 'cat', 'rabbit', 'cow']),
    ('en_Q', 'Q', 'Q', 'queen', ['hat', 'star', 'moon', 'sun']),
    ('en_R', 'R', 'R', 'rabbit', ['cat', 'dog', 'pig', 'frog']),
    ('en_S', 'S', 'S', 'sun', ['moon', 'star', 'flower', 'tree']),
    ('en_T', 'T', 'T', 'tiger', ['lion', 'cat', 'elephant', 'dog']),
    ('en_U', 'U', 'U', 'umbrella', ['hat', 'kite', 'star', 'ball']),
    ('en_V', 'V', 'V', 'violin', ['xylophone', 'star', 'flower', 'kite']),
    ('en_W', 'W', 'W', 'whale', ['fish', 'jellyfish', 'cat', 'frog']),
    ('en_X', 'X', 'X', 'xylophone', ['violin', 'rocket', 'star', 'hat']),
    ('en_Y', 'Y', 'Y', 'yak', ['elephant', 'tiger', 'lion', 'cow']),
    ('en_Z', 'Z', 'Z', 'zebra', ['tiger', 'lion', 'elephant', 'dog']),
  ];

  @override
  late final List<LetterLesson> letterLessons = [
    for (final (id, symbol, phonetic, target, distractors) in _data)
      LetterLesson(
        id: id,
        symbol: symbol,
        symbolPhoneticHint: phonetic,
        targetObjectID: target,
        targetObjectName: _objectNames[target] ?? _capitalize(target),
        distractorObjectIDs: distractors,
        languageCode: 'en',
      ),
  ];

  @override
  String localizedName(String objectID) => _objectNames[objectID] ?? _capitalize(objectID);

  static String _capitalize(String s) => s.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

}
