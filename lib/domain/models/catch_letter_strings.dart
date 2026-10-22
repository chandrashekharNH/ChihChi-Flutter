import '../../core/localization/localized.dart';
import 'app_language.dart';
import 'catch_letter_level.dart';

/// All Catch Letter text and narration, per language.
class CatchLetterStrings {
  // Worlds

  static String batchTitle(CatchLetterBatch batch, AppLanguage language) {
    const titles = [
      'My First Adventure',
      'Letters + Numbers',
      'Letters + Objects',
      'Animal World',
      'Colors & Shapes',
      'Nature World',
      'Space World',
      'City Adventure',
      'Memory Challenge',
      'ChihChi Master',
    ];
    return L(titles[batch.index]).resolve(language);
  }

  /// Spoken during the world's animated introduction (after the title).
  static List<String> introNarration(CatchLetterBatch batch, AppLanguage language) {
    const lines = [
      ["Hi! I'm ChihChi!", "Look, a letter! Let's catch it together!"],
      ['Numbers have come to play!', 'Catch the letter, not the number!'],
      ['The objects are waking up!', "A for Apple! Find the letter's friend!"],
      ['Welcome to the jungle!', "Every animal has a letter. Let's find them!"],
      ['A rainbow world!', 'Look carefully at colors and shapes!'],
      ['Trees, flowers and sunshine!', 'Find the letters hiding in nature!'],
      ['Three, two, one, blast off!', 'Catch the letters among the stars!'],
      ['Beep beep! Welcome to the city!', 'Letters are zooming by. Catch them!'],
      ['A mystery world!', 'Remember the letter, then catch it!'],
      ['The final adventure!', 'Show everything you learned, master!'],
    ];
    return lines[batch.index].map((l) => L(l).resolve(language)).toList();
  }

  /// LOOK → FIND → CATCH → REWARD tutorial steps (Batch 1).
  static List<(String icon, String word)> tutorialSteps(AppLanguage language) => [
        ('👀', L('Look').resolve(language)),
        ('🔍', L('Find').resolve(language)),
        ('👆', L('Catch').resolve(language)),
        ('🎁', L('Reward').resolve(language)),
      ];

  // Colours and shapes

  static String colorName(CatchLetterColor color, AppLanguage language) {
    switch (color) {
      case CatchLetterColor.red:
        return L('red').resolve(language);
      case CatchLetterColor.blue:
        return L('blue', key: 'blue#2').resolve(language);
      case CatchLetterColor.green:
        return L('green', key: 'green#2').resolve(language);
      case CatchLetterColor.yellow:
        return L('yellow', key: 'yellow#2').resolve(language);
      case CatchLetterColor.purple:
        return L('purple').resolve(language);
    }
  }

  static String shapeName(CatchLetterShape shape, AppLanguage language) => L(shape.name).resolve(language);

  // Prompts (HUD) and narration

  static String catchTheLetter(AppLanguage language) => L('Catch the letter').resolve(language);
  static String rememberThisLetter(AppLanguage language) => L('Remember this letter!').resolve(language);
  static String catchTheOneYouRemember(AppLanguage language) => L('Catch the letter you remember!').resolve(language);
  static String colorPrompt(CatchLetterColor color, AppLanguage language) =>
      L('Catch the {0} one', args: [colorName(color, language)]).resolve(language);
  static String shapePrompt(CatchLetterShape shape, AppLanguage language) =>
      L('Catch the one in the {0}', args: [shapeName(shape, language)]).resolve(language);
  static String sayCatchLetter(String letter, AppLanguage language) =>
      L('Catch the letter {0}!', args: [letter]).resolve(language);
  static String sayCatchColor(String letter, CatchLetterColor color, AppLanguage language) =>
      L('Catch the {0} {1}!', args: [colorName(color, language), letter]).resolve(language);
  static String sayCatchPlainColor(CatchLetterColor color, AppLanguage language) =>
      L('Catch {0}!', args: [colorName(color, language)]).resolve(language);
  static String sayCatchShape(String letter, CatchLetterShape shape, AppLanguage language) =>
      L('Catch {0} in the {1}!', args: [letter, shapeName(shape, language)]).resolve(language);
  static String sayRemember(String letter, AppLanguage language) =>
      L('Remember this letter. {0}!', args: [letter]).resolve(language);
  static String sayNowCatchIt(AppLanguage language) => L('Now catch it!').resolve(language);
  static String oops(AppLanguage language) => L('Oops!', key: 'Oops!#2').resolve(language);
  static String sayOopsTryAgain(AppLanguage language) => L("Oops! Let's try again!").resolve(language);
  static String sayLookHere(AppLanguage language) => L('Look! Here it is. Catch it!').resolve(language);

  // Completion

  static String correctCount(int correct, int total, AppLanguage language) =>
      L('{0} / {1} correct', args: [correct, total]).resolve(language);
  static String bestStreak(int streak, AppLanguage language) => L('🔥 {0} in a row', args: [streak]).resolve(language);
  static String adventureComplete(AppLanguage language) => L('Adventure complete!').resolve(language);
  static String youUnlocked(AppLanguage language) => L('You unlocked').resolve(language);
  static String sayUnlocked(CatchLetterBatch batch, AppLanguage language) =>
      L('Adventure complete! You unlocked {0}!', args: [batchTitle(batch, language)]).resolve(language);
  static String masterTitle(AppLanguage language) => L('You are a ChihChi Master!').resolve(language);

  // Level selection UI

  static String watchIntroAgain(AppLanguage language) => L('🎬 Watch Intro').resolve(language);
  static String skip(AppLanguage language) => L('Skip').resolve(language);
  static String lockedHint(CatchLetterBatch previous, AppLanguage language) =>
      L('Finish {0} to open', args: [batchTitle(previous, language)]).resolve(language);
  static String adventureMapTitle(AppLanguage language) => L("ChihChi's Adventure").resolve(language);
}
