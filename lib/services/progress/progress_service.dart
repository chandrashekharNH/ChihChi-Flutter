import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../data/storage/player_progress.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/home_game.dart';
import '../../domain/models/play_session_record.dart';
import '../../domain/models/puzzle_models.dart';
import '../../domain/models/reward_type.dart';
import '../../domain/models/world_theme.dart';
import '../audio/music_synthesizer.dart';
import 'child_profile_files.dart';

/// Totals for Build the Picture's final scorecard.
class PuzzleTotals {
  const PuzzleTotals(this.stars, this.levelsDone, this.plays, this.moves, this.wrong, this.hints, this.time);
  final int stars, levelsDone, plays, moves, wrong, hints;
  final double time;
}

/// Saving the outcome of one level of any game.
abstract class LevelResultRecording {
  void applyRewards(List<RewardGrant> grants);
  void completeLevel(int level);
  void recordAnswers(int correct, int wrong);
}

/// Catch Letter's own 50-level adventure.
abstract class CatchLetterProgressStoring implements LevelResultRecording {
  void completeCatchLetterLevel(int level, int stars);
}

/// Build the Picture results and totals.
abstract class PuzzleProgressStoring {
  void applyRewards(List<RewardGrant> grants);
  bool recordPuzzle(String id, int? level, PuzzleRunStats stats, int stars, int score);
  int? puzzleLevelStars(int level);
}

/// Every child's saved progress, kept in one JSON file on the device.
class ProgressService extends ChangeNotifier implements CatchLetterProgressStoring, PuzzleProgressStoring {
  ProgressService({File? file}) : _fileOverride = file {
    final first = PlayerProgress();
    _progress = first;
    _profiles = [first];
  }

  final File? _fileOverride;
  late PlayerProgress _progress;
  late List<PlayerProgress> _profiles;
  bool _loaded = false;

  /// The child who is playing.
  PlayerProgress get progress => _progress;

  /// Every child on this device, in the order they were added.
  List<PlayerProgress> get profiles => List.unmodifiable(_profiles);

  File get _file => _fileOverride ?? File('${ChildProfileFiles.baseDirectory.path}/profiles.json');

  Future<void> load() async {
    try {
      if (await _file.exists()) {
        final list = (jsonDecode(await _file.readAsString()) as List)
            .map((j) => PlayerProgress.fromJson((j as Map).cast<String, dynamic>()))
            .toList()
          ..sort((a, b) => a.profileOrder.compareTo(b.profileOrder));
        if (list.isNotEmpty) {
          _profiles = list;
          final activeID = ChildProfileFiles.activeID;
          _progress = list.firstWhere((p) => p.profileID == activeID, orElse: () => list.first);
        }
      }
    } catch (_) {
      // A damaged file: start fresh rather than crash a child's app.
    }
    _loaded = true;
    if (ChildProfileFiles.activeID != _progress.profileID) await ChildProfileFiles.setActiveID(_progress.profileID);
    notifyListeners();
  }

  /// False until the saved progress has been read.
  bool get isStoreAvailable => _loaded;

  void save() {
    notifyListeners();
    if (!_loaded) return;
    final text = jsonEncode(_profiles.map((p) => p.toJson()).toList());
    _file.parent.create(recursive: true).then((_) => _file.writeAsString(text)).catchError((_) => _file);
  }

  // Children (profiles)

  static const maximumProfiles = 6;

  String get activeProfileID => _progress.profileID;
  bool get canAddProfile => _profiles.length < maximumProfiles;

  static String _newID() {
    final r = math.Random.secure();
    String hex(int n) => List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join().toUpperCase();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${hex(4)}-${hex(12)}';
  }

  /// Adds a child with their own progress, rewards and files, and makes them the one playing.
  PlayerProgress? addProfile(String name) {
    if (!canAddProfile) return null;
    final child = PlayerProgress()
      ..profileID = _newID()
      ..profileOrder = _profiles.map((p) => p.profileOrder).fold(0, math.max) + 1
      ..childName = name.trim();
    _profiles.add(child);
    _activate(child);
    return child;
  }

  void switchProfile(String id) {
    if (id == activeProfileID) return;
    final child = _profiles.where((p) => p.profileID == id).firstOrNull;
    if (child != null) _activate(child);
  }

  /// Erases a child and everything saved for them. The last child can't be deleted.
  void deleteProfile(String id) {
    if (_profiles.length <= 1) return;
    final child = _profiles.where((p) => p.profileID == id).firstOrNull;
    if (child == null) return;
    if (id == activeProfileID) {
      final other = _profiles.firstWhere((p) => p.profileID != id);
      _activate(other);
    }
    _profiles.removeWhere((p) => p.profileID == id);
    ChildProfileFiles.deleteFiles(id);
    save();
  }

  /// Language, sound and motion settings belong to the device, so they follow whoever plays.
  void _activate(PlayerProgress child) {
    endPlaySession();
    child.selectedLanguage = _progress.selectedLanguage;
    child.musicEnabled = _progress.musicEnabled;
    child.soundEnabled = _progress.soundEnabled;
    child.voiceEnabled = _progress.voiceEnabled;
    child.hapticsEnabled = _progress.hapticsEnabled;
    child.reducedMotion = _progress.reducedMotion;
    child.musicTrackRaw = _progress.musicTrackRaw;
    _progress = child;
    ChildProfileFiles.setActiveID(child.profileID);
    save();
  }

  GameMusicTrack get musicTrack => GameMusicTrack.fromRaw(_progress.musicTrackRaw) ?? GameMusicTrack.sunnyDay;

  void setGameMusicTrack(GameMusicTrack track) {
    _progress.musicTrackRaw = track.name;
    save();
  }

  @override
  void applyRewards(List<RewardGrant> grants) {
    _progress.addRewards(grants);
    final stars = grants.where((g) => g.type == RewardType.star).fold<int>(0, (s, g) => s + g.amount);
    _updateOpenSession((s) => s.starsEarned += stars);
    save();
  }

  void recordAnswer(bool wasCorrect) {
    if (wasCorrect) {
      _progress.totalCorrectAnswers += 1;
      _progress.currentStreak += 1;
      if (_progress.currentStreak > _progress.bestStreak) _progress.bestStreak = _progress.currentStreak;
    } else {
      _progress.totalWrongAnswers += 1;
      _progress.currentStreak = 0;
    }
    _updateOpenSession((s) => wasCorrect ? s.correctAnswers += 1 : s.wrongAnswers += 1);
    save();
  }

  /// Same result as calling `recordAnswer` for each answer (correct ones first), but saves once.
  @override
  void recordAnswers(int correct, int wrong) {
    if (correct <= 0 && wrong <= 0) return;
    _progress.totalCorrectAnswers += math.max(0, correct);
    _progress.currentStreak += math.max(0, correct);
    _progress.bestStreak = math.max(_progress.bestStreak, _progress.currentStreak);
    if (wrong > 0) {
      _progress.totalWrongAnswers += wrong;
      _progress.currentStreak = 0;
    }
    _updateOpenSession((s) {
      s.correctAnswers += math.max(0, correct);
      s.wrongAnswers += math.max(0, wrong);
    });
    save();
  }

  void saveChildProfile(String name) {
    _progress.childName = name.trim();
    save();
  }

  @override
  void completeLevel(int level) {
    _progress.markLevelCompleted(level);
    _progress.lastPlayedDate = DateTime.now();
    _updateOpenSession((s) => s.recordCompletedLevel(level, null));
    save();
  }

  // Catch Letter adventure

  /// Best stars for a completed Catch Letter level, or null if it isn't completed yet.
  int? catchLetterStars(int level) => _progress.catchLetterStars[level];

  /// Levels open one after another; each world opens when the previous world is finished.
  bool isCatchLetterLevelUnlocked(int level) => level <= 1 || catchLetterStars(level - 1) != null;

  @override
  void completeCatchLetterLevel(int level, int stars) {
    _progress.catchLetterStars[level] = math.max(_progress.catchLetterStars[level] ?? 0, stars);
    _updateOpenSession((s) => s.recordCompletedLevel(level, stars));
    save();
  }

  bool hasSeenBatchIntroduction(int batch) => _progress.seenBatchIntros.contains(batch);

  void markBatchIntroductionSeen(int batch) {
    if (!_progress.seenBatchIntros.add(batch)) return;
    save();
  }

  bool hasSeenRetryTutorial(String key) => _progress.seenRetryTutorials.contains(key);

  void markRetryTutorialSeen(String key) {
    if (!_progress.seenRetryTutorials.add(key)) return;
    save();
  }

  // Build the Picture (puzzles)

  PuzzleDifficulty get puzzleDifficulty => PuzzleDifficulty.fromRaw(_progress.puzzleDifficultyRaw) ?? PuzzleDifficulty.easy;

  void setPuzzleDifficulty(PuzzleDifficulty difficulty) {
    _progress.puzzleDifficultyRaw = difficulty.rawValue;
    save();
  }

  @override
  int? puzzleLevelStars(int level) => _progress.puzzleLevelStars[level];

  bool isPuzzleLevelUnlocked(int level) => level <= 1 || puzzleLevelStars(level - 1) != null;

  PuzzleResult? puzzleResult(String id) => _progress.puzzleResults[id];

  /// Saves one finished puzzle. Returns true when it beat the previous best score.
  @override
  bool recordPuzzle(String id, int? level, PuzzleRunStats stats, int stars, int score) {
    final result = _progress.puzzleResults[id] ?? PuzzleResult();
    final isNewBest = result.plays > 0 && score > result.bestScore;
    result.stars = math.max(result.stars, stars);
    result.bestScore = math.max(result.bestScore, score);
    result.bestTime = result.plays == 0 ? stats.time : math.min(result.bestTime, stats.time);
    result.plays += 1;
    result.totalTime += stats.time;
    result.totalMoves += stats.moves;
    result.totalWrongPlacements += stats.wrongPlacements;
    result.totalHints += stats.hints;
    _progress.puzzleResults[id] = result;
    if (level != null) _progress.puzzleLevelStars[level] = math.max(_progress.puzzleLevelStars[level] ?? 0, stars);
    _progress.lastPlayedDate = DateTime.now();
    _updateOpenSession((s) {
      s.piecesPlaced += stats.pieces;
      s.wrongPlacements += stats.wrongPlacements;
      if (level != null) s.recordCompletedLevel(level, stars);
    });
    save();
    return isNewBest;
  }

  /// Totals for the final scorecard.
  PuzzleTotals get puzzleTotals {
    final results = _progress.puzzleResults.values;
    return PuzzleTotals(
      _progress.puzzleLevelStars.values.fold(0, (a, b) => a + b),
      _progress.puzzleLevelStars.length,
      results.fold(0, (a, r) => a + r.plays),
      results.fold(0, (a, r) => a + r.totalMoves),
      results.fold(0, (a, r) => a + r.totalWrongPlacements),
      results.fold(0, (a, r) => a + r.totalHints),
      results.fold(0.0, (a, r) => a + r.totalTime),
    );
  }

  void setHapticsEnabled(bool enabled) {
    _progress.hapticsEnabled = enabled;
    save();
  }

  void updateLanguage(AppLanguage language) {
    _progress.language = language;
    save();
  }

  void updateWorld(WorldID worldID) {
    _progress.worldID = worldID;
    save();
  }

  void setMusicEnabled(bool v) {
    _progress.musicEnabled = v;
    save();
  }

  void setSoundEnabled(bool v) {
    _progress.soundEnabled = v;
    save();
  }

  void setVoiceEnabled(bool v) {
    _progress.voiceEnabled = v;
    save();
  }

  void resetProgress() {
    final p = _progress;
    p.stars = 0;
    p.candy = 0;
    p.iceCream = 0;
    p.chocolate = 0;
    p.currentLevel = 1;
    p.highestUnlockedLevel = 1;
    p.totalCorrectAnswers = 0;
    p.totalWrongAnswers = 0;
    p.currentStreak = 0;
    p.bestStreak = 0;
    p.completedLevels = {};
    p.catchLetterStars = {};
    p.puzzleLevelStars = {};
    p.puzzleResults = {};
    p.playSessions = [];
    p.lastPlayedDate = null;
    _openSession = null;
    _openSessionResumedAt = null;
    save();
  }

  // Play sessions (Parent Zone activity)

  /// Visits shorter than this with nothing played are not recorded.
  static const double minimumRecordedPlayTime = 5;

  /// Older sessions are dropped so the local history stays small.
  static const Duration playHistoryRetention = Duration(days: 120);

  PlaySessionRecord? _openSession;
  DateTime? _openSessionResumedAt;

  /// Starts timing a game screen. Results saved while it is open are added to the session.
  void beginPlaySession(HomeGame game, [DateTime? at]) {
    final date = at ?? DateTime.now();
    endPlaySession(date);
    _openSession = PlaySessionRecord(game: game, startedAt: date);
    _openSessionResumedAt = date;
  }

  /// Stops the clock (app left the foreground) and saves the session so far.
  void pausePlaySession([DateTime? at]) {
    if (_openSessionResumedAt == null) return;
    _accumulateOpenSessionTime(at ?? DateTime.now());
    _storeOpenSession();
  }

  void resumePlaySession([DateTime? at]) {
    if (_openSession == null || _openSessionResumedAt != null) return;
    _openSessionResumedAt = at ?? DateTime.now();
  }

  void endPlaySession([DateTime? at]) {
    if (_openSession == null) return;
    _accumulateOpenSessionTime(at ?? DateTime.now());
    _storeOpenSession();
    _openSession = null;
  }

  void _accumulateOpenSessionTime(DateTime date) {
    final resumedAt = _openSessionResumedAt;
    if (resumedAt == null) return;
    _openSession?.duration += math.max(0, date.difference(resumedAt).inMilliseconds / 1000);
    _openSessionResumedAt = null;
  }

  void _updateOpenSession(void Function(PlaySessionRecord) change) {
    final session = _openSession;
    if (session != null) change(session);
  }

  /// Saves the open session, replacing its earlier save after a pause.
  void _storeOpenSession() {
    final session = _openSession;
    if (session == null || !(session.hasResults || session.duration >= minimumRecordedPlayTime)) return;
    final cutoff = session.startedAt.subtract(playHistoryRetention);
    final sessions =
        _progress.playSessions.where((s) => s.id != session.id && !s.startedAt.isBefore(cutoff)).toList()..add(session);
    _progress.playSessions = sessions;
    save();
  }

  // Child profile (Parent Zone)

  void updateChildProfile(String name, String avatar) {
    _progress.childName = name.trim();
    _progress.childAvatar = avatar;
    save();
  }

  void setChildGender(ChildGender? gender) {
    _progress.childGender = gender;
    save();
  }

  void setReducedMotion(bool enabled) {
    _progress.reducedMotion = enabled;
    save();
  }

  @visibleForTesting
  PlaySessionRecord? get openSessionForTesting => _openSession;
}
