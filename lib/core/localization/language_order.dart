import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/app_language.dart';
import 'language_geography.dart';
import 'language_ranker.dart';

/// Finds which Indian state the family is in, once, from a rough location, so the family's own
/// language can be put first. Only the state code is kept; the location is never saved or sent.
class LanguageLocationService {
  static const _stateKey = 'languageOrder.indianState';
  static const _askedKey = 'languageOrder.askedForLocation';

  String? savedState;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    savedState = prefs.getString(_stateKey);
  }

  /// Whether asking would help: the phone says India (or nothing) and lists no Indian language.
  static bool shouldAsk(LanguageSignals signals) {
    if (signals.indianState != null || !(signals.region == null || signals.region == 'IN')) return false;
    final indian = LanguageGeography.indianLanguages.toSet();
    final phone = signals.preferredLanguages.map((l) => l.split(RegExp('[-_]')).first);
    return !phone.any(indian.contains);
  }

  /// Asks once (ever) for a rough location and reports the state if one is found.
  Future<void> findStateOnce(void Function(String state) onState) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) ?? false) return;
    await prefs.setBool(_askedKey, true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) return;
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      final state = LanguageGeography.stateNear(position.latitude, position.longitude);
      if (state != null) {
        savedState = state;
        await prefs.setString(_stateKey, state);
        onState(state);
      }
    } catch (_) {
      // No location: the phone's own settings decide the order.
    }
  }
}

/// The app's languages in the order to show them, for every language picker.
class LanguageOrder extends ChangeNotifier {
  LanguageOrder({LanguageLocationService? location}) : _location = location ?? LanguageLocationService() {
    _ranking = LanguageRanker.rank(_signals(_location.savedState));
  }

  final LanguageLocationService _location;
  late LanguageRanking _ranking;

  Future<void> load() async {
    await _location.load();
    _ranking = LanguageRanker.rank(_signals(_location.savedState));
    notifyListeners();
  }

  LanguageRanking get ranking => _ranking;
  List<AppLanguage> get languages => _ranking.languages;

  /// The family's own language(s), shown first under "Suggested".
  List<AppLanguage> get suggested => _ranking.languages.take(_ranking.suggestedCount).toList();
  List<AppLanguage> get others => _ranking.languages.skip(_ranking.suggestedCount).toList();

  /// The best language to try after `language` (for "What is this in…?").
  AppLanguage bestOther(AppLanguage language) => language == AppLanguage.english
      ? languages.firstWhere((l) => l != AppLanguage.english, orElse: () => AppLanguage.english)
      : AppLanguage.english;

  /// Called when a language list is shown: the first time, and only when the phone settings
  /// can't tell, asks for a rough location to find the family's state.
  void listShown() {
    final signals = _signals(_location.savedState);
    if (!LanguageLocationService.shouldAsk(signals)) return;
    _location.findStateOnce((state) {
      _ranking = LanguageRanker.rank(_signals(state));
      notifyListeners();
    });
  }

  static LanguageSignals _signals(String? state) {
    final locales = ui.PlatformDispatcher.instance.locales;
    return LanguageSignals(
      preferredLanguages: locales.map((l) => l.toLanguageTag()).toList(),
      region: locales.isEmpty ? null : locales.first.countryCode,
      indianState: state,
    );
  }
}
