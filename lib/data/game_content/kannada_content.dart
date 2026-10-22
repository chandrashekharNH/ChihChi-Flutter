import '../../domain/models/app_language.dart';
import '../../domain/models/game_object.dart';
import '../../domain/models/letter_lesson.dart';
import 'game_content_provider.dart';

class KannadaContentProvider extends GameContentProviding {
  @override
  AppLanguage get language => AppLanguage.kannada;

  @override
  final List<GameObject> allObjects = const [
    GameObject(id: 'apple', emoji: '🍎', category: ObjectCategory.fruit),
    GameObject(id: 'elephant', emoji: '🐘', category: ObjectCategory.animal),
    GameObject(id: 'mouse', emoji: '🐭', category: ObjectCategory.animal),
    GameObject(id: 'mango', emoji: '🥭', category: ObjectCategory.fruit),
    GameObject(id: 'peacock', emoji: '🦚', category: ObjectCategory.animal),
    GameObject(id: 'cat', emoji: '🐱', category: ObjectCategory.animal),
    GameObject(id: 'dog', emoji: '🐶', category: ObjectCategory.animal),
    GameObject(id: 'fish', emoji: '🐟', category: ObjectCategory.animal),
    GameObject(id: 'banana', emoji: '🍌', category: ObjectCategory.fruit),
    GameObject(id: 'lion', emoji: '🦁', category: ObjectCategory.animal),
    GameObject(id: 'flower', emoji: '🌸', category: ObjectCategory.nature),
    GameObject(id: 'tree', emoji: '🌳', category: ObjectCategory.nature),
    GameObject(id: 'sun', emoji: '☀️', category: ObjectCategory.nature),
    GameObject(id: 'moon', emoji: '🌙', category: ObjectCategory.nature),
    GameObject(id: 'star', emoji: '⭐', category: ObjectCategory.nature),
    GameObject(id: 'house', emoji: '🏠', category: ObjectCategory.nature),
    GameObject(id: 'butterfly', emoji: '🦋', category: ObjectCategory.animal),
    GameObject(id: 'rabbit', emoji: '🐰', category: ObjectCategory.animal),
    GameObject(id: 'cow', emoji: '🐄', category: ObjectCategory.animal),
    GameObject(id: 'parrot', emoji: '🦜', category: ObjectCategory.animal),
    GameObject(id: 'snake', emoji: '🐍', category: ObjectCategory.animal),
    GameObject(id: 'frog', emoji: '🐸', category: ObjectCategory.animal),
    GameObject(id: 'orange', emoji: '🍊', category: ObjectCategory.fruit),
    GameObject(id: 'grapes', emoji: '🍇', category: ObjectCategory.fruit),
  ];

  static const Map<String, String> _objectNames = {
    'apple': 'ಸೇಬು',
    'elephant': 'ಆನೆ',
    'mouse': 'ಇಲಿ',
    'mango': 'ಮಾವಿನ ಹಣ್ಣು',
    'peacock': 'ನವಿಲು',
    'cat': 'ಬೆಕ್ಕು',
    'dog': 'ನಾಯಿ',
    'fish': 'ಮೀನು',
    'banana': 'ಬಾಳೆ',
    'lion': 'ಸಿಂಹ',
    'flower': 'ಹೂವು',
    'tree': 'ಮರ',
    'sun': 'ಸೂರ್ಯ',
    'moon': 'ಚಂದ್ರ',
    'star': 'ನಕ್ಷತ್ರ',
    'house': 'ಮನೆ',
    'butterfly': 'ಚಿಟ್ಟೆ',
    'rabbit': 'ಮೊಲ',
    'cow': 'ಹಸು',
    'parrot': 'ಗಿಳಿ',
    'snake': 'ಹಾವು',
    'frog': 'ಕಪ್ಪೆ',
    'orange': 'ಕಿತ್ತಳೆ',
    'grapes': 'ದ್ರಾಕ್ಷಿ',
  };

  static const _data = [
    ('kn_a', 'ಅ', 'a', 'apple', ['cat', 'dog', 'fish']),
    ('kn_aa', 'ಆ', 'aa', 'elephant', ['cat', 'mouse', 'fish']),
    ('kn_i', 'ಇ', 'i', 'mouse', ['cat', 'elephant', 'rabbit']),
    ('kn_ii', 'ಈ', 'ii', 'parrot', ['peacock', 'cat', 'dog']),
    ('kn_u', 'ಉ', 'u', 'rabbit', ['cat', 'mouse', 'dog']),
    ('kn_uu', 'ಊ', 'uu', 'frog', ['fish', 'snake', 'mouse']),
    ('kn_e', 'ಏ', 'e', 'butterfly', ['flower', 'tree', 'fish']),
    ('kn_o', 'ಓ', 'o', 'mango', ['apple', 'banana', 'grapes']),
    ('kn_ka', 'ಕ', 'ka', 'peacock', ['elephant', 'lion', 'dog']),
    ('kn_kha', 'ಖ', 'kha', 'rabbit', ['cat', 'frog', 'fish']),
    ('kn_ga', 'ಗ', 'ga', 'cow', ['dog', 'lion', 'elephant']),
    ('kn_cha', 'ಚ', 'cha', 'cat', ['dog', 'rabbit', 'fish']),
    ('kn_ja', 'ಜ', 'ja', 'grapes', ['apple', 'banana', 'mango']),
    ('kn_ta', 'ಟ', 'ta', 'flower', ['tree', 'sun', 'moon']),
    ('kn_da', 'ಡ', 'da', 'frog', ['cat', 'dog', 'fish']),
    ('kn_na', 'ನ', 'na', 'peacock', ['parrot', 'cat', 'dog']),
    ('kn_pa', 'ಪ', 'pa', 'flower', ['butterfly', 'tree', 'sun']),
    ('kn_ba', 'ಬ', 'ba', 'banana', ['apple', 'mango', 'grapes']),
    ('kn_ma', 'ಮ', 'ma', 'fish', ['cat', 'dog', 'rabbit']),
    ('kn_ya', 'ಯ', 'ya', 'elephant', ['lion', 'dog', 'cat']),
    ('kn_ra', 'ರ', 'ra', 'peacock', ['butterfly', 'flower', 'parrot']),
    ('kn_la', 'ಲ', 'la', 'lion', ['elephant', 'dog', 'rabbit']),
    ('kn_va', 'ವ', 'va', 'tree', ['flower', 'house', 'sun']),
    ('kn_sha', 'ಶ', 'sha', 'snake', ['fish', 'frog', 'cat']),
    ('kn_sa', 'ಸ', 'sa', 'sun', ['moon', 'star', 'flower']),
    ('kn_ha', 'ಹ', 'ha', 'elephant', ['cow', 'dog', 'lion']),
  ];

  @override
  late final List<LetterLesson> letterLessons = [
    for (final (id, symbol, phonetic, target, distractors) in _data)
      LetterLesson(
        id: id,
        symbol: symbol,
        symbolPhoneticHint: phonetic,
        targetObjectID: target,
        targetObjectName: _objectNames[target] ?? target,
        distractorObjectIDs: distractors,
        languageCode: 'kn',
      ),
  ];

  @override
  String localizedName(String objectID) => _objectNames[objectID] ?? objectID;

}
