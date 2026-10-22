import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/models/app_language.dart';
import '../../domain/models/game_object.dart';
import '../../domain/models/letter_lesson.dart';
import '../../domain/models/run_collect.dart';
import 'game_content_provider.dart';

class PackLetter {
  const PackLetter({
    required this.symbol,
    required this.sound,
    required this.emoji,
    required this.word,
    required this.english,
    required this.category,
  });

  /// The letter as written ("அ"); for Chinese, a whole character ("鱼").
  final String symbol;

  /// How it sounds, in Latin letters ("a").
  final String sound;
  final String emoji;

  /// A word that starts with the letter (for Chinese, the character's own word).
  final String word;

  /// The word in English, for grown-ups and translators.
  final String english;

  /// fruit, animal, vehicle, shape, food, nature or toy.
  final String category;

  factory PackLetter.fromJson(Map<String, dynamic> j) => PackLetter(
        symbol: j['symbol'] as String,
        sound: j['sound'] as String,
        emoji: j['emoji'] as String,
        word: j['word'] as String,
        english: j['english'] as String,
        category: j['category'] as String,
      );
}

/// The letters of one language and a picture word for each, read from
/// `assets/language_packs/<code>.json`.
class LanguagePack {
  LanguagePack(this.code, this.letters);
  final String code;
  final List<PackLetter> letters;

  static final Map<String, LanguagePack> _packs = {};

  /// Loads every pack once at start-up.
  static Future<void> loadAll() async {
    for (final language in AppLanguage.values) {
      try {
        final text = await rootBundle.loadString('assets/language_packs/${language.code}.json');
        final json = jsonDecode(text) as Map<String, dynamic>;
        _packs[language.code] = LanguagePack(json['code'] as String,
            (json['letters'] as List).map((l) => PackLetter.fromJson((l as Map).cast<String, dynamic>())).toList());
      } catch (_) {
        // English, Kannada and Hindi have no pack.
      }
    }
  }

  static LanguagePack? pack(AppLanguage language) => _packs[language.code];

  String objectID(int index) => '${code}_${index + 1}';

  ObjectCategory category(int index) =>
      ObjectCategory.values.firstWhere((c) => c.name == letters[index].category, orElse: () => ObjectCategory.nature);

  /// Three other letters' pictures to mix in with a letter's own picture.
  List<String> distractors(int index) => [5, 9, 13].map((o) => objectID((index + o) % letters.length)).toList();
}

/// Catch Letter and Catch World content for a language that has a pack.
class PackContentProvider extends GameContentProviding {
  PackContentProvider(this.language, LanguagePack pack)
      : allObjects = [
          for (var i = 0; i < pack.letters.length; i++)
            GameObject(id: pack.objectID(i), emoji: pack.letters[i].emoji, category: pack.category(i)),
        ],
        letterLessons = [
          for (var i = 0; i < pack.letters.length; i++)
            LetterLesson(
              id: pack.objectID(i),
              symbol: pack.letters[i].symbol,
              symbolPhoneticHint: pack.letters[i].sound,
              targetObjectID: pack.objectID(i),
              targetObjectName: pack.letters[i].word,
              distractorObjectIDs: pack.distractors(i),
              languageCode: pack.code,
            ),
        ],
        _names = {for (var i = 0; i < pack.letters.length; i++) pack.objectID(i): pack.letters[i].word};

  @override
  final AppLanguage language;
  @override
  final List<GameObject> allObjects;
  @override
  final List<LetterLesson> letterLessons;
  final Map<String, String> _names;

  @override
  String localizedName(String objectID) => _names[objectID] ?? objectID;
}

/// Learn Blaster, Turbo Race and letter puzzles: a pack's letters as targets.
List<RunCollectTarget> packLetters(LanguagePack pack) => [
      for (var i = 0; i < pack.letters.length; i++)
        RunCollectTarget(
          id: pack.objectID(i),
          symbol: pack.letters[i].symbol,
          emoji: pack.letters[i].emoji,
          englishName: pack.letters[i].english,
          kannadaName: pack.letters[i].word,
          hindiName: pack.letters[i].word,
          mode: RunCollectTargetMode.letter,
          associatedLetter: pack.letters[i].symbol,
          difficulty: 1,
          ownName: pack.letters[i].word,
        ),
    ];
