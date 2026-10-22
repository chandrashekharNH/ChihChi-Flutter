import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../services/progress/child_profile_files.dart';
import 'ar_explorer_mission.dart';
import 'ar_explorer_world_content.dart';

/// Everything AR Explorer remembers, saved as one small JSON file on this device (next to the
/// child's name recording). Kept apart from `PlayerProgress`. Stars still go to the shared reward
/// total through `ProgressService`.
class ARExplorerProgress {
  /// Best stars (1–3) per finished Explorer Level.
  Map<int, int> levelStars = {};

  /// Levels whose ChihChi introduction has been shown.
  Set<int> seenIntros = {};
  bool hasSeenSafety = false;
  Set<String> discoveredObjectIDs = {};
  int missionsCompleted = 0;
  int starsEarned = 0;

  /// Finished sessions per mode, for the parent's "favourite mode".
  Map<String, int> modePlays = {};

  /// Items collected for "My AR World" (shared-vocabulary word IDs).
  Set<String> collection = {};

  // Parent settings (kept on reset).
  bool isAllowed = true;
  bool hintsEnabled = true;

  /// ChihChi speaks instructions (also needs the app-wide Voice setting).
  bool voiceGuidance = true;

  /// Offer "What is this in Kannada?" after a discovery.
  bool languageChallenge = true;

  ARExplorerProgress();

  /// Missing keys fall back to defaults, so older files still load.
  factory ARExplorerProgress.fromJson(Map<String, dynamic> j) {
    final p = ARExplorerProgress();
    T? read<T>(String key) => j[key] is T ? j[key] as T : null;
    p.levelStars = {
      for (final e in (read<Map>('levelStars') ?? {}).entries) int.parse('${e.key}'): (e.value as num).toInt()
    };
    p.seenIntros = {for (final v in read<List>('seenIntros') ?? []) (v as num).toInt()};
    p.hasSeenSafety = read<bool>('hasSeenSafety') ?? false;
    p.discoveredObjectIDs = {for (final v in read<List>('discoveredObjectIDs') ?? []) '$v'};
    p.missionsCompleted = read<num>('missionsCompleted')?.toInt() ?? 0;
    p.starsEarned = read<num>('starsEarned')?.toInt() ?? 0;
    p.modePlays = {for (final e in (read<Map>('modePlays') ?? {}).entries) '${e.key}': (e.value as num).toInt()};
    p.collection = {for (final v in read<List>('collection') ?? []) '$v'};
    p.isAllowed = read<bool>('isAllowed') ?? true;
    p.hintsEnabled = read<bool>('hintsEnabled') ?? true;
    p.voiceGuidance = read<bool>('voiceGuidance') ?? true;
    p.languageChallenge = read<bool>('languageChallenge') ?? true;
    return p;
  }

  Map<String, dynamic> toJson() => {
        'levelStars': {for (final e in levelStars.entries) '${e.key}': e.value},
        'seenIntros': seenIntros.toList(),
        'hasSeenSafety': hasSeenSafety,
        'discoveredObjectIDs': discoveredObjectIDs.toList(),
        'missionsCompleted': missionsCompleted,
        'starsEarned': starsEarned,
        'modePlays': modePlays,
        'collection': collection.toList(),
        'isAllowed': isAllowed,
        'hintsEnabled': hintsEnabled,
        'voiceGuidance': voiceGuidance,
        'languageChallenge': languageChallenge,
      };

  /// Level 1 is always open; each finished level opens the next available one.
  bool isLevelUnlocked(ARExplorerLevel level) {
    if (!level.isAvailable) return false;
    if (level.number == 1) return true;
    final previous = ARExplorerLevel.all.where((l) => l.number < level.number && l.isAvailable).lastOrNull;
    return previous == null || levelStars[previous.number] != null;
  }

  bool isModeUnlocked(ARExplorerMode mode) {
    final level = ARExplorerLevel.level(mode.unlockLevel);
    return level != null && isLevelUnlocked(level);
  }

  /// "Explorer Level N": the highest level the child can play.
  int get explorerLevel {
    final open = ARExplorerLevel.all.where(isLevelUnlocked).map((l) => l.number);
    return open.isEmpty ? 1 : open.reduce((a, b) => a > b ? a : b);
  }

  /// The most played mode, only once it clearly leads (at least 3 plays, no tie).
  ARExplorerMode? get favoriteMode {
    final sorted = modePlays.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty || sorted.first.value < 3) return null;
    if (sorted.length > 1 && sorted[1].value == sorted.first.value) return null;
    return ARExplorerMode.fromRaw(sorted.first.key);
  }
}

class ARExplorerProgressStore extends ChangeNotifier {
  ARExplorerProgressStore({Directory? directory})
      : _file = File('${(directory ?? ChildProfileFiles.activeDirectory).path}/ar-explorer-progress.json') {
    progress = _load(_file);
  }

  final File _file;
  late ARExplorerProgress progress;

  /// Read-only snapshot for screens that only display progress (e.g. the Parent Zone).
  static ARExplorerProgress snapshot({Directory? directory}) =>
      _load(File('${(directory ?? ChildProfileFiles.activeDirectory).path}/ar-explorer-progress.json'));

  void finishLevel(int number, int stars) => _update((p) {
        final s = stars.clamp(1, 3);
        p.levelStars[number] = (p.levelStars[number] ?? 0) > s ? p.levelStars[number]! : s;
      });

  void markIntroSeen(int level) => _update((p) => p.seenIntros.add(level));
  void markSafetySeen() => _update((p) => p.hasSeenSafety = true);

  void recordDiscovery(String objectID) {
    if (progress.discoveredObjectIDs.contains(objectID)) return;
    _update((p) => p.discoveredObjectIDs.add(objectID));
  }

  void recordMission(int stars) => _update((p) {
        p.missionsCompleted += 1;
        p.starsEarned += stars;
      });

  void recordFinishedSession(ARExplorerMode mode) =>
      _update((p) => p.modePlays[mode.rawValue] = (p.modePlays[mode.rawValue] ?? 0) + 1);

  void setAllowed(bool v) => _update((p) => p.isAllowed = v);
  void setHintsEnabled(bool v) => _update((p) => p.hintsEnabled = v);
  void setVoiceGuidance(bool v) => _update((p) => p.voiceGuidance = v);
  void setLanguageChallenge(bool v) => _update((p) => p.languageChallenge = v);

  /// Adds the level's "My AR World" item the first time; returns it when it is new.
  String? collectReward(int level) {
    final item = ARExplorerWorldCatalog.levelRewards[level];
    if (item == null || progress.collection.contains(item)) return null;
    _update((p) => p.collection.add(item));
    return item;
  }

  /// Clears learning progress but keeps the parent's settings and the seen safety note.
  void resetLearningProgress() {
    final fresh = ARExplorerProgress()
      ..isAllowed = progress.isAllowed
      ..hintsEnabled = progress.hintsEnabled
      ..voiceGuidance = progress.voiceGuidance
      ..languageChallenge = progress.languageChallenge
      ..hasSeenSafety = progress.hasSeenSafety;
    progress = fresh;
    _write();
    notifyListeners();
  }

  void _update(void Function(ARExplorerProgress) change) {
    change(progress);
    _write();
    notifyListeners();
  }

  void _write() {
    try {
      _file.parent.createSync(recursive: true);
      _file.writeAsStringSync(jsonEncode(progress.toJson()), flush: true);
    } catch (_) {
      // Progress stays in memory for this session; the game keeps working.
    }
  }

  static ARExplorerProgress _load(File file) {
    try {
      if (!file.existsSync()) return ARExplorerProgress();
      return ARExplorerProgress.fromJson((jsonDecode(file.readAsStringSync()) as Map).cast<String, dynamic>());
    } catch (_) {
      return ARExplorerProgress();
    }
  }
}
