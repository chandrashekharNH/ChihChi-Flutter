import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/models/app_language.dart';

/// One line of app text in every language. The English text is written in the code and is also
/// the key into `assets/i18n/<code>.json` (converted from the iOS `AppText.xcstrings`). Values that
/// change (a number, a name) are written `{0}`, `{1}`… and passed as arguments.
class Localized {
  const Localized(this.english, {String? key, this.arguments = const []}) : key = key ?? english;

  final String english;
  final String key;

  /// Each argument is either a `Localized` (said in the same language) or anything else (inserted
  /// as written).
  final List<Object?> arguments;

  String resolve(AppLanguage language) {
    final template = language == AppLanguage.english ? english : (AppTextCatalog.lookup(key, language) ?? english);
    if (arguments.isEmpty) return template;
    var result = template;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      final value = argument is Localized ? argument.resolve(language) : '$argument';
      result = result.replaceAll('{$index}', value);
    }
    return result;
  }

  /// Lets a `Localized` be used where a `String Function(AppLanguage)` is expected.
  String call(AppLanguage language) => resolve(language);

  /// The same line, written in capitals in English only (other scripts have no capitals).
  Localized get uppercasedInEnglish => Localized(english.toUpperCase(), key: key, arguments: arguments);

  /// The line in every language, for content that stores names per language.
  Map<AppLanguage, String> allLanguages() => {for (final l in AppLanguage.values) l: resolve(l)};

  @override
  bool operator ==(Object other) =>
      other is Localized && other.key == key && other.english == english && _listEquals(other.arguments, arguments);

  @override
  int get hashCode => Object.hash(key, english, Object.hashAll(arguments));

  static bool _listEquals(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => english;
}

/// `L('Reach Level {0}', [level])`: a line of app text.
Localized L(String english, {String? key, List<Object?> args = const []}) =>
    Localized(english, key: key, arguments: args);

/// The app text for every language, loaded once at start-up.
class AppTextCatalog {
  static final Map<String, Map<String, String>> _tables = {};

  static Future<void> load() async {
    for (final language in AppLanguage.values) {
      if (language == AppLanguage.english) continue;
      try {
        final text = await rootBundle.loadString('assets/i18n/${language.code}.json');
        _tables[language.code] = (jsonDecode(text) as Map<String, dynamic>).cast<String, String>();
      } catch (_) {
        _tables[language.code] = {};
      }
    }
  }

  /// For tests: put tables in directly.
  static void setTable(AppLanguage language, Map<String, String> table) => _tables[language.code] = table;

  /// The text for `key` in `language`, or null when that language has no line for it yet.
  static String? lookup(String key, AppLanguage language) {
    final value = _tables[language.code]?[key];
    return value == null || value.isEmpty ? null : value;
  }
}
