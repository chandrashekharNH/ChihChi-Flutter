import '../../domain/models/app_language.dart';
import '../../domain/models/game_type.dart';
import '../../domain/models/home_game.dart';
import '../../domain/models/ui_text.dart';
import '../turbo_race/turbo_race_text.dart';

/// Each home game's title and subtitle, in the app's language.
extension HomeGameText on HomeGame {
  String title(AppLanguage language) {
    switch (this) {
      case HomeGame.catchLetter:
        return UIText.catchLetter.resolve(language);
      case HomeGame.catchWorld:
        return UIText.catchWorld.resolve(language);
      case HomeGame.learnBlaster:
        return UIText.gameTitle(GameType.learnBlaster3D).resolve(language);
      case HomeGame.buildPicture:
        return UIText.gameTitle(GameType.buildPicture).resolve(language);
      case HomeGame.arHunt:
        return UIText.gameTitle(GameType.arHunt).resolve(language);
      case HomeGame.turboRace:
        return TurboRaceText.title.resolve(language);
    }
  }

  String subtitle(AppLanguage language) {
    switch (this) {
      case HomeGame.catchLetter:
        return UIText.catchLetterSubtitle.resolve(language);
      case HomeGame.catchWorld:
        return UIText.catchWorldSubtitle.resolve(language);
      case HomeGame.learnBlaster:
        return UIText.gameSubtitle(GameType.learnBlaster3D).resolve(language);
      case HomeGame.buildPicture:
        return UIText.gameSubtitle(GameType.buildPicture).resolve(language);
      case HomeGame.arHunt:
        return UIText.gameSubtitle(GameType.arHunt).resolve(language);
      case HomeGame.turboRace:
        return TurboRaceText.subtitle.resolve(language);
    }
  }
}
