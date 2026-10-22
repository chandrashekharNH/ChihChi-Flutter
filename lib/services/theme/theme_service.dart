import '../../domain/models/world_theme.dart';

class ThemeService {
  ThemeService([WorldID worldID = WorldID.enchantedForest]) : currentTheme = WorldTheme.theme(worldID);

  WorldTheme currentTheme;

  void setWorld(WorldID worldID) => currentTheme = WorldTheme.theme(worldID);

  List<(WorldTheme theme, bool isUnlocked)> availableWorlds(int unlockedUpToLevel) =>
      [for (final theme in WorldTheme.all) (theme, unlockedUpToLevel >= theme.id.requiredLevel)];
}
