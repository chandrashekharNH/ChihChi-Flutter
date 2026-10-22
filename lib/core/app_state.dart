import 'package:flutter/foundation.dart';

import '../data/game_content/game_content_provider.dart';
import '../domain/models/app_language.dart';
import '../domain/models/world_theme.dart';
import '../services/audio/audio_service.dart';
import '../services/difficulty/difficulty_service.dart';
import '../services/reward/reward_service.dart';
import '../services/theme/theme_service.dart';
import 'localization/language_order.dart';
import 'localization/localized.dart';

/// App-wide choices (language, world) and the shared services every screen uses.
class AppState extends ChangeNotifier {
  AppLanguage _language = AppLanguage.english;
  WorldTheme theme = WorldTheme.enchantedForest;
  GameContentProviding _contentProvider = GameContentRegistry.provider(AppLanguage.english);

  final audioService = AudioService();
  final rewardService = const RewardService();
  final difficultyService = const DifficultyService();
  final themeService = ThemeService();
  final languageOrder = LanguageOrder();

  AppLanguage get language => _language;
  GameContentProviding get contentProvider => _contentProvider;

  void setLanguage(AppLanguage language) {
    if (language == _language) return;
    _language = language;
    _contentProvider = GameContentRegistry.provider(language);
    notifyListeners();
  }

  void setWorld(WorldID worldID) {
    theme = WorldTheme.theme(worldID);
    themeService.setWorld(worldID);
    notifyListeners();
  }

  String get catchInstruction => L('Catch').resolve(_language);
  String get levelLabel => L('Level').resolve(_language);
  String get homeTitle => 'ChihChi';

  /// Shorthand for resolving a line in the current language.
  String t(Localized line) => line.resolve(_language);
}
