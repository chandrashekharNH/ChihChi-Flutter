import '../../domain/models/app_language.dart';
import '../../domain/models/play_session_record.dart';
import '../../domain/models/puzzle_models.dart';
import '../../domain/models/reward_type.dart';
import '../../domain/models/world_theme.dart';

/// Whether the child is a boy or a girl — an optional choice that only picks a starting look for
/// their character (hair and clothes).
enum ChildGender {
  boy,
  girl;

  String get emoji => this == ChildGender.boy ? '👦' : '👧';

  static ChildGender? fromRaw(String? raw) {
    for (final g in values) {
      if (g.name == raw) return g;
    }
    return null;
  }
}

/// One child's saved progress (iOS: the SwiftData `PlayerProgress` model).
class PlayerProgress {
  int stars = 0;
  int candy = 0;
  int iceCream = 0;
  int chocolate = 0;
  int currentLevel = 1;
  int highestUnlockedLevel = 1;
  String selectedLanguage = AppLanguage.english.code;
  String selectedWorldID = WorldID.enchantedForest.rawValue;
  int totalCorrectAnswers = 0;
  int totalWrongAnswers = 0;
  int currentStreak = 0;
  int bestStreak = 0;
  DateTime? lastPlayedDate;
  Set<int> completedLevels = {};
  bool musicEnabled = true;
  bool soundEnabled = true;
  bool voiceEnabled = true;
  bool reducedMotion = false;
  String childName = '';

  // Catch Letter adventure (50 levels) — kept separate so other games' unlocks are unaffected.
  Map<int, int> catchLetterStars = {};
  Set<int> seenBatchIntros = {};
  Set<String> seenRetryTutorials = {};

  // Build the Picture (puzzles) — own progress, separate from the other games.
  Map<int, int> puzzleLevelStars = {};
  Map<String, PuzzleResult> puzzleResults = {};
  int puzzleDifficultyRaw = PuzzleDifficulty.easy.rawValue;
  bool hapticsEnabled = true;

  // Parent Zone — local play history and the profile avatar a parent can choose.
  List<PlaySessionRecord> playSessions = [];
  String childAvatar = '';

  /// The chosen background tune; empty means the first one.
  String musicTrackRaw = '';

  // One record per child. The first child's id is empty (from before profiles existed).
  String profileID = '';
  int profileOrder = 0;

  /// `ChildGender`, or empty when not chosen.
  String childGenderRaw = '';

  PlayerProgress();

  ChildGender? get childGender => ChildGender.fromRaw(childGenderRaw);
  set childGender(ChildGender? value) => childGenderRaw = value?.name ?? '';

  AppLanguage get language => AppLanguage.fromCode(selectedLanguage) ?? AppLanguage.english;
  set language(AppLanguage value) => selectedLanguage = value.code;

  WorldID get worldID => WorldID.fromRaw(selectedWorldID) ?? WorldID.enchantedForest;
  set worldID(WorldID value) => selectedWorldID = value.rawValue;

  double get accuracy {
    final total = totalCorrectAnswers + totalWrongAnswers;
    return total == 0 ? 0 : totalCorrectAnswers / total;
  }

  void addRewards(List<RewardGrant> grants) {
    for (final grant in grants) {
      switch (grant.type) {
        case RewardType.star:
          stars += grant.amount;
        case RewardType.candy:
          candy += grant.amount;
        case RewardType.iceCream:
          iceCream += grant.amount;
        case RewardType.chocolate:
          chocolate += grant.amount;
        case RewardType.mystery:
          break;
      }
    }
  }

  void markLevelCompleted(int level) {
    completedLevels.add(level);
    if (level >= highestUnlockedLevel) highestUnlockedLevel = level + 1;
  }

  Map<String, dynamic> toJson() => {
        'stars': stars,
        'candy': candy,
        'iceCream': iceCream,
        'chocolate': chocolate,
        'currentLevel': currentLevel,
        'highestUnlockedLevel': highestUnlockedLevel,
        'selectedLanguage': selectedLanguage,
        'selectedWorldID': selectedWorldID,
        'totalCorrectAnswers': totalCorrectAnswers,
        'totalWrongAnswers': totalWrongAnswers,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'lastPlayedDate': lastPlayedDate?.toIso8601String(),
        'completedLevels': completedLevels.toList(),
        'musicEnabled': musicEnabled,
        'soundEnabled': soundEnabled,
        'voiceEnabled': voiceEnabled,
        'reducedMotion': reducedMotion,
        'childName': childName,
        'catchLetterStars': catchLetterStars.map((k, v) => MapEntry('$k', v)),
        'seenBatchIntros': seenBatchIntros.toList(),
        'seenRetryTutorials': seenRetryTutorials.toList(),
        'puzzleLevelStars': puzzleLevelStars.map((k, v) => MapEntry('$k', v)),
        'puzzleResults': puzzleResults.map((k, v) => MapEntry(k, v.toJson())),
        'puzzleDifficultyRaw': puzzleDifficultyRaw,
        'hapticsEnabled': hapticsEnabled,
        'playSessions': playSessions.map((s) => s.toJson()).toList(),
        'childAvatar': childAvatar,
        'musicTrackRaw': musicTrackRaw,
        'profileID': profileID,
        'profileOrder': profileOrder,
        'childGenderRaw': childGenderRaw,
      };

  static Map<int, int> _intMap(Object? raw) =>
      ((raw as Map?) ?? {}).map((k, v) => MapEntry(int.parse('$k'), (v as num).toInt()));

  factory PlayerProgress.fromJson(Map<String, dynamic> j) {
    final p = PlayerProgress();
    p.stars = j['stars'] as int? ?? 0;
    p.candy = j['candy'] as int? ?? 0;
    p.iceCream = j['iceCream'] as int? ?? 0;
    p.chocolate = j['chocolate'] as int? ?? 0;
    p.currentLevel = j['currentLevel'] as int? ?? 1;
    p.highestUnlockedLevel = j['highestUnlockedLevel'] as int? ?? 1;
    p.selectedLanguage = j['selectedLanguage'] as String? ?? AppLanguage.english.code;
    p.selectedWorldID = j['selectedWorldID'] as String? ?? WorldID.enchantedForest.rawValue;
    p.totalCorrectAnswers = j['totalCorrectAnswers'] as int? ?? 0;
    p.totalWrongAnswers = j['totalWrongAnswers'] as int? ?? 0;
    p.currentStreak = j['currentStreak'] as int? ?? 0;
    p.bestStreak = j['bestStreak'] as int? ?? 0;
    p.lastPlayedDate = DateTime.tryParse(j['lastPlayedDate'] as String? ?? '');
    p.completedLevels = ((j['completedLevels'] as List?) ?? []).map((e) => (e as num).toInt()).toSet();
    p.musicEnabled = j['musicEnabled'] as bool? ?? true;
    p.soundEnabled = j['soundEnabled'] as bool? ?? true;
    p.voiceEnabled = j['voiceEnabled'] as bool? ?? true;
    p.reducedMotion = j['reducedMotion'] as bool? ?? false;
    p.childName = j['childName'] as String? ?? '';
    p.catchLetterStars = _intMap(j['catchLetterStars']);
    p.seenBatchIntros = ((j['seenBatchIntros'] as List?) ?? []).map((e) => (e as num).toInt()).toSet();
    p.seenRetryTutorials = ((j['seenRetryTutorials'] as List?) ?? []).map((e) => '$e').toSet();
    p.puzzleLevelStars = _intMap(j['puzzleLevelStars']);
    p.puzzleResults = ((j['puzzleResults'] as Map?) ?? {})
        .map((k, v) => MapEntry('$k', PuzzleResult.fromJson((v as Map).cast<String, dynamic>())));
    p.puzzleDifficultyRaw = j['puzzleDifficultyRaw'] as int? ?? PuzzleDifficulty.easy.rawValue;
    p.hapticsEnabled = j['hapticsEnabled'] as bool? ?? true;
    p.playSessions = ((j['playSessions'] as List?) ?? [])
        .map((s) => PlaySessionRecord.fromJson((s as Map).cast<String, dynamic>()))
        .whereType<PlaySessionRecord>()
        .toList();
    p.childAvatar = j['childAvatar'] as String? ?? '';
    p.musicTrackRaw = j['musicTrackRaw'] as String? ?? '';
    p.profileID = j['profileID'] as String? ?? '';
    p.profileOrder = j['profileOrder'] as int? ?? 0;
    p.childGenderRaw = j['childGenderRaw'] as String? ?? '';
    return p;
  }
}
