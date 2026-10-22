enum ObjectCategory { fruit, animal, vehicle, shape, food, nature, toy }

class GameObject {
  const GameObject({required this.id, required this.emoji, required this.category, this.audioName});
  final String id;
  final String emoji;
  final ObjectCategory category;
  final String? audioName;

  @override
  bool operator ==(Object other) => other is GameObject && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
