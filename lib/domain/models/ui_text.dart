import '../../core/localization/localized.dart';
import 'game_type.dart';
import 'puzzle_models.dart';
import 'reward_type.dart';
import 'world_theme.dart';

/// Text for app screens (menus, HUDs, buttons, overlays) in every app language. Each entry is a
/// `Localized`, so `UIText.games(language)` gives the text.
class UIText {
  // Home / menus
  static final appName = L('ChihChi');
  static final games = L('🎮 Games');
  static final seeAll = L('See All');
  static final progress = L('Progress');
  static final rewards = L('Rewards');
  static final selectLanguage = L('🌐 Select Language');
  static Localized reachLevel(int n) => L('Reach Level {0}', args: [n]);
  static Localized gameTitle(GameType game) => L(_titles[game]!);
  static Localized gameSubtitle(GameType game) => L(_subtitles[game]!);
  static Localized world(WorldID world) => L(world.displayName);

  // Level selection
  static final chooseYourGame = L('Choose Your Game');
  static final twoWaysToLearn = L('ChihChi has two fun ways to learn!');
  static final chooseLevel = L('Choose Level');
  static final catchLetter = L('Catch Letter');
  static final catchLetterSubtitle = L('Catch the correct letter and learn A–Z');
  static final catchWorld = L('Catch World');
  static final catchWorldSubtitle = L('Catch the correct word and discover objects');

  // Progress / rewards
  static final myProgress = L('My Progress');
  static final worldExploration = L('World Exploration');
  static final unlocked = L('Unlocked!');
  static final rewardCollection = L('Reward Collection');
  static final myRewards = L('My Rewards');
  static final stars = L('Stars');
  static final candy = L('Candy');
  static final iceCream = L('Ice Cream');
  static final chocolate = L('Chocolate');
  static Localized rewardName(RewardType type) {
    switch (type) {
      case RewardType.star:
        return L('Star');
      case RewardType.candy:
        return candy;
      case RewardType.iceCream:
        return iceCream;
      case RewardType.chocolate:
        return chocolate;
      case RewardType.mystery:
        return L('Mystery Gift');
    }
  }

  static final levelReached = L('Level Reached');
  static final correctAnswers = L('Correct Answers', key: 'Correct Answers#2');
  static final bestStreak = L('Best Streak');
  static final accuracy = L('Accuracy');
  static Localized levelsComplete(int done, int total) => L('{0}/{1} levels complete', args: [done, total]);

  // Settings
  static final settings = L('⚙️ Settings');
  static final language = L('🌐 Language');
  static final worldTheme = L('🌍 World / Theme');
  static final audio = L('🔊 Audio');
  static final music = L('🎵 Music');
  static final soundEffects = L('🔔 Sound Effects');
  static final voice = L('🗣 Voice');
  static final dangerZone = L('⚠️ Danger Zone');
  static final resetAllProgress = L('Reset All Progress');
  static final resetAllProgressQuestion = L('Reset All Progress?', key: 'Reset All Progress?#2');
  static final resetWarning = L('This will erase all stars, rewards, and level progress. This cannot be undone.');
  static final reset = L('Reset');
  static final cancel = L('Cancel');

  // Onboarding
  static final whatsYourName = L("Hello! What's your name?");
  static final yourName = L('Your name');
  static final letsPlay = L("Let's Play! 🎉");
  static Localized hiName(String name) => L('Hi, {0}! 🎉', args: [name]);

  // In game
  static Localized level(int n) => L('Level {0}', args: [n]);
  static Localized round(int r, int total) => L('Round {0}/{1}', args: [r, total]);
  static Localized roundOf(int r, int total) => L('Round {0} of {1}', args: [r, total]);
  static Localized score(int n) => L('Score: {0}', args: [n]);
  static Localized accuracyPercent(int n) => L('Accuracy: {0}%', args: [n]);
  static final findThis = L('Find this');
  static final getReady = L('Get Ready!');
  static final greatJob = L('Great Job!');
  static final plusPoints = L('⭐ + points');
  static final tryAgainExclaim = L('Try Again!');
  static final keepGoing = L('Keep going!');
  static final keepPracticing = L('Keep Practicing!');
  static final levelComplete = L('Level Complete!');
  static final playAgain = L('Play Again');
  static final continueButton = L('Continue', key: 'Continue#3');
  static final tryAgain = L('Try Again', key: 'Try Again#3');
  static final exit = L('Exit');
  static final exitGame = L('Exit Game');
  static final paused = L('Paused');
  static final resume = L('Resume');
  static final closeGame = L('Close game');
  static final sayItAgain = L('Say it again');
  static final changeLanguage = L('Change language');
  static final preparingGame = L('Getting the game ready…');
  static final blasterTip = L('✋ Hold the gun and move it. Tap the gun to fire!');

  // Build the Picture
  static final puzzleAdventure = L('Adventure');
  static final freePlay = L('Free Play');
  static Localized difficultyName(PuzzleDifficulty difficulty) =>
      L(const ['Very Easy', 'Easy', 'Normal', 'Advanced', 'Expert'][difficulty.index]);
  static Localized categoryName(PuzzleCategory category) {
    switch (category) {
      case PuzzleCategory.animals:
        return L('Animals');
      case PuzzleCategory.nature:
        return L('Nature');
      case PuzzleCategory.vehicles:
        return L('Vehicles');
      case PuzzleCategory.food:
        return L('Food');
      case PuzzleCategory.space:
        return L('Space', key: 'Space#2');
      case PuzzleCategory.dinosaurs:
        return L('Dinosaurs');
      case PuzzleCategory.objects:
        return L('Things');
      case PuzzleCategory.places:
        return L('Places');
      case PuzzleCategory.india:
        return L('India');
      case PuzzleCategory.letters:
        return L('Letters');
      case PuzzleCategory.numbers:
        return L('Numbers');
      case PuzzleCategory.colors:
        return L('Colours');
      case PuzzleCategory.words:
        return L('Words');
    }
  }

  static final hint = L('Hint');
  static final rotate = L('Turn');
  static final peek = L('Look');
  static final puzzleComplete = L('Puzzle Complete!');
  static final pieces = L('Pieces');
  static final moves = L('Moves');
  static final tryAgains = L('Try-agains');
  static final hintsUsed = L('Hints');
  static final time = L('Time');
  static final scoreTitle = L('Score');
  static final nextPuzzle = L('Next', key: 'Next#2');
  static final home = L('Home');
  static final allPuzzlesDone = L('You completed every puzzle!');
  static final congratulations = L('Congratulations!');
  static final amazing = L('Amazing!');
  static Localized puzzleCount(int n) => L('{0} puzzles', args: [n]);
  static final newBest = L('🏆 New best!');
  static final totalStars = L('Total Stars');
  static final puzzlesDone = L('Puzzles');
  static final timeGoal = L('Goal');
  static final haptics = L('📳 Vibration');
  static final levelsPassed = L('Levels');
  static final sayAmazing = L('Amazing!');
  static Localized sayGrandFinale(String name) =>
      L('Amazing{0}! You completed every puzzle! Congratulations!', args: [name.isEmpty ? '' : ', $name']);

  // AR Explorer (camera permission)
  static final findIt = L('Find it! →');
  static Localized seeing(String label) => L('Seeing: {0}', args: [label]);
  static final veryClose = L('🔥 Very Close!');
  static final gettingWarmer = L('🌡️ Getting Warmer!');
  static final keepLooking = L('❄️ Keep Looking...');
  static final pointCamera = L('👀 Point camera at objects');
  static final youFoundIt = L('You Found It!');
  static final nextObject = L('Next Object ▶');
  static final finish = L('Finish 🏆');
  static final timesUp = L("Time's Up!");
  static Localized itWas(String thing) => L('It was {0}', args: [thing]);
  static final tryNext = L('Try Next ▶');
  static final lookingFor = L("We're looking for");
  static final cameraNeeded = L('Camera Access Needed');
  static final allowCamera = L('Please allow camera access in Settings to play ChihChi AR Explorer.');
  static final openSettings = L('Open Settings');
  static final goBack = L('Go Back');

  // Photo puzzles
  static final myPhotoPuzzle = L('📸 My Photo Puzzle');
  static final myPhotoPuzzleSubtitle = L('Take a picture of anything and turn it into a puzzle!');
  static final takePhoto = L('Take Photo');
  static final choosePhoto = L('Choose Photo');
  static final myPhoto = L('My Photo');

  // Saying your name
  static final holdAndSayName = L('Hold 🎤 and say your name');
  static final listening = L('Listening… 👂');
  static final hearIt = L('Hear it');
  static final orTypeIt = L('or type it');
  static final thatsMe = L("That's me! ✓");
  static final hiThere = L('Hi! 🎉');
  static final micOff = L('Ask a grown-up to turn on the microphone for ChihChi in Settings, or type your name.');

  static const Map<GameType, String> _titles = {
    GameType.catchAndLearn: 'Catch & Learn',
    GameType.learnBlaster3D: 'Learn Blaster 3D',
    GameType.arHunt: 'ChihChi AR Explorer',
    GameType.memoryMagic: 'Memory Magic',
    GameType.colorQuest: 'Color Quest',
    GameType.numberWorld: 'Number World',
    GameType.shapeAdventure: 'Shape Adventure',
    GameType.animalSafari: 'Animal Safari',
    GameType.wordBuilder: 'Word Builder',
    GameType.buildPicture: 'Build the Picture',
  };

  static const Map<GameType, String> _subtitles = {
    GameType.catchAndLearn: 'Catch the right letter!',
    GameType.learnBlaster3D: 'Aim and blast the right letter!',
    GameType.arHunt: 'Your world is the adventure!',
    GameType.memoryMagic: 'Match the cards!',
    GameType.colorQuest: 'Find the right color!',
    GameType.numberWorld: 'Catch the right number!',
    GameType.shapeAdventure: 'Explore shapes!',
    GameType.animalSafari: 'Learn about animals!',
    GameType.wordBuilder: 'Build words!',
    GameType.buildPicture: 'Drag the pieces and make the picture!',
  };
}
