import '../../domain/models/app_language.dart';
import '../../domain/models/game_object.dart';
import '../../domain/models/letter_lesson.dart';
import 'game_content_provider.dart';

class HindiContentProvider extends GameContentProviding {
  @override
  AppLanguage get language => AppLanguage.hindi;

  @override
  final List<GameObject> allObjects = const [
    GameObject(id: 'pomegranate', emoji: '🍎', category: ObjectCategory.fruit),
    GameObject(id: 'mango', emoji: '🥭', category: ObjectCategory.fruit),
    GameObject(id: 'owl', emoji: '🦉', category: ObjectCategory.animal),
    GameObject(id: 'camel', emoji: '🐪', category: ObjectCategory.animal),
    GameObject(id: 'elephant', emoji: '🐘', category: ObjectCategory.animal),
    GameObject(id: 'horse', emoji: '🐴', category: ObjectCategory.animal),
    GameObject(id: 'cow', emoji: '🐄', category: ObjectCategory.animal),
    GameObject(id: 'lion', emoji: '🦁', category: ObjectCategory.animal),
    GameObject(id: 'tiger', emoji: '🐯', category: ObjectCategory.animal),
    GameObject(id: 'rabbit', emoji: '🐰', category: ObjectCategory.animal),
    GameObject(id: 'parrot', emoji: '🦜', category: ObjectCategory.animal),
    GameObject(id: 'fish', emoji: '🐟', category: ObjectCategory.animal),
    GameObject(id: 'flower', emoji: '🌸', category: ObjectCategory.nature),
    GameObject(id: 'tree', emoji: '🌳', category: ObjectCategory.nature),
    GameObject(id: 'sun', emoji: '☀️', category: ObjectCategory.nature),
    GameObject(id: 'moon', emoji: '🌙', category: ObjectCategory.nature),
    GameObject(id: 'star', emoji: '⭐', category: ObjectCategory.nature),
    GameObject(id: 'house', emoji: '🏠', category: ObjectCategory.nature),
    GameObject(id: 'apple', emoji: '🍎', category: ObjectCategory.fruit),
    GameObject(id: 'banana', emoji: '🍌', category: ObjectCategory.fruit),
    GameObject(id: 'snake', emoji: '🐍', category: ObjectCategory.animal),
    GameObject(id: 'frog', emoji: '🐸', category: ObjectCategory.animal),
    GameObject(id: 'cat', emoji: '🐱', category: ObjectCategory.animal),
    GameObject(id: 'dog', emoji: '🐶', category: ObjectCategory.animal),
    GameObject(id: 'lotus', emoji: '🪷', category: ObjectCategory.nature),
    GameObject(id: 'bear', emoji: '🐻', category: ObjectCategory.animal),
  ];

  static const Map<String, String> _objectNames = {
    'pomegranate': 'अनार',
    'mango': 'आम',
    'owl': 'उल्लू',
    'camel': 'ऊँट',
    'elephant': 'हाथी',
    'horse': 'घोड़ा',
    'cow': 'गाय',
    'lion': 'शेर',
    'tiger': 'बाघ',
    'rabbit': 'खरगोश',
    'parrot': 'तोता',
    'fish': 'मछली',
    'flower': 'फूल',
    'tree': 'पेड़',
    'sun': 'सूरज',
    'moon': 'चाँद',
    'star': 'तारा',
    'house': 'घर',
    'apple': 'सेब',
    'banana': 'केला',
    'snake': 'साँप',
    'frog': 'मेंढक',
    'cat': 'बिल्ली',
    'dog': 'कुत्ता',
    'lotus': 'कमल',
    'bear': 'भालू',
  };

  static const _data = [
    ('hi_a', 'अ', 'a', 'pomegranate', ['cat', 'dog', 'fish']),
    ('hi_aa', 'आ', 'aa', 'mango', ['apple', 'banana', 'flower']),
    ('hi_i', 'इ', 'i', 'elephant', ['lion', 'tiger', 'cow']),
    ('hi_ii', 'ई', 'ii', 'parrot', ['owl', 'cat', 'fish']),
    ('hi_u', 'उ', 'u', 'owl', ['parrot', 'cat', 'rabbit']),
    ('hi_uu', 'ऊ', 'uu', 'camel', ['horse', 'cow', 'elephant']),
    ('hi_e', 'ए', 'e', 'flower', ['tree', 'sun', 'moon']),
    ('hi_o', 'ओ', 'o', 'frog', ['fish', 'snake', 'cat']),
    ('hi_ka', 'क', 'ka', 'lotus', ['flower', 'tree', 'star']),
    ('hi_kha', 'ख', 'kha', 'rabbit', ['cat', 'frog', 'fish']),
    ('hi_ga', 'ग', 'ga', 'cow', ['horse', 'lion', 'elephant']),
    ('hi_gha', 'घ', 'gha', 'horse', ['cow', 'dog', 'cat']),
    ('hi_cha', 'च', 'cha', 'moon', ['sun', 'star', 'flower']),
    ('hi_ja', 'ज', 'ja', 'fish', ['frog', 'snake', 'cat']),
    ('hi_ta', 'त', 'ta', 'parrot', ['owl', 'dog', 'cat']),
    ('hi_tha', 'थ', 'tha', 'flower', ['tree', 'sun', 'star']),
    ('hi_da', 'द', 'da', 'elephant', ['lion', 'tiger', 'cow']),
    ('hi_na', 'न', 'na', 'snake', ['fish', 'frog', 'cat']),
    ('hi_pa', 'प', 'pa', 'flower', ['tree', 'sun', 'moon']),
    ('hi_fa', 'फ', 'fa', 'flower', ['butterfly', 'tree', 'sun']),
    ('hi_ba', 'ब', 'ba', 'tiger', ['lion', 'cat', 'dog']),
    ('hi_bha', 'भ', 'bha', 'bear', ['lion', 'tiger', 'elephant']),
    ('hi_ma', 'म', 'ma', 'fish', ['frog', 'snake', 'cat']),
    ('hi_ya', 'य', 'ya', 'elephant', ['cow', 'horse', 'camel']),
    ('hi_ra', 'र', 'ra', 'parrot', ['owl', 'cat', 'fish']),
    ('hi_la', 'ल', 'la', 'lion', ['tiger', 'cat', 'dog']),
    ('hi_va', 'व', 'va', 'tree', ['flower', 'house', 'sun']),
    ('hi_sha', 'श', 'sha', 'lion', ['tiger', 'elephant', 'cow']),
    ('hi_sa', 'स', 'sa', 'apple', ['mango', 'banana', 'flower']),
    ('hi_ha', 'ह', 'ha', 'elephant', ['horse', 'cow', 'camel']),
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
        languageCode: 'hi',
      ),
  ];

  @override
  String localizedName(String objectID) => _objectNames[objectID] ?? objectID;

}
