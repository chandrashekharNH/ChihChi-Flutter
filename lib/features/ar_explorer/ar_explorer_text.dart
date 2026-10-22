import '../../core/localization/localized.dart';
import '../../domain/models/app_language.dart';
import 'ar_explorer_content.dart';
import 'ar_explorer_mission.dart';
import 'ar_explorer_world_content.dart';

class ARExplorerText {
  static final title = L("ChihChi AR Explorer");
  static final tagline = L("Your world is the adventure!");
  static final letsExplore = L("Let's explore!");
  static final explorerLevels = L("Explorer Levels");
  static final playAMode = L("Play a Hunt");
  static Localized explorerLevel(Object? n) => L("Explorer Level {0}", args: [n]);
  static final comingSoon = L("Coming soon");
  static Localized stars(Object? n) => L("{0} stars", args: [n]);
  static final welcomeExplorer = L("Welcome, Explorer!");
  static final letsGo = L("Let's Go!");
  static final replayIntro = L("Watch the introduction again");
  static final safetyTitle = L("Explore safely");
  static final safetyText = L("Stay in a safe place while exploring. Ask a grown-up to help you.");
  static final howToTitle = L("How to explore");
  static final howToMove = L("Move your device slowly.");
  static final howToPoint = L("Point at something.");
  static final howToTap = L("Tap it on the screen.");
  static final howToListen = L("Listen and learn!");
  static final cameraWhyTitle = L("📷 Camera time!");
  static final cameraWhy = L("ChihChi Explorer uses the camera to turn your surroundings into a learning adventure. Pictures stay on this device.");
  static final continueButton = L("Continue", key: "Continue#2");
  static final cameraNeededTitle = L("📷 Camera Access Needed");
  static final cameraNeeded = L("Camera access is required for ChihChi AR Explorer. A grown-up can turn it on in Settings → ChihChi → Camera.");
  static final back = L("Back");
  static final unsupported = L("This device does not support the AR features this game needs. You can keep enjoying the other ChihChi games!");
  static final notAllowed = L("A grown-up has turned off AR Explorer. You can play the other ChihChi games!");
  static final missionDiscover = L("Find something interesting and tap it!");
  static Localized missionFind(Object? name) => L("Find the {0}!", args: [name]);
  static final mysteryIntro = L("I'm thinking of something…");
  static Localized missionColor(ExplorerColor color) => L("Find something {0}!", key: "Find something {0}! (colour)", args: [colorWord(color).uppercasedInEnglish]);
  static Localized missionShape(ExplorerShape shape) => L("Find something {0}!", key: "Find something {0}! (shape)", args: [shapeWord(shape).uppercasedInEnglish]);
  static Localized missionLetter(Object? letter) => L("Find something that starts with {0}!", args: [letter]);
  static Localized missionCount(Object? target, Object? found) => L("Tap {0} different things! ({1}/{0})", args: [target, found]);
  static final missionScavenger = L("Today's adventure!");
  static final rememberThese = L("Remember these!");
  static final whichFirst = L("Which one did you see first?");
  static final howMany = L("How many did you find?");
  static Localized thatsA(Object? name) => L("That's a {0}!", args: [name]);
  static Localized letterFor(Object? letter, Object? name) => L("{0} for {1}.", args: [letter, name]);
  static Localized shapeFact(Object? name, ExplorerShape shape) => L("{0} is {1}!", args: [name, shapeWord(shape)]);
  static Localized foundColor(ExplorerColor color) => L("Great! You found {0}!", args: [colorWord(color)]);
  static Localized seenColor(ExplorerColor seen, ExplorerColor target) => L("That's {0}. Let's look for {1}!", args: [colorWord(seen), colorWord(target)]);
  static final noClearColor = L("I can't see one clear colour there. Point right at it!");
  static Localized seenObject(Object? name) => L("That's a {0}. Let's keep looking!", args: [name]);
  static Localized seenShape(Object? name, ExplorerShape shape) => L("That's a {0} – it's {1}. Let's keep looking!", args: [name, shapeWord(shape)]);
  static Localized seenLetter(Object? name, Object? seenLetter, Object? target) => L("{0} starts with {1}. Let's find {2}!", args: [name, seenLetter, target]);
  static final unsure = L("Hmm… I'm not sure what that is.");
  static final tryAnother = L("Try another object, or move a little closer.");
  static Localized isThisA(Object? name) => L("Is this a {0}?", args: [name]);
  static final yes = L("Yes");
  static final no = L("No");
  static Localized quizRightNo(Object? seen) => L("Well done! This is a {0}.", args: [seen]);
  static Localized quizWrongYes(Object? seen, Object? target) => L("Not quite. This is a {0}, not a {1}.", args: [seen, target]);
  static Localized quizMissed(Object? target) => L("Look again! This is a {0}.", args: [target]);
  static Localized quizSkipped(Object? target) => L("Okay! That is not a {0}. Let's find the next one.", args: [target]);
  static final okayTryAnother = L("Okay! Let's try another one.");
  static Localized cheer(int n) => [L("Yes!"), L("Great discovery!"), L("Well done!")][n.abs() % 3];
  static Localized mysterySolved(Object? name) => L("{0}! You solved the mystery!", args: [name]);
  static final scavengerDone = L("Adventure complete!");
  static Localized findAnother(Object? name) => L("Can you find another {0}?", args: [name]);
  static Localized alreadyFound(Object? name) => L("You already found the {0}! Find something different.", args: [name]);
  static Localized countAgain(int n) => L("Not quite! Let's count again: {0}.", args: [[for (var i = 1; i <= (n < 1 ? 1 : n); i++) '$i'].join(', ')]);
  static Localized foundCount(Object? n) => L("You found {0} things!", args: [n]);
  static Localized itWas(Object? name) => L("You saw the {0} first.", args: [name]);
  static final imReady = L("I'm ready!");
  static final mixItUp = L("Mix It Up");
  static final pickAGame = L("Pick a game!");
  static final mixItUpHint = L("A bit of everything!");
  static final hint = L("Hint");
  static final skip = L("Try another");
  static final pause = L("Pause");
  static final resume = L("Resume");
  static final listen = L("Listen");
  static final next = L("Next");
  static final checkMiddle = L("Check the middle");
  static final cameraAccessibility = L("Camera view. Double-tap to check the object in the middle.");
  static final hintLookAround = L("Look around you.");
  static Localized hintColor(ExplorerColor color) => L("Look for something {0} – maybe a toy or a book.", args: [colorWord(color)]);
  static Localized hintLike(Object? name) => L("Like a {0}!", args: [name]);
  static final hintDiscover = L("Try a cup, a book or a chair.");
  static final hintCount = L("Tap different things, one at a time.");
  static final tipMoveSlowly = L("Move your device slowly to look around.");
  static final tipMoreLight = L("Point toward a well-lit area.");
  static final tipSlowDown = L("Let's stop for a moment and look around.");
  static final cameraPaused = L("Camera paused");
  static final cameraStopped = L("The camera stopped. Let's try again.");
  static final tryAgain = L("Try Again", key: "Try Again#3");
  static final paused = L("Paused", key: "Paused#2");
  static final explorerComplete = L("🎉 Explorer Complete!");
  static Localized discovered(Object? n) => L("You discovered {0} things", args: [n]);
  static Localized correctOf(Object? c, Object? t) => L("Correct: {0} / {1}", args: [c, t]);
  static Localized starsPlus(Object? n) => L("⭐ +{0} stars", args: [n]);
  static final greatExploring = L("Fantastic exploring!");
  static final nextAdventure = L("Next Adventure");
  static final explorerHome = L("Explorer Home");
  static final playAgain = L("Play Again");
  static Localized missionColorShape(ExplorerColor color, ExplorerShape shape) => L("Find something {0} that is {1}!", args: [colorWord(color).uppercasedInEnglish, shapeWord(shape).uppercasedInEnglish]);
  static final tapFloorToPlace = L("Look at the floor, then tap it to place ChihChi!");
  static final placeCloser = L("Try a spot on the floor closer to you.");
  static final hintPlace = L("Point at the floor near you, then tap it.");
  static Localized meetAnimal(Object? name) => L("Meet the {0}!", args: [name]);
  static Localized tapTheAnimal(Object? name) => L("Tap the {0}!", args: [name]);
  static final whatAnimal = L("What animal is this?");
  static final lookAgain = L("Not quite! Let's look again.");
  static final openPortalMission = L("Tap the floor to open a magic portal!");
  static final portalAppeared = L("Whoa! A magical portal! Tap it!");
  static Localized welcomeWorld(ARAdventureWorld world) => L("Welcome to the {0}!", args: [worldName(world)]);
  static final starsLost = L("Oh no! The Magic Stars are lost! Let's bring them back!");
  static final findTreasure = L("I can see something nearby! Find the treasure!");
  static final treasureFound = L("You found a treasure!");
  static Localized magicStarBack(Object? n) => L("Magic Star {0} is back!", args: [n]);
  static final worldRestored = L("✨ Magic world restored!");
  static final lookLeft = L("Look to your left!");
  static final lookRight = L("Look to your right!");
  static final lookBehind = L("Turn around slowly and look behind you!");
  static final lookAhead = L("It's right in front of you!");
  static Localized whatIsThisIn(AppLanguage target) => L("What is this in ${target.englishName}?");
  static final languageChallenge = L("Language challenge");
  static final myARWorld = L("My AR World");
  static final myARWorldHint = L("Your collection");
  static final placeInRoom = L("Place in my room");
  static final tapToPlaceItem = L("Tap the floor to place it!");
  static final collectionEmpty = L("Finish an Explorer Level to collect your first treasure!");
  static final newForWorld = L("New for your AR World!");
  static final clear = L("Clear");
  static final done = L("Done");
  static final levelLocked = L("Finish the level before this one to open it.");
  static Localized itemsCollected(Object? n, Object? total) => L("{0} of {1} collected", args: [n, total]);
  static Localized lockedItem(Object? level) => L("Finish Explorer Level {0} to get this!", args: [level]);

  static Localized colorName(ExplorerColor color) => colorWord(color);
  static Localized shapeName(ExplorerShape shape) => shapeWord(shape);

  static Localized colorWord(ExplorerColor color) => switch (color) {
        ExplorerColor.red => L("red"),
        ExplorerColor.orange => L("orange"),
        ExplorerColor.yellow => L("yellow"),
        ExplorerColor.green => L("green"),
        ExplorerColor.blue => L("blue"),
        ExplorerColor.purple => L("purple"),
        ExplorerColor.pink => L("pink"),
      };

  static Localized shapeWord(ExplorerShape shape) => switch (shape) {
        ExplorerShape.round => L("round"),
        ExplorerShape.rectangle => L("rectangle-shaped"),
        ExplorerShape.long => L("long and thin"),
      };

  static Localized modeName(ARExplorerMode mode) => switch (mode) {
        ARExplorerMode.discover => L("Find Things"),
        ARExplorerMode.mystery => L("Mystery"),
        ARExplorerMode.color => L("Colours"),
        ARExplorerMode.shape => L("Shapes"),
        ARExplorerMode.letter => L("Letters"),
        ARExplorerMode.number => L("Counting"),
        ARExplorerMode.scavenger => L("Treasure List"),
        ARExplorerMode.memory => L("Memory"),
        ARExplorerMode.animal => L("Animals"),
        ARExplorerMode.adventure => L("AR Adventure"),
      };

  static Localized modeHint(ARExplorerMode mode) => switch (mode) {
        ARExplorerMode.discover => L("Tap anything around you!"),
        ARExplorerMode.mystery => L("Guess from clues"),
        ARExplorerMode.color => L("Find red, blue…"),
        ARExplorerMode.shape => L("Round or long?"),
        ARExplorerMode.letter => L("Starts with B…"),
        ARExplorerMode.number => L("Count things"),
        ARExplorerMode.scavenger => L("Tick them all!"),
        ARExplorerMode.memory => L("Remember and find"),
        ARExplorerMode.animal => L("Meet animals in your room!"),
        ARExplorerMode.adventure => L("Magic portal & treasure!"),
      };

  static Localized levelName(int number) => switch (number) {
        1 => L("First Explorer"),
        2 => L("Color Explorer"),
        3 => L("Shape Explorer"),
        4 => L("Letter Explorer"),
        5 => L("Number Explorer"),
        6 => L("Memory Explorer"),
        7 => L("Scavenger Explorer"),
        8 => L("Animal Explorer"),
        9 => L("Adventure Explorer"),
        _ => L("ChihChi Master Explorer"),
      };

  static Localized levelIntro(int number) => switch (number) {
        1 => L("Today we'll discover things around you!"),
        2 => L("Today we're going to find colours!"),
        3 => L("Today we're going to find shapes!"),
        4 => L("Today we'll find things by their first letter!"),
        5 => L("Today we're going to count things!"),
        6 => L("Today we'll play a memory game!"),
        7 => L("Today we're going on a scavenger hunt!"),
        8 => L("Today we'll meet animals in your room!"),
        9 => L("Today we'll go on a magic adventure!"),
        10 => L("You're a Master Explorer! Let's mix everything!"),
        _ => L("New adventures are coming soon!"),
      };

  static Localized worldName(ARAdventureWorld world) => switch (world) {
        ARAdventureWorld.forest => L("Forest"),
        ARAdventureWorld.space => L("Space"),
        ARAdventureWorld.ocean => L("Ocean"),
        ARAdventureWorld.dinosaur => L("Dinosaur World"),
        ARAdventureWorld.kingdom => L("Magic Kingdom", key: "Magic Kingdom#2"),
      };
}
