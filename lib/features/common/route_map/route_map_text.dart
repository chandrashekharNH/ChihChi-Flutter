import '../../../core/localization/localized.dart';
import '../../../domain/models/app_language.dart';
import '../../../domain/models/run_collect.dart';

/// Route map strings (lands that exist only on a map, and start hubs).
class RouteMapText {
  static String start(AppLanguage l) => L('Start').resolve(l);
  static String artStudio(AppLanguage l) => L('Art Studio').resolve(l);
  static String launchPad(AppLanguage l) => L('Launch Pad').resolve(l);
  static String meadow(AppLanguage l) => L('Flower Meadow').resolve(l);
  static String beach(AppLanguage l) => L('Sunny Beach').resolve(l);
  static String jungle(AppLanguage l) => L('Jungle').resolve(l);
  static String rainbowHills(AppLanguage l) => L('Rainbow Hills').resolve(l);
  static String youAreHere(AppLanguage l) => L('You are here').resolve(l);
  static String level(int n, AppLanguage l) => L('Level {0}', args: [n]).resolve(l);
  static String levelStars(int n, int stars, AppLanguage l) => L('Level {0}, {1} ⭐', args: [n, stars]).resolve(l);

  static String blasterWorld(RunCollectWorld world, AppLanguage l) {
    switch (world) {
      case RunCollectWorld.enchantedForest:
        return L('Enchanted Forest').resolve(l);
      case RunCollectWorld.colorfulCity:
        return L('Colorful City').resolve(l);
      case RunCollectWorld.iceKingdom:
        return L('Ice Kingdom').resolve(l);
      case RunCollectWorld.candyLand:
        return L('Candy Land').resolve(l);
      case RunCollectWorld.spaceWorld:
        return L('Space World').resolve(l);
      case RunCollectWorld.oceanWorld:
        return L('Ocean World').resolve(l);
      case RunCollectWorld.dinosaurWorld:
        return L('Dinosaur World').resolve(l);
      case RunCollectWorld.magicKingdom:
        return L('Magic Kingdom').resolve(l);
    }
  }
}
