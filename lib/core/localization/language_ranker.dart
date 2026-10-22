import '../../domain/models/app_language.dart';
import 'language_geography.dart';

/// What is known about where the family lives.
class LanguageSignals {
  const LanguageSignals({this.preferredLanguages = const [], this.region, this.indianState});

  /// The phone's languages, best first (e.g. "kn-IN").
  final List<String> preferredLanguages;

  /// The phone's region, e.g. "IN".
  final String? region;

  /// The Indian state found from a rough location, e.g. "KA".
  final String? indianState;
}

class LanguageRanking {
  const LanguageRanking(this.languages, this.suggestedCount);
  final List<AppLanguage> languages;

  /// How many at the top are "suggested" (the family's own language or languages).
  final int suggestedCount;
}

/// Sorts the app's languages for a family: their own language first, then English, then the
/// languages of their country (neighbouring states first), then nearby countries, then the rest.
class LanguageRanker {
  static LanguageRanking rank(LanguageSignals signals) {
    final order = <AppLanguage>[];
    void add(Iterable<String> codes) {
      for (final code in codes) {
        final language = AppLanguage.fromCode(code);
        if (language != null && !order.contains(language)) order.add(language);
      }
    }

    final state = signals.indianState == null ? null : LanguageGeography.indianStates[signals.indianState];
    final country = signals.region ?? (state == null ? null : 'IN');
    final phoneLanguages = signals.preferredLanguages
        .map((l) => l.split(RegExp('[-_]')).first)
        .where((l) => l != AppLanguage.english.code)
        .toList();

    // 1. Their own language.
    add(state?.languages.take(1) ?? const []);
    add(phoneLanguages);
    if (order.isEmpty && country != null) add(LanguageGeography.countryLanguages[country]?.take(1) ?? const []);
    final suggestedCount = order.isEmpty ? 1 : order.length;

    // 2. English.
    add([AppLanguage.english.code]);

    // 3. Their country: in India, the state's other languages and its neighbours' first.
    if (state != null) {
      add(state.languages);
      add(state.neighbours
          .map((n) => LanguageGeography.indianStates[n])
          .whereType<IndianState>()
          .expand((s) => s.languages));
    }
    if (country != null) add(LanguageGeography.countryLanguages[country] ?? const []);

    // 4. Nearby countries.
    if (country != null) {
      add(LanguageGeography.nearbyCountries(country).expand((c) => LanguageGeography.countryLanguages[c] ?? const []));
    }

    // 5. Everything else.
    final rest = [...AppLanguage.values]..sort((a, b) => a.englishName.compareTo(b.englishName));
    add(rest.map((l) => l.code));

    return LanguageRanking(order, suggestedCount < order.length ? suggestedCount : order.length);
  }
}
