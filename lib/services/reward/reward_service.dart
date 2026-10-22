import 'dart:math' as math;

import '../../core/localization/localized.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/game_engagement.dart';
import '../../domain/models/reward_type.dart';

class RewardService {
  const RewardService();

  List<RewardGrant> rewardsForCorrectAnswer(int streak) {
    final grants = [RewardGrant(type: RewardType.candy, amount: 1, reason: 'Correct answer')];
    switch (streak) {
      case 3:
        grants.add(RewardGrant(type: RewardType.star, amount: 1, reason: '3 in a row!'));
      case 5:
        grants.add(RewardGrant(type: RewardType.iceCream, amount: 1, reason: '5 in a row!'));
      case 10:
        grants.add(RewardGrant(type: RewardType.chocolate, amount: 1, reason: '10 in a row!'));
      default:
        if (streak > 0 && streak % 10 == 0) {
          grants.add(RewardGrant(type: RewardType.chocolate, amount: 1, reason: '$streak in a row!'));
        }
    }
    return grants;
  }

  /// While the child is "on fire" (three or more right in a row), every right answer earns an
  /// extra star.
  List<RewardGrant> rewardsForBoost(PlayBoost boost) =>
      boost.isOnFire ? [RewardGrant(type: RewardType.star, amount: 1, reason: 'On fire!')] : [];

  /// Finishing a boss level (every fifth) earns a bigger prize.
  List<RewardGrant> rewardsForBossLevel(int level) =>
      PlayBoost.isBossLevel(level) ? [RewardGrant(type: RewardType.star, amount: 3, reason: 'Boss level!')] : [];

  List<RewardGrant> rewardsForLevelCompletion(int level, double accuracy, int streak) {
    final grants = [RewardGrant(type: RewardType.iceCream, amount: 1, reason: 'Level $level complete!')];
    if (accuracy >= 0.9) {
      grants.add(RewardGrant(type: RewardType.star, amount: 3, reason: 'Excellent accuracy!'));
      grants.add(RewardGrant(type: RewardType.chocolate, amount: 1, reason: 'Perfect run!'));
    } else if (accuracy >= 0.7) {
      grants.add(RewardGrant(type: RewardType.star, amount: 2, reason: 'Great job!'));
    } else {
      grants.add(RewardGrant(type: RewardType.star, amount: 1, reason: 'Keep going!'));
    }
    return grants;
  }

  /// AR Explorer: the mission's stars, plus a treat on a streak of right answers.
  List<RewardGrant> rewardsForExplorerMission(int stars, int streak) {
    final grants = [RewardGrant(type: RewardType.star, amount: stars, reason: 'AR Explorer')];
    switch (streak) {
      case 3:
        grants.add(RewardGrant(type: RewardType.candy, amount: 1, reason: '3 discoveries in a row!'));
      case 5:
        grants.add(RewardGrant(type: RewardType.iceCream, amount: 1, reason: '5 discoveries in a row!'));
      case 10:
        grants.add(RewardGrant(type: RewardType.chocolate, amount: 1, reason: '10 discoveries in a row!'));
    }
    return grants;
  }

  /// Turbo Race: three stars per race star, a little extra for winning, and a treat for three stars.
  List<RewardGrant> rewardsForRace(int stars, int position) {
    final grants = [RewardGrant(type: RewardType.star, amount: stars * 3 + (position == 1 ? 2 : 0), reason: 'Turbo Race')];
    if (stars == 3) grants.add(RewardGrant(type: RewardType.candy, amount: 1, reason: 'Three-star race!'));
    return grants;
  }

  /// AR Explorer: a bonus for finishing a session with at least one discovery.
  List<RewardGrant> rewardsForExplorerSession(int completedMissions) =>
      completedMissions > 0 ? [RewardGrant(type: RewardType.star, amount: 5, reason: 'Explorer complete')] : [];

  int starsForAccuracy(double accuracy) => accuracy >= 0.9 ? 3 : (accuracy >= 0.7 ? 2 : 1);

  static final _random = math.Random();

  String celebrationMessage(int streak, AppLanguage language) {
    const messages = ['Amazing!', 'Fantastic!', 'Great Job!', 'Wonderful!', "You're a Star!", 'Brilliant!', 'Keep it up!', 'Super!', 'Excellent!'];
    final message = messages[_random.nextInt(messages.length)];
    return L(message, key: 'cheer.$message').resolve(language);
  }

  String encouragementMessage(AppLanguage language) {
    const messages = ['Try again!', 'Almost there!', 'You can do it!', "Let's try once more!", 'So close!'];
    final message = messages[_random.nextInt(messages.length)];
    return L(message, key: 'cheer.$message').resolve(language);
  }
}
