import 'package:chihchi/core/store/premium_access.dart';
import 'package:chihchi/domain/models/home_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first 10 levels of every game are free', () {
    for (final game in HomeGame.values) {
      expect(PremiumAccess.allows(game, 10, EntitlementState.free), isTrue);
      expect(PremiumAccess.allows(game, 11, EntitlementState.free), isFalse);
      expect(PremiumAccess.allows(game, 11, EntitlementState.premium), isTrue);
      expect(PremiumAccess.allows(game, 11, EntitlementState.checking), isFalse);
    }
  });
}
