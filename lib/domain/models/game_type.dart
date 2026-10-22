enum GameType {
  catchAndLearn('catch_and_learn', '🍎', 0),
  learnBlaster3D('learn_blaster_3d', '🚀', 0),
  arHunt('ar_hunt', '🌎', 0),
  memoryMagic('memory_magic', '🧠', 3),
  colorQuest('color_quest', '🎨', 5),
  numberWorld('number_world', '🔢', 5),
  shapeAdventure('shape_adventure', '⭐', 8),
  animalSafari('animal_safari', '🦁', 8),
  wordBuilder('word_builder', '📝', 10),
  buildPicture('build_picture', '🧩', 0);

  const GameType(this.rawValue, this.icon, this.requiredLevel);
  final String rawValue;
  final String icon;
  final int requiredLevel;
}
