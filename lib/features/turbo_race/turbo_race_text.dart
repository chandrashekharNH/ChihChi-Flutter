import '../../core/localization/localized.dart';
import 'turbo_race_content.dart';

class TurboRaceText {
  static final title = L("Turbo Race");
  static final subtitle = L("Race the world, learn on the way!");
  static final worldJourney = L("World Journey");
  static Localized raceNumber(Object? n) => L("Race {0}", args: [n]);
  static final comingSoon = L("Coming soon");
  static final startRace = L("Start Race");
  static final map = L("Map");
  static Localized goingTo(Object? place) => L("We're going to {0}!", args: [place]);
  static Localized welcomeTo(Object? place) => L("Welcome to {0}!", args: [place]);
  static final youAreHere = L("You are here");
  static final ready = L("Ready?");
  static final go = L("GO!");
  static final finalLap = L("Final lap!");
  static final finish = L("FINISH!");
  static final position = L("POS");
  static final lap = L("LAP");
  static final boost = L("BOOST");
  static final boostReady = L("Boost ready! Tap ⚡");
  static final speedUnit = L("km/h");
  static final steerTip = L("Hold and slide to steer");
  static final paused = L("Paused");
  static final resume = L("Keep Racing");
  static final quit = L("Back to Map");
  static final oops = L("Oops!");
  static final holdToDrive = L("Hold to drive!");
  static Localized youPassed(Object? name) => L("You passed {0}!", args: [name]);
  static Localized passedYou(Object? name) => L("{0} passed you!", args: [name]);
  static Localized rivalWon(Object? name) => L("{0} won! Keep going!", args: [name]);
  static final youLead = L("You're in front!");
  static final finishOrder = L("Finish order");
  static final boostShout = L("⚡ BOOST!");
  static Localized findBanner(Object? symbol) => L("Find {0}", args: [symbol]);
  static Localized startsBanner(Object? emoji, Object? word) => L("{0} {1} starts with…", args: [emoji, word]);
  static Localized colorBanner(Object? swatch, Object? name) => L("{0} {1} gate", args: [swatch, name]);
  static Localized shapeBanner(Object? icon, Object? name) => L("{0} {1}", args: [icon, name]);
  static Localized sayFind(Object? symbol) => L("Find {0}!", args: [symbol]);
  static Localized sayWhichLetterStarts(Object? word) => L("Which letter starts {0}?", args: [word]);
  static Localized sayColorGate(Object? name) => L("Drive through the {0} gate!", args: [name]);
  static Localized sayShapeGate(Object? name) => L("Drive through the {0}!", args: [name]);
  static Localized sayStartsWith(Object? word, Object? letter) => L("{0} starts with {1}. Let's try the next one!", args: [word, letter]);
  static Localized sayWeNeeded(Object? picked, Object? answer) => L("That was {0}. We needed {1}!", args: [picked, answer]);
  static final raceComplete = L("RACE COMPLETE");
  static final greatTry = L("Great try!");
  static Localized place(int n) => Localized('${_ordinal(n)} PLACE', key: '{0} PLACE (place number)', arguments: ['$n']);
  static final time = L("TIME");
  static final bestLap = L("BEST LAP");
  static final learning = L("LEARNING");
  static final rewards = L("REWARDS");
  static final nextDestination = L("NEXT DESTINATION");
  static final continueJourney = L("Continue Journey");
  static final raceAgain = L("Race Again");
  static Localized retryLine(int n) => switch (n % 3) {
        0 => L("That corner was FAST! Let's race again!"),
        1 => L('Oops! My wheels got confused!'),
        _ => L("So close! Let's try again!"),
      };
  static final goalFinish = L("Finish the race");
  static Localized goalLearning(Object? n) => L("Pass {0} learning gates", args: [n]);
  static Localized goalBonus(TurboBonusGoal goal) => switch (goal) {
        BonusCollectStars(:final count) => collectStars(count),
        BonusFinishTopThree() => finishTopThree,
        BonusUseBoost(:final count) => useBoost(count),
        BonusNoWrongGates() => noWrongGates,
        BonusWin() => win,
      };
  static Localized collectStars(Object? n) => L("Collect {0} stars", args: [n]);
  static final finishTopThree = L("Finish in the top 3");
  static Localized useBoost(Object? n) => L("Use boost {0} times", args: [n]);
  static final noWrongGates = L("No wrong gates");
  static final win = L("Win the race");
  static Localized sayWeMadeIt(Object? place) => L("We made it! Welcome to {0}!", args: [place]);

  static String _ordinal(int n) => switch (n) { 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${n}th' };
}
