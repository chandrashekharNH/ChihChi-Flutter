import '../../domain/models/app_language.dart';
import 'localized.dart';

/// Names of things in the games (apple, lion, farm…). The content tables keep their English,
/// Kannada and Hindi names in code; every other language reads the name from the app text under
/// a key such as `object.Apple`, and falls back to English.
class ContentNames {
  static String objectKey(String english) => 'object.$english';
  static String sceneKey(String english) => 'scene.$english';

  static String name(
      {required String key,
      required String english,
      required String kannada,
      required String hindi,
      required AppLanguage language}) {
    switch (language) {
      case AppLanguage.english:
        return english;
      case AppLanguage.kannada:
        return kannada;
      case AppLanguage.hindi:
        return hindi;
      default:
        return AppTextCatalog.lookup(key, language) ?? english;
    }
  }

  static Map<AppLanguage, String> names(
          {required String key, required String english, required String kannada, required String hindi}) =>
      {
        for (final l in AppLanguage.values)
          l: name(key: key, english: english, kannada: kannada, hindi: hindi, language: l)
      };
}
