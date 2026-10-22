import 'reward_type.dart';

/// Where a catch game is. Mirrors the iOS `GameState` enum.
sealed class GameState {
  const GameState();
  bool get isActive => this is GamePlaying;
}

class GameLoading extends GameState { const GameLoading(); }
class GameReady extends GameState { const GameReady(); }
class GameInstruction extends GameState { const GameInstruction(); }
class GamePlaying extends GameState { const GamePlaying(); }
class GamePaused extends GameState { const GamePaused(); }
class GameAnswerWrong extends GameState { const GameAnswerWrong(); }
class GameOver extends GameState { const GameOver(); }

class GameAnswerCorrect extends GameState {
  const GameAnswerCorrect(this.objectName);
  final String objectName;
  @override
  bool operator ==(Object other) => other is GameAnswerCorrect && other.objectName == objectName;
  @override
  int get hashCode => objectName.hashCode;
}

class GameLevelCompleted extends GameState {
  const GameLevelCompleted(this.stars, this.rewards);
  final int stars;
  final List<RewardGrant> rewards;
  @override
  bool operator ==(Object other) => other is GameLevelCompleted && other.stars == stars;
  @override
  int get hashCode => stars.hashCode;
}
