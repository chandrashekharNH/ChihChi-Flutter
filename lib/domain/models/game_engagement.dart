/// The little extras that keep a level exciting, shared by Catch Letter, Catch World and Learn
/// Blaster: three right in a row sets the child "on fire" (bonus stars for every answer while it
/// lasts), five in a row earns a slow-motion power-up, and every fifth level is a boss level.
class PlayBoost {
  static const fireStreak = 3;
  static const slowMotionStreak = 5;
  static const maximumCharges = 2;

  /// How long one slow-motion lasts, and how slow everything moves meanwhile.
  static const double slowMotionSeconds = 6;
  static const double slowMotionFactor = 0.45;

  int _streak = 0;
  int _slowMotionCharges = 0;

  int get streak => _streak;
  int get slowMotionCharges => _slowMotionCharges;
  bool get isOnFire => _streak >= fireStreak;

  /// A right answer. Returns true when it earned a slow-motion power-up.
  bool correct() {
    _streak += 1;
    if (_streak % slowMotionStreak != 0 || _slowMotionCharges >= maximumCharges) return false;
    _slowMotionCharges += 1;
    return true;
  }

  /// A wrong answer ends the streak; power-ups already earned are kept.
  void wrong() => _streak = 0;

  /// Spends one power-up. False when there is none.
  bool useSlowMotion() {
    if (_slowMotionCharges <= 0) return false;
    _slowMotionCharges -= 1;
    return true;
  }

  static bool isBossLevel(int level) => level > 0 && level % 5 == 0;
}
