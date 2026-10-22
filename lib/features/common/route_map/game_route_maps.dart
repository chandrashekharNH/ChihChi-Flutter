import 'dart:ui';

import '../../../core/ui/palette.dart';
import '../../../domain/models/app_language.dart';
import '../../../domain/models/catch_letter_level.dart';
import '../../../domain/models/catch_letter_strings.dart';
import '../../../domain/models/puzzle_models.dart';
import '../../../domain/models/run_collect.dart';
import '../../../domain/models/ui_text.dart';
import 'route_map_content.dart';
import 'route_map_text.dart';

/// Builds each game's route map from its own progress. The games' unlock rules stay theirs; the
/// map only shows them.
class GameRouteMaps {
  // Catch Letter (10 worlds × 5 levels)
  static RouteMapContent catchLetter({
    required int? Function(int) stars,
    required bool Function(int) unlocked,
    required AppLanguage language,
  }) {
    final lands = [
      for (final batch in CatchLetterBatch.values)
        _land(batch.index + 1, batch.icon, CatchLetterStrings.batchTitle(batch, language), batch.gradient,
            batch.ambientEmojis, batch.levels, language, (level) => _state(stars(level), unlocked(level))),
    ];
    return RouteMapContent(
      start: RouteMapHub('🐣', RouteMapText.start(language)),
      startColors: [rgb(0.6, 0.85, 0.5), rgb(0.45, 0.75, 0.4)],
      startDecorations: const ['🌷', '🌼', '🐝', '🌳'],
      lands: lands,
      openColor: rgb(1, 0.5, 0.25),
    );
  }

  // Build the Picture (10 worlds × 10 levels)
  static RouteMapContent buildPicture({
    required List<PuzzleWorld> worlds,
    required int? Function(int) stars,
    required bool Function(int) unlocked,
    required bool Function(int) hasPuzzle,
    required AppLanguage language,
  }) {
    final lands = [
      for (final world in worlds)
        _land(world.id, world.category.icon, UIText.categoryName(world.category).resolve(language),
            _categoryColors(world.category), _categoryDecorations(world.category), world.levels, language,
            (level) => _state(stars(level), unlocked(level) && hasPuzzle(level))),
    ];
    return RouteMapContent(
      start: RouteMapHub('🖼️', RouteMapText.artStudio(language)),
      startColors: [rgb(0.75, 0.6, 1), rgb(0.55, 0.4, 0.9)],
      startDecorations: const ['🎨', '🖍️', '✏️', '🧩'],
      lands: lands,
      openColor: rgb(0.55, 0.3, 0.9),
    );
  }

  // Learn Blaster (its own worlds, 20 levels)
  static RouteMapContent learnBlaster({
    required int totalLevels,
    required int highestUnlocked,
    required Set<int> completed,
    required AppLanguage language,
  }) {
    final groups = <(RunCollectWorld, List<int>)>[];
    for (var level = 1; level <= (totalLevels < 1 ? 1 : totalLevels); level++) {
      final world = RunCollectLevelConfig.configuration(level).world;
      if (groups.isNotEmpty && groups.last.$1 == world) {
        groups.last.$2.add(level);
      } else {
        groups.add((world, [level]));
      }
    }
    final lands = [
      for (var i = 0; i < groups.length; i++)
        _land(i + 1, groups[i].$1.emoji, RouteMapText.blasterWorld(groups[i].$1, language), _worldColors(groups[i].$1),
            _worldDecorations(groups[i].$1), groups[i].$2, language,
            (level) => _sharedLevelState(level, highestUnlocked, completed)),
    ];
    return RouteMapContent(
      start: RouteMapHub('🛸', RouteMapText.launchPad(language)),
      startColors: [rgb(0.3, 0.35, 0.7), rgb(0.2, 0.22, 0.5)],
      startDecorations: const ['⭐', '🛰️', '✨'],
      lands: lands,
      openColor: rgb(0.3, 0.5, 1),
    );
  }

  // Catch World (4 map lands × 5 levels)
  static RouteMapContent catchWorld({
    required int totalLevels,
    required int highestUnlocked,
    required Set<int> completed,
    required AppLanguage language,
  }) {
    final themes = <(String, String, List<Color>, List<String>)>[
      ('🌼', RouteMapText.meadow(language), [rgb(0.6, 0.85, 0.45), rgb(0.4, 0.7, 0.35)], ['🌷', '🦋', '🐞', '🌻']),
      ('🏖️', RouteMapText.beach(language), [rgb(0.45, 0.8, 0.95), rgb(0.95, 0.85, 0.6)], ['🐚', '🦀', '⛱️', '🌊']),
      ('🌴', RouteMapText.jungle(language), [rgb(0.25, 0.6, 0.3), rgb(0.12, 0.42, 0.2)], ['🐒', '🦜', '🌿', '🐘']),
      ('🌈', RouteMapText.rainbowHills(language), [rgb(1, 0.65, 0.8), rgb(0.6, 0.5, 0.95)], ['☁️', '🦄', '✨', '🎈']),
    ];
    final perLand = (totalLevels / themes.length).ceil().clamp(1, 1 << 20);
    final lands = <RouteMapLand>[];
    for (var i = 0; i < themes.length; i++) {
      final first = i * perLand + 1;
      final last = (first + perLand - 1).clamp(0, totalLevels);
      if (first > last) continue;
      final t = themes[i];
      lands.add(_land(i + 1, t.$1, t.$2, t.$3, t.$4, [for (var l = first; l <= last; l++) l], language,
          (level) => _sharedLevelState(level, highestUnlocked, completed)));
    }
    return RouteMapContent(
      start: RouteMapHub('🌍', RouteMapText.start(language)),
      startColors: [rgb(0.55, 0.85, 0.7), rgb(0.35, 0.7, 0.6)],
      startDecorations: const ['🌳', '🏡', '🌷'],
      lands: lands,
      openColor: rgb(0.2, 0.6, 0.75),
    );
  }

  // Helpers

  static RouteMapLand _land(int id, String landmark, String name, List<Color> colors, List<String> decorations,
      Iterable<int> levels, AppLanguage language, RouteMapStopState Function(int) state) {
    final stops = [
      for (final level in levels)
        () {
          final s = state(level);
          final label = s.isCompleted && s.stars != null
              ? RouteMapText.levelStars(level, s.stars!, language)
              : RouteMapText.level(level, language);
          return RouteMapStop(level: level, icon: '$level', state: s, accessibilityLabel: label);
        }(),
    ];
    return RouteMapLand(
      id: id,
      hub: RouteMapHub(landmark, name),
      colors: colors,
      decorations: decorations,
      isReached: stops.isNotEmpty && stops.first.isPlayable,
      stops: stops,
    );
  }

  static RouteMapStopState _state(int? stars, bool isUnlocked) {
    if (stars != null) return RouteMapStopState.completed(stars);
    return isUnlocked ? RouteMapStopState.open : RouteMapStopState.locked;
  }

  /// Catch World and Learn Blaster share one record of opened and finished levels (no stars per level).
  static RouteMapStopState _sharedLevelState(int level, int highestUnlocked, Set<int> completed) {
    if (completed.contains(level)) return const RouteMapStopState.completed();
    return level <= (highestUnlocked < 1 ? 1 : highestUnlocked) ? RouteMapStopState.open : RouteMapStopState.locked;
  }

  static List<Color> _categoryColors(PuzzleCategory category) {
    switch (category) {
      case PuzzleCategory.animals:
        return [rgb(0.95, 0.75, 0.4), rgb(0.8, 0.55, 0.25)];
      case PuzzleCategory.nature:
        return [rgb(0.45, 0.78, 0.45), rgb(0.25, 0.58, 0.3)];
      case PuzzleCategory.vehicles:
        return [rgb(0.6, 0.7, 0.85), rgb(0.4, 0.5, 0.7)];
      case PuzzleCategory.food:
        return [rgb(1, 0.65, 0.55), rgb(0.9, 0.4, 0.4)];
      case PuzzleCategory.space:
        return [rgb(0.25, 0.25, 0.55), rgb(0.1, 0.1, 0.3)];
      case PuzzleCategory.dinosaurs:
        return [rgb(0.55, 0.7, 0.3), rgb(0.4, 0.52, 0.2)];
      case PuzzleCategory.objects:
        return [rgb(0.95, 0.7, 0.8), rgb(0.8, 0.5, 0.65)];
      case PuzzleCategory.places:
        return [rgb(0.55, 0.75, 0.95), rgb(0.35, 0.55, 0.8)];
      case PuzzleCategory.india:
        return [rgb(1, 0.7, 0.35), rgb(0.2, 0.6, 0.35)];
      case PuzzleCategory.letters:
        return [rgb(0.45, 0.65, 1), rgb(0.3, 0.4, 0.85)];
      case PuzzleCategory.numbers:
        return [rgb(0.4, 0.8, 0.8), rgb(0.2, 0.55, 0.6)];
      case PuzzleCategory.colors:
        return [rgb(1, 0.55, 0.75), rgb(0.6, 0.4, 0.95)];
      case PuzzleCategory.words:
        return [rgb(0.95, 0.8, 0.4), rgb(0.85, 0.6, 0.25)];
    }
  }

  static List<String> _categoryDecorations(PuzzleCategory category) {
    switch (category) {
      case PuzzleCategory.animals:
        return const ['🦁', '🐘', '🦒', '🌴'];
      case PuzzleCategory.nature:
        return const ['🌳', '🌸', '🦋', '🍄'];
      case PuzzleCategory.vehicles:
        return const ['🚗', '🚌', '🚦', '🚲'];
      case PuzzleCategory.food:
        return const ['🍎', '🍌', '🥕', '🍇'];
      case PuzzleCategory.space:
        return const ['⭐', '🪐', '🌙', '☄️'];
      case PuzzleCategory.dinosaurs:
        return const ['🦕', '🌋', '🌿', '🥚'];
      case PuzzleCategory.objects:
        return const ['🧸', '⚽', '🎈', '📦'];
      case PuzzleCategory.places:
        return const ['🏠', '🏫', '🏥', '🌳'];
      case PuzzleCategory.india:
        return const ['🪔', '🛺', '🐘', '🌺'];
      case PuzzleCategory.letters:
        return const ['🔤', '✏️', '📖'];
      case PuzzleCategory.numbers:
        return const ['🔢', '➕', '📏'];
      case PuzzleCategory.colors:
        return const ['🎨', '🌈', '🖍️'];
      case PuzzleCategory.words:
        return const ['📚', '💬', '✏️'];
    }
  }

  static List<Color> _worldColors(RunCollectWorld world) {
    switch (world) {
      case RunCollectWorld.enchantedForest:
        return [rgb(0.35, 0.7, 0.4), rgb(0.15, 0.45, 0.25)];
      case RunCollectWorld.colorfulCity:
        return [rgb(1, 0.72, 0.4), rgb(0.85, 0.45, 0.55)];
      case RunCollectWorld.iceKingdom:
        return [rgb(0.85, 0.95, 1), rgb(0.6, 0.8, 0.95)];
      case RunCollectWorld.candyLand:
        return [rgb(1, 0.7, 0.85), rgb(0.9, 0.5, 0.75)];
      case RunCollectWorld.spaceWorld:
        return [rgb(0.2, 0.2, 0.5), rgb(0.06, 0.06, 0.22)];
      case RunCollectWorld.oceanWorld:
        return [rgb(0.3, 0.7, 0.9), rgb(0.1, 0.4, 0.7)];
      case RunCollectWorld.dinosaurWorld:
        return [rgb(0.55, 0.7, 0.3), rgb(0.4, 0.52, 0.2)];
      case RunCollectWorld.magicKingdom:
        return [rgb(0.85, 0.6, 0.95), rgb(0.65, 0.4, 0.85)];
    }
  }

  static List<String> _worldDecorations(RunCollectWorld world) {
    switch (world) {
      case RunCollectWorld.enchantedForest:
        return const ['🌲', '🍄', '🦊', '✨'];
      case RunCollectWorld.colorfulCity:
        return const ['🏢', '🚕', '🎈', '🚦'];
      case RunCollectWorld.iceKingdom:
        return const ['⛄', '🐧', '❄️', '🏔️'];
      case RunCollectWorld.candyLand:
        return const ['🍭', '🍬', '🧁', '🍩'];
      case RunCollectWorld.spaceWorld:
        return const ['🪐', '⭐', '☄️', '👽'];
      case RunCollectWorld.oceanWorld:
        return const ['🐠', '🐙', '🐚', '🐳'];
      case RunCollectWorld.dinosaurWorld:
        return const ['🦕', '🌋', '🌿', '🥚'];
      case RunCollectWorld.magicKingdom:
        return const ['🏰', '🌈', '🐉', '✨'];
    }
  }
}
