import 'dart:ui';

import '../../core/ui/palette.dart';

enum WorldID {
  enchantedForest('enchanted_forest', 0, 'Enchanted Forest'),
  magicKingdom('magic_kingdom', 10, 'Magic Kingdom'),
  spaceWorld('space_world', 20, 'Space World'),
  oceanWorld('ocean_world', 30, 'Ocean World'),
  dinosaurWorld('dinosaur_world', 40, 'Dinosaur World');

  const WorldID(this.rawValue, this.requiredLevel, this.displayName);
  final String rawValue;
  final int requiredLevel;
  final String displayName;

  static WorldID? fromRaw(String? raw) {
    for (final w in values) {
      if (w.rawValue == raw) return w;
    }
    return null;
  }
}

class WorldTheme {
  const WorldTheme({
    required this.id,
    required this.primaryColor,
    required this.secondaryColor,
    required this.cardColor,
    required this.accentColor,
    required this.gradientTop,
    required this.gradientBottom,
    required this.characterEmoji,
    required this.ambientEmojis,
    required this.sceneBGColor,
  });

  final WorldID id;
  final Color primaryColor;
  final Color secondaryColor;
  final Color cardColor;
  final Color accentColor;
  final Color gradientTop;
  final Color gradientBottom;
  final String characterEmoji;
  final List<String> ambientEmojis;
  final Color sceneBGColor;

  static final enchantedForest = WorldTheme(
    id: WorldID.enchantedForest,
    primaryColor: rgb(0.18, 0.65, 0.28),
    secondaryColor: rgb(0.42, 0.80, 0.42),
    cardColor: rgb(0.92, 0.99, 0.92),
    accentColor: rgb(1.0, 0.78, 0.0),
    gradientTop: rgb(0.15, 0.60, 0.22),
    gradientBottom: rgb(0.06, 0.32, 0.12),
    characterEmoji: '🧚',
    ambientEmojis: const ['🌳', '🍄', '🌸', '✨', '🦋'],
    sceneBGColor: rgb(0.12, 0.50, 0.20),
  );

  static final magicKingdom = WorldTheme(
    id: WorldID.magicKingdom,
    primaryColor: rgb(0.50, 0.18, 0.78),
    secondaryColor: rgb(0.68, 0.48, 0.88),
    cardColor: rgb(0.97, 0.94, 1.0),
    accentColor: rgb(1.0, 0.84, 0.0),
    gradientTop: rgb(0.38, 0.12, 0.68),
    gradientBottom: rgb(0.18, 0.05, 0.42),
    characterEmoji: '🧙',
    ambientEmojis: const ['🏰', '⭐', '🌟', '✨', '👑'],
    sceneBGColor: rgb(0.28, 0.08, 0.55),
  );

  static final spaceWorld = WorldTheme(
    id: WorldID.spaceWorld,
    primaryColor: rgb(0.12, 0.22, 0.62),
    secondaryColor: rgb(0.28, 0.42, 0.82),
    cardColor: rgb(0.90, 0.92, 1.0),
    accentColor: rgb(0.40, 0.82, 1.0),
    gradientTop: rgb(0.08, 0.10, 0.35),
    gradientBottom: rgb(0.02, 0.02, 0.18),
    characterEmoji: '👨‍🚀',
    ambientEmojis: const ['🚀', '🌙', '⭐', '🪐', '☄️'],
    sceneBGColor: rgb(0.05, 0.06, 0.28),
  );

  static final oceanWorld = WorldTheme(
    id: WorldID.oceanWorld,
    primaryColor: rgb(0.05, 0.42, 0.72),
    secondaryColor: rgb(0.22, 0.62, 0.88),
    cardColor: rgb(0.90, 0.96, 1.0),
    accentColor: rgb(0.0, 0.82, 0.82),
    gradientTop: rgb(0.05, 0.38, 0.68),
    gradientBottom: rgb(0.02, 0.18, 0.45),
    characterEmoji: '🐬',
    ambientEmojis: const ['🐠', '🐚', '🌊', '🪸', '🐡'],
    sceneBGColor: rgb(0.04, 0.28, 0.55),
  );

  static final dinosaurWorld = WorldTheme(
    id: WorldID.dinosaurWorld,
    primaryColor: rgb(0.55, 0.38, 0.12),
    secondaryColor: rgb(0.72, 0.58, 0.28),
    cardColor: rgb(0.99, 0.97, 0.90),
    accentColor: rgb(0.88, 0.52, 0.10),
    gradientTop: rgb(0.42, 0.58, 0.12),
    gradientBottom: rgb(0.22, 0.32, 0.06),
    characterEmoji: '🦕',
    ambientEmojis: const ['🦖', '🌋', '🌿', '🦴', '🥚'],
    sceneBGColor: rgb(0.30, 0.45, 0.10),
  );

  static WorldTheme theme(WorldID id) {
    switch (id) {
      case WorldID.enchantedForest:
        return enchantedForest;
      case WorldID.magicKingdom:
        return magicKingdom;
      case WorldID.spaceWorld:
        return spaceWorld;
      case WorldID.oceanWorld:
        return oceanWorld;
      case WorldID.dinosaurWorld:
        return dinosaurWorld;
    }
  }

  static List<WorldTheme> get all => [enchantedForest, magicKingdom, spaceWorld, oceanWorld, dinosaurWorld];
}
