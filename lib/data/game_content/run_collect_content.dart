import 'dart:math' as math;

import '../../domain/models/app_language.dart';
import '../../domain/models/run_collect.dart';
import 'language_pack.dart';

class RunCollectContent {
  // English A-Z
  static final List<RunCollectTarget> englishLetters = [
    _t('a', 'A', '🍎', 'Apple', 'ಸೇಬು', 'सेब', 'A', 1),
    _t('b', 'B', '⚽', 'Ball', 'ಚೆಂಡು', 'गेंद', 'B', 1),
    _t('c', 'C', '🐱', 'Cat', 'ಬೆಕ್ಕು', 'बिल्ली', 'C', 1),
    _t('d', 'D', '🐶', 'Dog', 'ನಾಯಿ', 'कुत्ता', 'D', 1),
    _t('e', 'E', '🐘', 'Elephant', 'ಆನೆ', 'हाथी', 'E', 1),
    _t('f', 'F', '🐟', 'Fish', 'ಮೀನು', 'मछली', 'F', 1),
    _t('g', 'G', '🍇', 'Grapes', 'ದ್ರಾಕ್ಷಿ', 'अंगूर', 'G', 1),
    _t('h', 'H', '🎩', 'Hat', 'ಟೋಪಿ', 'टोपी', 'H', 1),
    _t('i', 'I', '🍦', 'Ice Cream', 'ಐಸ್ ಕ್ರೀಮ್', 'आइसक्रीम', 'I', 1),
    _t('j', 'J', '🧃', 'Juice', 'ಜ್ಯೂಸ್', 'जूस', 'J', 1),
    _t('k', 'K', '🪁', 'Kite', 'ಗಾಳಿಪಟ', 'पतंग', 'K', 1),
    _t('l', 'L', '🦁', 'Lion', 'ಸಿಂಹ', 'शेर', 'L', 1),
    _t('m', 'M', '🥭', 'Mango', 'ಮಾವು', 'आम', 'M', 1),
    _t('n', 'N', '🪺', 'Nest', 'ಗೂಡು', 'घोंसला', 'N', 1),
    _t('o', 'O', '🍊', 'Orange', 'ಕಿತ್ತಳೆ', 'संतरा', 'O', 1),
    _t('p', 'P', '✏️', 'Pencil', 'ಪೆನ್ಸಿಲ್', 'पेंसिल', 'P', 1),
    _t('q', 'Q', '👑', 'Queen', 'ರಾಣಿ', 'रानी', 'Q', 2),
    _t('r', 'R', '🐰', 'Rabbit', 'ಮೊಲ', 'खरगोश', 'R', 1),
    _t('s', 'S', '☀️', 'Sun', 'ಸೂರ್ಯ', 'सूरज', 'S', 1),
    _t('t', 'T', '🐯', 'Tiger', 'ಹುಲಿ', 'बाघ', 'T', 1),
    _t('u', 'U', '☂️', 'Umbrella', 'ಛತ್ರಿ', 'छाता', 'U', 1),
    _t('v', 'V', '🚐', 'Van', 'ವ್ಯಾನ್', 'वैन', 'V', 1),
    _t('w', 'W', '⌚', 'Watch', 'ಗಡಿಯಾರ', 'घड़ी', 'W', 1),
    _t('x', 'X', '🎼', 'Xylophone', 'ಕ್ಸೈಲೋಫೋನ್', 'ज़ाइलोफोन', 'X', 2),
    _t('y', 'Y', '🪀', 'Yo-Yo', 'ಯೋ-ಯೋ', 'यो-यो', 'Y', 1),
    _t('z', 'Z', '🦓', 'Zebra', 'ಜೀಬ್ರಾ', 'ज़ेब्रा', 'Z', 1),
  ];

  // Hindi educational alphabet targets
  static final List<RunCollectTarget> hindiLetters = [
    _t('hi_01', 'अ', '🍎', 'Apple', 'ಸೇಬು', 'अनार', 'अ', 1),
    _t('hi_02', 'आ', '🥭', 'Mango', 'ಮಾವು', 'आम', 'आ', 1),
    _t('hi_03', 'इ', '🧱', 'Brick', 'ಇಟ್ಟಿಗೆ', 'इमली', 'इ', 1),
    _t('hi_04', 'ई', '🎋', 'Sugarcane', 'ಕಬ್ಬು', 'ईख', 'ई', 1),
    _t('hi_05', 'उ', '🦉', 'Owl', 'ಗೂಬೆ', 'उल्लू', 'उ', 1),
    _t('hi_06', 'ऊ', '🧶', 'Wool', 'ಉಣ್ಣೆ', 'ऊन', 'ऊ', 1),
    _t('hi_07', 'ए', '👠', 'Shoe', 'ಚಪ್ಪಲಿ', 'एड़ी', 'ए', 1),
    _t('hi_08', 'ऐ', '👓', 'Glasses', 'ಕನ್ನಡಕ', 'ऐनक', 'ऐ', 1),
    _t('hi_09', 'ओ', '🥣', 'Bowl', 'ಬಟ್ಟಲು', 'ओखली', 'ओ', 1),
    _t('hi_10', 'औ', '🛠️', 'Tool', 'ಉಪಕರಣ', 'औजार', 'औ', 1),
    _t('hi_11', 'क', '🌸', 'Lotus', 'ತಾವರೆ', 'कमल', 'क', 1),
    _t('hi_12', 'ख', '🐰', 'Rabbit', 'ಮೊಲ', 'खरगोश', 'ख', 1),
    _t('hi_13', 'ग', '🪴', 'Pot', 'ಕುಂಡ', 'गमला', 'ग', 1),
    _t('hi_14', 'घ', '🏠', 'House', 'ಮನೆ', 'घर', 'घ', 1),
    _t('hi_15', 'च', '🥄', 'Spoon', 'ಚಮಚ', 'चम्मच', 'च', 1),
    _t('hi_16', 'छ', '☂️', 'Umbrella', 'ಛತ್ರಿ', 'छाता', 'छ', 1),
    _t('hi_17', 'ज', '🚢', 'Ship', 'ಹಡಗು', 'जहाज', 'ज', 1),
    _t('hi_18', 'झ', '🧹', 'Broom', 'ಪೊರಕೆ', 'झाड़ू', 'झ', 1),
    _t('hi_19', 'ट', '🍅', 'Tomato', 'ಟೊಮ್ಯಾಟೊ', 'टमाटर', 'ट', 1),
    _t('hi_20', 'ठ', '🍰', 'Cake', 'ಕೇಕ್', 'ठेला', 'ठ', 2),
    _t('hi_21', 'ड', '🥁', 'Drum', 'ಡೋಲು', 'डमरू', 'ड', 1),
    _t('hi_22', 'त', '🍭', 'Candy', 'ಮಿಠಾಯಿ', 'तितली', 'त', 1),
    _t('hi_23', 'न', '🐘', 'Elephant', 'ಆನೆ', 'नल', 'न', 1),
    _t('hi_24', 'प', '🪁', 'Kite', 'ಗಾಳಿಪಟ', 'पतंग', 'प', 1),
    _t('hi_25', 'ब', '🦆', 'Duck', 'ಬಾತುಕೋಳಿ', 'बतख', 'ब', 1),
    _t('hi_26', 'म', '🐟', 'Fish', 'ಮೀನು', 'मछली', 'म', 1),
  ];

  // Kannada educational alphabet targets
  static final List<RunCollectTarget> kannadaLetters = [
    _t('kn_01', 'ಅ', '🍎', 'Apple', 'ಸೇಬು', 'सेब', 'ಅ', 1),
    _t('kn_02', 'ಆ', '🥭', 'Mango', 'ಮಾವು', 'आम', 'ಆ', 1),
    _t('kn_03', 'ಇ', '🍋', 'Lemon', 'ನಿಂಬೆ', 'नींबू', 'ಇ', 1),
    _t('kn_04', 'ಈ', '🎋', 'Sugarcane', 'ಕಬ್ಬು', 'गन्ना', 'ಈ', 1),
    _t('kn_05', 'ಉ', '🦉', 'Owl', 'ಗೂಬೆ', 'उल्लू', 'ಉ', 1),
    _t('kn_06', 'ಊ', '🧶', 'Wool', 'ಉಣ್ಣೆ', 'ऊन', 'ಊ', 1),
    _t('kn_07', 'ಎ', '🐘', 'Elephant', 'ಆನೆ', 'हाथी', 'ಎ', 1),
    _t('kn_08', 'ಏ', '🦅', 'Eagle', 'ಹದ್ದು', 'गरुड़', 'ಏ', 1),
    _t('kn_09', 'ಐ', '👓', 'Glasses', 'ಕನ್ನಡಕ', 'चश्मा', 'ಐ', 1),
    _t('kn_10', 'ಒ', '🥣', 'Bowl', 'ಬಟ್ಟಲು', 'कटोरा', 'ಒ', 1),
    _t('kn_11', 'ಓ', '🦙', 'Animal', 'ಪ್ರಾಣಿ', 'जानवर', 'ಓ', 2),
    _t('kn_12', 'ಔ', '🛠️', 'Tool', 'ಉಪಕರಣ', 'औजार', 'ಔ', 1),
    _t('kn_13', 'ಕ', '🐦', 'Bird', 'ಹಕ್ಕಿ', 'पक्षी', 'ಕ', 1),
    _t('kn_14', 'ಖ', '🐰', 'Rabbit', 'ಮೊಲ', 'खरगोश', 'ಖ', 1),
    _t('kn_15', 'ಗ', '🌹', 'Rose', 'ಗುಲಾಬಿ', 'गुलाब', 'ಗ', 1),
    _t('kn_16', 'ಘ', '🏠', 'House', 'ಮನೆ', 'घर', 'ಘ', 1),
    _t('kn_17', 'ಚ', '🥄', 'Spoon', 'ಚಮಚ', 'चम्मच', 'ಚ', 1),
    _t('kn_18', 'ಜ', '🚢', 'Ship', 'ಹಡಗು', 'जहाज', 'ಜ', 1),
    _t('kn_19', 'ಟ', '🍅', 'Tomato', 'ಟೊಮ್ಯಾಟೊ', 'टमाटर', 'ಟ', 1),
    _t('kn_20', 'ಡ', '🥁', 'Drum', 'ಡೋಲು', 'ढोल', 'ಡ', 1),
    _t('kn_21', 'ತ', '🦋', 'Butterfly', 'ಚಿಟ್ಟೆ', 'तितली', 'ತ', 1),
    _t('kn_22', 'ದ', '🌳', 'Tree', 'ಮರ', 'पेड़', 'ದ', 1),
    _t('kn_23', 'ನ', '🐶', 'Dog', 'ನಾಯಿ', 'कुत्ता', 'ನ', 1),
    _t('kn_24', 'ಪ', '🪁', 'Kite', 'ಗಾಳಿಪಟ', 'पतंग', 'ಪ', 1),
    _t('kn_25', 'ಬ', '🦆', 'Duck', 'ಬಾತುಕೋಳಿ', 'बतख', 'ಬ', 1),
    _t('kn_26', 'ಮ', '🐟', 'Fish', 'ಮೀನು', 'मछली', 'ಮ', 1),
  ];

  // General word/object library
  static final List<RunCollectTarget> objects = englishLetters
      .map((t) => RunCollectTarget(
            id: 'object_${t.id}',
            symbol: t.symbol,
            emoji: t.emoji,
            englishName: t.englishName,
            kannadaName: t.kannadaName,
            hindiName: t.hindiName,
            mode: RunCollectTargetMode.object,
            associatedLetter: t.associatedLetter,
            difficulty: t.difficulty,
          ))
      .toList();

  static List<RunCollectTarget> targets(AppLanguage language, RunCollectTargetMode mode) {
    switch (mode) {
      case RunCollectTargetMode.letter:
        switch (language) {
          case AppLanguage.english:
            return englishLetters;
          case AppLanguage.kannada:
            return kannadaLetters;
          case AppLanguage.hindi:
            return hindiLetters;
          default:
            final pack = LanguagePack.pack(language);
            return pack == null ? englishLetters : packLetters(pack);
        }
      case RunCollectTargetMode.word:
      case RunCollectTargetMode.object:
        return objects;
    }
  }

  static List<RunCollectTarget> distractors(RunCollectTarget target, AppLanguage language, RunCollectTargetMode mode, int count,
      [math.Random? random]) {
    final pool = targets(language, mode).where((t) => t.id != target.id).toList()..shuffle(random);
    return pool.take(math.max(0, count)).toList();
  }

  static RunCollectTarget _t(String id, String symbol, String emoji, String englishName, String kannadaName,
          String hindiName, String associatedLetter, int difficulty) =>
      RunCollectTarget(
        id: id,
        symbol: symbol,
        emoji: emoji,
        englishName: englishName,
        kannadaName: kannadaName,
        hindiName: hindiName,
        mode: RunCollectTargetMode.letter,
        associatedLetter: associatedLetter,
        difficulty: difficulty,
      );
}
