import '../../core/localization/localized.dart';

class ParentText {
  static final parentZone = L("Parent Zone");
  static final forParents = L("For Parents & Guardians");
  static final pleaseSolve = L("Please solve:");
  static final answer = L("Answer");
  static final notQuiteRight = L("That's not quite right. Please try again.");
  static final tryAgain = L("Try Again", key: "Try Again#2");
  static final continueButton = L("Continue");
  static final close = L("Close");
  static Localized gateQuestion(Object? a, Object? b) => L("What is {0} plus {1}?", args: [a, b]);
  static final dashboardTitle = L("Parent Dashboard");
  static final journeySubtitle = L("Your child's learning journey");
  static final exitParentZone = L("Exit Parent Zone");
  static final unavailable = L("Progress is temporarily unavailable.");
  static final childProfile = L("Child Profile");
  static final editProfile = L("Edit Profile");
  static Localized recordedSince(Object? date) => L("Activity recorded since {0}", args: [date]);
  static final nickname = L("Nickname");
  static final nicknamePlaceholder = L("ChihChi Explorer");
  static final avatar = L("Avatar");
  static final nicknameFooter = L("Stored only on this device. ChihChi says this name during games, so a nickname works well.");
  static final save = L("Save");
  static final today = L("Today");
  static final thisWeek = L("This Week");
  static final learningTime = L("Learning Time");
  static final gamesPlayed = L("Games Played");
  static final levelsCompleted = L("Levels Completed");
  static final questionsAnswered = L("Questions Answered");
  static final correctAnswers = L("Correct Answers");
  static final accuracy = L("Accuracy");
  static final starsEarned = L("Stars Earned");
  static final noDataYet = L("No data yet");
  static final noActivityToday = L("No learning activity yet today.");
  static final startJourney = L("Activity will appear here after a game is played. 🌱");
  static final learningProgress = L("Learning Progress");
  static Localized levelsOf(Object? done, Object? total) => L("{0} of {1} levels", args: [done, total]);
  static Localized percentComplete(Object? percent) => L("{0}% complete", args: [percent]);
  static Localized starCount(Object? count) => L("{0} stars", args: [count]);
  static final noLevelsYet = L("No completed levels yet.");
  static final notLevelBased = L("This game has no levels.");
  static final recentActivity = L("Recent Activity");
  static final noRecentActivity = L("Recent games will appear here.");
  static Localized playedFor(Object? duration) => L("Played {0}", args: [duration]);
  static Localized level(Object? n) => L("Level {0}", args: [n]);
  static final lessThanMinute = L("< 1 min");
  static final overallProgress = L("Overall Progress");
  static final performance = L("Performance");
  static final levelProgress = L("Level Progress");
  static final timePlayed = L("Time Played");
  static final placementAccuracy = L("Piece Placement");
  static final trackedLevelsNote = L("Counted from activity recorded on this device.");
  static final noAnswerData = L("This game does not record answers.");
  static final weeklyActivity = L("Weekly Activity");
  static final weeklyChartCaption = L("Learning minutes per day");
  static final noActivityThisWeek = L("No activity recorded this week.");
  static final screenTime = L("Screen Time");
  static final averageSession = L("Average Session");
  static final screenTimeNote = L("Shown for your information only.");
  static final learningStreak = L("Learning Streak");
  static Localized streakDays(Object? days) => L("{0}-day learning streak", args: [days]);
  static Localized minutesOnDay(Object? day, Object? minutes) => L("{0}, {1} minutes", args: [day, minutes]);
  static final learningInsights = L("Learning Insights");
  static final insightsEmpty = L("Insights will appear after a few more games.");
  static final insightsDisclaimer = L("Based only on answers in ChihChi games from the last two weeks. These are gameplay observations, not assessments.");
  static final lettersGoingWell = L("Letter recognition is going well.");
  static final lettersSteady = L("Letter recognition is progressing steadily.");
  static final lettersPractice = L("Letters may benefit from more practice.");
  static final puzzlesGoingWell = L("Picture puzzles are going well.");
  static final puzzlesSteady = L("Picture puzzles are progressing steadily.");
  static final puzzlesPractice = L("Picture puzzles may benefit from more practice.");
  static final rewards = L("Rewards");
  static final noRewards = L("No rewards yet.");
  static final overallStats = L("All Time");
  static final bestStreak = L("Best Answer Streak");
  static final parentSettings = L("Parent Settings");
  static final general = L("General");
  static final gameExperience = L("Game Experience");
  static final privacy = L("Privacy");
  static final support = L("Support");
  static final about = L("About");
  static final parentControls = L("Parent Controls");
  static final audio = L("Audio");
  static final music = L("Music");
  static final soundEffects = L("Sound Effects");
  static final voice = L("Voice");
  static final vibration = L("Vibration");
  static final audioFooter = L("Changes apply right away in every game. Volume follows the device volume.");
  static final language = L("Language");
  static final languageFooter = L("Changes the language of games, voices and menus.");
  static final reducePuzzleMotion = L("Calmer Puzzle Animations");
  static final reducePuzzleMotionFooter = L("Uses gentler animations in Build the Picture. The system Reduce Motion setting is always respected.");
  static final privacyTitle = L("Privacy & Data");
  static final privacyIntro = L("ChihChi is designed with child privacy in mind. Everything below is stored only on this device.");
  static final privacyStoredHeader = L("Stored on this device");
  static final privacyNotHeader = L("What ChihChi does not do");
  static final storesName = L("The name or nickname and avatar entered for the child");
  static final storesProgress = L("Game progress, levels, stars and rewards");
  static final storesActivity = L("Play history for this dashboard: games, time played and answers (kept for 120 days)");
  static final storesSettings = L("Settings such as language, audio and vibration");
  static final noAccounts = L("No accounts, logins or email addresses");
  static final noAds = L("No advertisements");
  static final noTracking = L("No analytics or third-party tracking");
  static final noInternet = L("Works fully offline. The internet is only used for an optional App Store check for new versions and, when a grown-up chooses, to buy or restore Full Adventure through Apple. No personal data is sent");
  static final cameraNote = L("AR Explorer uses the camera only while it is open. Objects are recognised on the device when the child taps; camera pictures are never saved, uploaded or used to identify anyone.");
  static final photosNote = L("Photos taken or chosen for picture puzzles are used only while playing and are never saved or shared.");
  static final deletingNote = L("Deleting ChihChi removes all of its data from this device. Device backups you have enabled may include it.");
  static final resetTitle = L("Reset Progress");
  static final resetDescription = L("Reset all learning progress, levels, rewards and statistics.");
  static final resetButton = L("Reset Progress");
  static final resetQuestion = L("Reset All Progress?");
  static final resetMessage = L("This cannot be undone. All completed levels, stars, rewards and learning statistics will be removed.");
  static final resetKeeps = L("The child profile, language and audio settings are kept.");
  static final resetDone = L("Progress has been reset.");
  static final cancel = L("Cancel", key: "Cancel#2");
  static final supportTitle = L("Support ChihChi");
  static final supportBody = L("ChihChi is designed to give children a fun learning experience without advertisements or subscriptions. The first levels of every game are free.");
  static final supportOptional = L("If your family enjoys ChihChi, sharing it with other families or leaving a review helps future development.");
  static final supportThanks = L("Thank you ❤️");
  static final supportNoPurchase = L("ChihChi has one optional purchase, Full Adventure, which a grown-up can buy in the Parent Zone. There are no subscriptions or recurring payments.");
  static final aboutTitle = L("About ChihChi");
  static final tagline = L("Play. Learn. Explore.");
  static Localized version(Object? version) => L("Version {0}", args: [version]);
  static final games = L("Games");
  static final nameVoice = L("Name in Child's Voice");
  static final nameVoiceSaved = L("Recording saved");
  static final nameVoiceNew = L("New recording – tap Save to keep it");
  static final noNameVoice = L("No recording yet");
  static final play = L("Play");
  static final holdToRecord = L("Hold to record");
  static final recordingNow = L("Recording…");
  static final deleteRecording = L("Delete Recording");
  static final nameVoiceFooter = L("Games say the child's name using this short recording. It is stored only on this device and is never shared.");
  static final micDenied = L("Microphone access is off. Turn it on in Settings › ChihChi to record.");
  static final editCharacter = L("Edit Character");
  static final children = L("Children");
  static final addChild = L("Add Child");
  static final addChildPrompt = L("Enter a nickname. This child gets their own progress, rewards and character.");
  static final playingNow = L("Playing now");
  static final deleteChild = L("Delete Child");
  static Localized deleteChildQuestion(Object? name) => L("Delete {0}?", args: [name]);
  static final deleteChildMessage = L("This child's progress, rewards, name recording and character are erased from this device. This cannot be undone.");
  static final childrenFooter = L("Each child has their own name, character, rewards and progress. Tap a child to switch. Language and sound settings are shared.");
  static final backgroundMusic = L("Background Music");
  static final backgroundMusicFooter = L("Tap a tune to hear it. The chosen tune plays in every game.");
  static final girlsVoices = L("Girls");
  static final boysVoices = L("Boys");
  static Localized voiceMissing(Object? name) => L("No {0} voice is installed on this iPhone, so {0} cannot be spoken properly. Download one in the Settings app: Accessibility › Read & Speak (or Spoken Content) › Voices › {0}.", args: [name]);
  static final girlVoice = L("Girl's voice");
  static final boyVoice = L("Boy's voice");
  static final speakingVoice = L("Speaking Voice");
  static final voiceBasic = L("Basic");
  static final voiceEnhanced = L("Enhanced");
  static final voicePremium = L("Premium");
  static final playSample = L("Play Sample");
  static final voiceTip = L("This is the iPhone's basic voice, which can sound robotic. For a clearer, more natural voice, download an Enhanced or Premium voice for this language in the Settings app: Accessibility › Read & Speak (or Spoken Content) › Voices. ChihChi uses the best voice installed, with no other change needed.");
  static final voiceGood = L("ChihChi is using a natural voice installed on this iPhone.");
  static final childCharacter = L("Child's Character");
  static final deleteCharacter = L("Delete Character");
  static final characterNone = L("No character made — ChihChi is the hero.");
  static final characterDeleteQuestion = L("Delete the child's character?");
  static final characterFooter = L("Only the chosen look (hair, clothes, colours) and a drawing of it are stored, on this device. No photo is ever kept. Deleting brings ChihChi back as the hero; progress is not affected.");
  static final storesCharacter = L("The child's game character, if one was made: the chosen look and a drawing of it (never a photo)");
  static final characterPhotoNote = L("\"From my photo\" asks a grown-up first. The photo is looked at on the device only to suggest skin tone, hair colour and face shape, is never saved or uploaded, and is discarded as soon as the character is made.");
  static final storesNameVoice = L("A short recording of the child saying their name, if one was made");
  static final arExplorer = L("AR Explorer");
  static final explorerLevelStat = L("Explorer Level");
  static final missionsCompleted = L("Missions Completed");
  static final objectsDiscovered = L("Objects Discovered");
  static final favoriteMode = L("Favourite Hunt");
  static final allowARExplorer = L("Allow AR Explorer");
  static final arHints = L("Hints");
  static final arVoiceGuidance = L("Voice Guidance");
  static final arLanguageChallenge = L("Language Challenge");
  static final arWorldItems = L("AR World Items");
  static final arExplorerFooter = L("Voice guidance also needs the Voice setting above to be on. The language challenge asks for a discovered object's name in another language. Camera access itself is managed by iOS in Settings › ChihChi.");
  static final updateAvailable = L("New version available");
  static Localized updateMessage(Object? version) => L("ChihChi {0} is ready on the App Store.", args: [version]);
  static final updateButton = L("Update");
  static final updateBadge = L("Update", key: "Update#2");
  static final timeByGame = L("Time by Game");
  static final lastSevenDays = L("Last 7 Days");
  static final levelMap = L("Level Map");
  static final seeWeeklyActivity = L("See weekly activity & insights");
}

/// Lines that name the iPhone or Apple have an Android version. The Android lines are new, so
/// they show in English until they are translated.
class ParentPlatformText {
  static bool get _android => _isAndroid;
  static bool _isAndroid = false;

  /// Set once at start-up from `Platform.isAndroid`.
  static void configure({required bool android}) => _isAndroid = android;

  static Localized get noInternet => _android
      ? L("Works fully offline. The internet is only used, when a grown-up chooses, to buy or restore Full Adventure through Google Play. No personal data is sent")
      : ParentText.noInternet;

  static Localized voiceMissing(String name) => _android
      ? L("No {0} voice is installed on this phone, so {0} cannot be spoken properly. Install one in the phone's Settings: Text-to-speech output › Speech engine › Install voice data › {0}.", args: [name])
      : ParentText.voiceMissing(name);

  static Localized get voiceTip => _android
      ? L("This voice can sound robotic. For a clearer, more natural voice, install a higher-quality voice for this language in the phone's Settings: Text-to-speech output › Speech engine › Install voice data. ChihChi uses the best voice installed, with no other change needed.")
      : ParentText.voiceTip;

  static Localized get voiceGood => _android ? L('ChihChi is using a natural voice installed on this phone.') : ParentText.voiceGood;

  static Localized get micDenied =>
      _android ? L('Microphone access is off. Turn it on in Settings › Apps › ChihChi › Permissions to record.') : ParentText.micDenied;

  static Localized get arExplorerFooter => _android
      ? L("Voice guidance also needs the Voice setting above to be on. The language challenge asks for a discovered object's name in another language. Camera access itself is managed in Settings › Apps › ChihChi › Permissions.")
      : ParentText.arExplorerFooter;

  static Localized updateMessage(String version) => ParentText.updateMessage(version);
}
