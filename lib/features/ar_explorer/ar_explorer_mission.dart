import 'dart:math' as math;

import '../../domain/models/app_language.dart';
import 'ar_explorer_content.dart';
import 'ar_explorer_world_content.dart';

// Modes, Explorer Levels and missions for AR Explorer, plus the pure rules that build a session and
// judge a tap. No UI, no camera: easy to test and to extend with new content.

enum ARExplorerMode {
  discover('🔎', 1),
  mystery('🕵️', 4),
  color('🎨', 2),
  shape('🔷', 3),
  letter('🔤', 4),
  number('🔢', 5),
  scavenger('🎒', 7),
  memory('🧠', 6),
  animal('🐾', 8),
  adventure('🚀', 9);

  const ARExplorerMode(this.icon, this.unlockLevel);
  final String icon;

  /// The Explorer Level that opens this mode for free play.
  final int unlockLevel;

  String get rawValue => name;

  /// Modes that place ChihChi's own content in the room instead of only reading the camera.
  bool get usesVirtualStage => this == animal || this == adventure;

  /// Challenges in one short session (a scavenger list counts as one).
  int get sessionLength {
    switch (this) {
      case scavenger:
        return 1;
      case memory:
      case number:
      case mystery:
      case animal:
        return 3;
      case adventure:
        return 7;
      default:
        return 5;
    }
  }

  static ARExplorerMode? fromRaw(String? raw) => values.where((m) => m.name == raw).firstOrNull;
}

class ARExplorerLevel {
  const ARExplorerLevel(this.number, this.icon, this.modes);
  final int number;
  final String icon;

  /// Modes mixed in this level. Empty would mean the level is not in this version.
  final List<ARExplorerMode> modes;

  bool get isAvailable => modes.isNotEmpty;

  /// The ten levels, opened one after another.
  static const all = [
    ARExplorerLevel(1, '🌱', [ARExplorerMode.discover]),
    ARExplorerLevel(2, '🎨', [ARExplorerMode.color]),
    ARExplorerLevel(3, '🔷', [ARExplorerMode.shape]),
    ARExplorerLevel(4, '🔤', [ARExplorerMode.letter]),
    ARExplorerLevel(5, '🔢', [ARExplorerMode.number]),
    ARExplorerLevel(6, '🧠', [ARExplorerMode.memory]),
    ARExplorerLevel(7, '🎒', [ARExplorerMode.scavenger]),
    ARExplorerLevel(8, '🐾', [ARExplorerMode.animal]),
    ARExplorerLevel(9, '🚀', [ARExplorerMode.adventure]),
    ARExplorerLevel(10, '🌎',
        [ARExplorerMode.color, ARExplorerMode.shape, ARExplorerMode.letter, ARExplorerMode.mystery, ARExplorerMode.number]),
  ];

  static ARExplorerLevel? level(int number) => all.where((l) => l.number == number).firstOrNull;

  /// The available level after `number`, skipping levels not in this version.
  static ARExplorerLevel? next(int number) => all.where((l) => l.number > number && l.isAvailable).firstOrNull;

  @override
  bool operator ==(Object other) => other is ARExplorerLevel && other.number == number;
  @override
  int get hashCode => number;
}

// Missions

sealed class MissionGoal {
  const MissionGoal();

  /// Answered by tapping ChihChi's own content (or the floor to place it), not by recognition.
  bool get isVirtual => this is MeetAnimal || this is OpenPortal || this is CollectTreasure;
}

/// Tap anything ChihChi knows.
class DiscoverAnything extends MissionGoal {
  const DiscoverAnything();
}

/// Tap one particular object (mystery objects, "find another").
class FindObject extends MissionGoal {
  const FindObject(this.id);
  final String id;
}

class FindColor extends MissionGoal {
  const FindColor(this.color);
  final ExplorerColor color;
}

class FindShape extends MissionGoal {
  const FindShape(this.shape);
  final ExplorerShape shape;
}

/// An object whose name starts with this letter in the current language.
class FindLetter extends MissionGoal {
  const FindLetter(this.letter);
  final String letter;
}

/// Tap this many different objects, then say how many.
class CountObjects extends MissionGoal {
  const CountObjects(this.count);
  final int count;
}

/// A checklist; any tap can tick any unticked item.
class Scavenger extends MissionGoal {
  const Scavenger(this.items);
  final List<ScavengerItem> items;
}

/// Remember these objects, then find `ask`.
class MemoryRound extends MissionGoal {
  const MemoryRound(this.objects, this.ask);
  final List<String> objects;
  final String ask;
}

/// Something of this colour whose shape we know (Master Explorer).
class FindColorAndShape extends MissionGoal {
  const FindColorAndShape(this.color, this.shape);
  final ExplorerColor color;
  final ExplorerShape shape;
}

/// A virtual animal stands in the room: meet it, tap it, name it.
class MeetAnimal extends MissionGoal {
  const MeetAnimal(this.id);
  final String id;
}

/// Open the magic portal (AR Adventure's first step).
class OpenPortal extends MissionGoal {
  const OpenPortal(this.world);
  final ARAdventureWorld world;
}

/// Find and tap a virtual treasure hidden near ChihChi.
class CollectTreasure extends MissionGoal {
  const CollectTreasure(this.treasure);
  final ARTreasure treasure;
}

/// One thing on a scavenger list.
class ScavengerItem {
  const ScavengerItem.color(ExplorerColor this.color)
      : shape = null,
        letter = null,
        objectID = null;
  const ScavengerItem.shape(ExplorerShape this.shape)
      : color = null,
        letter = null,
        objectID = null;
  const ScavengerItem.letter(String this.letter)
      : color = null,
        shape = null,
        objectID = null;
  const ScavengerItem.object(String this.objectID)
      : color = null,
        shape = null,
        letter = null;

  final ExplorerColor? color;
  final ExplorerShape? shape;
  final String? letter;
  final String? objectID;

  @override
  bool operator ==(Object other) =>
      other is ScavengerItem &&
      other.color == color &&
      other.shape == shape &&
      other.letter == letter &&
      other.objectID == objectID;
  @override
  int get hashCode => Object.hash(color, shape, letter, objectID);
}

class ARExplorerMission {
  ARExplorerMission(this.goal, this.stars) : id = _next++;
  static int _next = 0;

  final int id;
  final MissionGoal goal;
  final int stars;

  /// Brings back a Magic Star in AR Adventure's story (the real-world challenges do).
  bool get restoresMagicStar => goal is FindColor || goal is FindShape || goal is FindLetter || goal is FindColorAndShape;

  @override
  bool operator ==(Object other) => other is ARExplorerMission && other.id == id;
  @override
  int get hashCode => id;
}

class ARExplorerMissionGenerator {
  /// A short session for a mode. Only picks targets the game can actually recognise, and avoids
  /// repeating the same target in one session.
  static List<ARExplorerMission> session(ARExplorerMode mode, AppLanguage language, math.Random random) {
    List<T> shuffled<T>(Iterable<T> items) => items.toList()..shuffle(random);
    switch (mode) {
      case ARExplorerMode.discover:
        return [for (var i = 0; i < mode.sessionLength; i++) ARExplorerMission(const DiscoverAnything(), 2)];
      case ARExplorerMode.color:
        return shuffled(ExplorerColor.values).take(mode.sessionLength).map((c) => ARExplorerMission(FindColor(c), 2)).toList();
      case ARExplorerMode.shape:
        // Cycle through the shapes so every session practises each one.
        final order = shuffled(findableShapes);
        return [
          for (var i = 0; i < mode.sessionLength; i++) ARExplorerMission(FindShape(order[i % order.length]), 2),
        ];
      case ARExplorerMode.letter:
        return shuffled(ARExplorerCatalog.huntableLetters(language))
            .take(mode.sessionLength)
            .map((l) => ARExplorerMission(FindLetter(l), 3))
            .toList();
      case ARExplorerMode.mystery:
        return shuffled(ARExplorerCatalog.mysteryObjects)
            .take(mode.sessionLength)
            .map((o) => ARExplorerMission(FindObject(o.id), 3))
            .toList();
      case ARExplorerMode.number:
        return [for (var i = 0; i < mode.sessionLength; i++) ARExplorerMission(CountObjects(2 + random.nextInt(2)), 3)];
      case ARExplorerMode.memory:
        return [
          for (var i = 0; i < mode.sessionLength; i++)
            () {
              final objects = shuffled(ARExplorerCatalog.commonObjects).take(3).map((o) => o.id).toList();
              return ARExplorerMission(MemoryRound(objects, objects[random.nextInt(objects.length)]), 3);
            }(),
        ];
      case ARExplorerMode.scavenger:
        return [ARExplorerMission(Scavenger(scavengerList(language, random)), 10)];
      case ARExplorerMode.animal:
        return shuffled(ARExplorerWorldCatalog.animals)
            .take(mode.sessionLength)
            .map((a) => ARExplorerMission(MeetAnimal(a.id), 3))
            .toList();
      case ARExplorerMode.adventure:
        return adventureStory(language, random);
    }
  }

  /// "The Magic Stars are lost!": open the portal, then three times find a treasure and do a
  /// real-world challenge; each challenge brings back one Magic Star.
  static List<ARExplorerMission> adventureStory(AppLanguage language, math.Random random) {
    final world = ARAdventureWorld.values[random.nextInt(ARAdventureWorld.values.length)];
    final treasures = ARTreasure.values.toList()..shuffle(random);
    final challenges = <MissionGoal>[
      FindColor(ExplorerColor.values[random.nextInt(ExplorerColor.values.length)]),
      if (findableShapes.isNotEmpty) FindShape(findableShapes[random.nextInt(findableShapes.length)]),
    ];
    final letters = ARExplorerCatalog.huntableLetters(language);
    if (letters.isNotEmpty) challenges.add(FindLetter(letters[random.nextInt(letters.length)]));
    final missions = [ARExplorerMission(OpenPortal(world), 2)];
    for (var i = 0; i < challenges.length; i++) {
      missions.add(ARExplorerMission(CollectTreasure(treasures[i % treasures.length]), 3));
      missions.add(ARExplorerMission(challenges[i], 3));
    }
    return missions;
  }

  /// A mixed Master Explorer session: one challenge from each mode in the level, plus one that
  /// combines a colour and a shape ("something RED that is ROUND").
  static List<ARExplorerMission> masterSession(List<ARExplorerMode> modes, AppLanguage language, math.Random random) {
    final missions = [
      for (final mode in modes)
        if (session(mode, language, random).isNotEmpty) session(mode, language, random).first,
    ];
    if (modes.contains(ARExplorerMode.color) && modes.contains(ARExplorerMode.shape) && findableShapes.isNotEmpty) {
      final color = ExplorerColor.values[random.nextInt(ExplorerColor.values.length)];
      final shape = findableShapes[random.nextInt(findableShapes.length)];
      missions.add(ARExplorerMission(FindColorAndShape(color, shape), 4));
    }
    return missions;
  }

  /// Shapes with at least one recognisable object.
  static List<ExplorerShape> get findableShapes =>
      ExplorerShape.values.where((s) => ARExplorerCatalog.shaped(s).isNotEmpty).toList();

  static List<ScavengerItem> scavengerList(AppLanguage language, math.Random random) {
    final colors = (ExplorerColor.values.toList()..shuffle(random)).take(2).map(ScavengerItem.color);
    final shape = ScavengerItem.shape(ExplorerShape.values[random.nextInt(ExplorerShape.values.length)]);
    final letters = ARExplorerCatalog.huntableLetters(language);
    final common = ARExplorerCatalog.commonObjects;
    return [
      ...colors,
      shape,
      if (letters.isNotEmpty) ScavengerItem.letter(letters[random.nextInt(letters.length)]),
      if (common.isNotEmpty) ScavengerItem.object(common[random.nextInt(common.length)].id),
    ];
  }
}

// Judging a tap

/// What was found instead of the answer asked for.
class SeenThing {
  const SeenThing.object(String this.objectID)
      : color = null,
        noColor = false;
  const SeenThing.color(ExplorerColor this.color)
      : objectID = null,
        noColor = false;
  const SeenThing.noColor()
      : objectID = null,
        color = null,
        noColor = true;

  final String? objectID;
  final ExplorerColor? color;
  final bool noColor;

  @override
  bool operator ==(Object other) =>
      other is SeenThing && other.objectID == objectID && other.color == color && other.noColor == noColor;
  @override
  int get hashCode => Object.hash(objectID, color, noColor);
}

enum JudgementKind { correct, notQuite, unsure }

class ARExplorerJudgement {
  const ARExplorerJudgement.correct([this.objectID])
      : kind = JudgementKind.correct,
        seen = null;
  const ARExplorerJudgement.notQuite(SeenThing this.seen)
      : kind = JudgementKind.notQuite,
        objectID = null;
  const ARExplorerJudgement.unsure()
      : kind = JudgementKind.unsure,
        objectID = null,
        seen = null;

  final JudgementKind kind;

  /// Right answer: the object, if one was recognised.
  final String? objectID;

  /// Not quite: what was found instead.
  final SeenThing? seen;

  @override
  bool operator ==(Object other) =>
      other is ARExplorerJudgement && other.kind == kind && other.objectID == objectID && other.seen == seen;
  @override
  int get hashCode => Object.hash(kind, objectID, seen);
}

/// Find Things asks "Is this a cup?" after every tap; this is what the child's answer earns.
enum QuizOutcomeKind {
  /// It is the thing, and the child said yes.
  found,

  /// It is the thing, but the child said no.
  missed,

  /// It is something else, and the child said no: well spotted.
  rightNo,

  /// It is something else, but the child said yes.
  wrongYes,

  /// The camera couldn't tell and the child said no: move on.
  skipped,
}

class QuizOutcome {
  const QuizOutcome(this.kind, [this.seen]);
  final QuizOutcomeKind kind;
  final String? seen;

  @override
  bool operator ==(Object other) => other is QuizOutcome && other.kind == kind && other.seen == seen;
  @override
  int get hashCode => Object.hash(kind, seen);
}

class ARExplorerJudge {
  /// Judges a confident recognition against a mission goal (probable results are confirmed by the
  /// child first and then judged as confident).
  static ARExplorerJudgement judge(MissionGoal goal, String? objectID, ExplorerColor? color, AppLanguage language) {
    final object = objectID == null ? null : ARExplorerCatalog.object(objectID);
    switch (goal) {
      case DiscoverAnything():
      case CountObjects():
        return object == null ? const ARExplorerJudgement.unsure() : ARExplorerJudgement.correct(object.id);
      case FindObject(:final id):
      case MemoryRound(ask: final id):
        if (object == null) return const ARExplorerJudgement.unsure();
        return object.id == id ? ARExplorerJudgement.correct(id) : ARExplorerJudgement.notQuite(SeenThing.object(object.id));
      case FindColor(color: final target):
        if (color == null) return const ARExplorerJudgement.notQuite(SeenThing.noColor());
        return color == target ? ARExplorerJudgement.correct(object?.id) : ARExplorerJudgement.notQuite(SeenThing.color(color));
      case FindShape(shape: final target):
        if (object == null) return const ARExplorerJudgement.unsure();
        return object.shape == target
            ? ARExplorerJudgement.correct(object.id)
            : ARExplorerJudgement.notQuite(SeenThing.object(object.id));
      case FindColorAndShape(color: final targetColor, shape: final targetShape):
        // Both must be known: the colour under the finger and a confidently named object.
        if (color == null) return const ARExplorerJudgement.notQuite(SeenThing.noColor());
        if (color != targetColor) return ARExplorerJudgement.notQuite(SeenThing.color(color));
        if (object == null) return const ARExplorerJudgement.unsure();
        return object.shape == targetShape
            ? ARExplorerJudgement.correct(object.id)
            : ARExplorerJudgement.notQuite(SeenThing.object(object.id));
      case FindLetter(:final letter):
        if (object == null) return const ARExplorerJudgement.unsure();
        return object.firstLetter(language) == letter
            ? ARExplorerJudgement.correct(object.id)
            : ARExplorerJudgement.notQuite(SeenThing.object(object.id));
      case Scavenger():
      // Scavenger taps are matched item by item; see `scavengerMatch`.
      case MeetAnimal():
      case OpenPortal():
      case CollectTreasure():
        // Virtual goals are answered by tapping ChihChi's own content, never by recognition.
        return const ARExplorerJudgement.unsure();
    }
  }

  /// `seen` is what the camera is sure the tapped thing is, or null when it can't tell — then the
  /// child's own answer is believed.
  static QuizOutcome quizOutcome(String target, String? seen, bool saidYes) {
    if (seen == null) return QuizOutcome(saidYes ? QuizOutcomeKind.found : QuizOutcomeKind.skipped);
    if (seen == target) return QuizOutcome(saidYes ? QuizOutcomeKind.found : QuizOutcomeKind.missed);
    return QuizOutcome(saidYes ? QuizOutcomeKind.wrongYes : QuizOutcomeKind.rightNo, seen);
  }

  /// The first unticked scavenger item this tap satisfies.
  static ScavengerItem? scavengerMatch(List<ScavengerItem> items, Set<ScavengerItem> ticked, String? objectID,
      ExplorerColor? color, AppLanguage language) {
    final object = objectID == null ? null : ARExplorerCatalog.object(objectID);
    for (final item in items) {
      if (ticked.contains(item)) continue;
      if (item.color != null && color == item.color) return item;
      if (item.shape != null && object?.shape == item.shape) return item;
      if (item.letter != null && object?.firstLetter(language) == item.letter) return item;
      if (item.objectID != null && object?.id == item.objectID) return item;
    }
    return null;
  }
}
