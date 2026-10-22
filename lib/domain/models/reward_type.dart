import 'dart:math' as math;

enum RewardType {
  star('⭐', 'Star'),
  candy('🍭', 'Candy'),
  iceCream('🍦', 'Ice Cream'),
  chocolate('🍫', 'Chocolate'),
  mystery('🎁', 'Mystery Gift');

  const RewardType(this.emoji, this.name);
  final String emoji;
  final String name;
}

class RewardGrant {
  RewardGrant({required this.type, required this.amount, required this.reason})
      : id = '${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 30)}';
  final String id;
  final RewardType type;
  final int amount;
  final String reason;

  String get displayText => '${type.emoji} ${type.name} +$amount';

  @override
  bool operator ==(Object other) => other is RewardGrant && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
