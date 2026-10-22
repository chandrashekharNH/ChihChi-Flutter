import '../../domain/models/app_language.dart';
import '../../domain/models/game_object.dart';
import '../../domain/models/letter_lesson.dart';
import 'english_content.dart';
import 'hindi_content.dart';
import 'kannada_content.dart';
import 'language_pack.dart';

abstract class GameContentProviding {
  AppLanguage get language;
  List<GameObject> get allObjects;
  List<LetterLesson> get letterLessons;
  String localizedName(String objectID);

  LetterLesson? lesson(String id) {
    for (final l in letterLessons) {
      if (l.id == id) return l;
    }
    return null;
  }

  GameObject? object(String id) {
    for (final o in allObjects) {
      if (o.id == id) return o;
    }
    return null;
  }
}

class GameContentRegistry {
  static GameContentProviding provider(AppLanguage language) {
    switch (language) {
      case AppLanguage.english:
        return EnglishContentProvider();
      case AppLanguage.kannada:
        return KannadaContentProvider();
      case AppLanguage.hindi:
        return HindiContentProvider();
      default:
        final pack = LanguagePack.pack(language);
        if (pack == null) return EnglishContentProvider();
        return PackContentProvider(language, pack);
    }
  }
}
