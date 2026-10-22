import 'dart:math' as math;

import '../../data/game_content/run_collect_content.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/catch_letter_level.dart';
import '../../domain/models/catch_letter_strings.dart';
import '../../domain/models/run_collect.dart';
import 'turbo_race_content.dart';
import 'turbo_race_text.dart';

/// What is painted on a gate choice.
sealed class TurboGateFace {
  const TurboGateFace();
}

class GateText extends TurboGateFace {
  const GateText(this.text);
  final String text;
}

class GateColor extends TurboGateFace {
  const GateColor(this.color);
  final CatchLetterColor color;
}

class GateShape extends TurboGateFace {
  const GateShape(this.shape);
  final CatchLetterShape shape;
}

/// One choice on a learning gate.
class TurboGateOption {
  const TurboGateOption(this.face, this.spokenName);
  final TurboGateFace face;

  /// How ChihChi names this choice out loud ("B", "blue", "3", "star").
  final String spokenName;
}

sealed class TurboQuestion {
  const TurboQuestion();
}

class FindSymbol extends TurboQuestion {
  const FindSymbol(this.symbol);
  final String symbol;
}

class LetterStarting extends TurboQuestion {
  const LetterStarting(this.word, this.emoji);
  final String word, emoji;
}

class ColorQuestion extends TurboQuestion {
  const ColorQuestion(this.color);
  final CatchLetterColor color;
}

class ShapeQuestion extends TurboQuestion {
  const ShapeQuestion(this.shape);
  final CatchLetterShape shape;
}

/// A learning gate: a question asked just before the gate and the choices across the road.
class TurboChallenge {
  const TurboChallenge(this.question, this.options, this.correctIndex);
  final TurboQuestion question;
  final List<TurboGateOption> options;
  final int correctIndex;

  TurboGateOption get answer => options[correctIndex];

  /// The small banner on the HUD while the gate is coming up.
  String banner(AppLanguage language) => switch (question) {
        FindSymbol(:final symbol) => TurboRaceText.findBanner(symbol).resolve(language),
        LetterStarting(:final word, :final emoji) => TurboRaceText.startsBanner(emoji, word).resolve(language),
        ColorQuestion(:final color) => TurboRaceText.colorBanner(color.swatch, answer.spokenName).resolve(language),
        ShapeQuestion(:final shape) => TurboRaceText.shapeBanner(shape.icon, answer.spokenName).resolve(language),
      };

  /// What ChihChi says as the gate comes into view.
  String spokenPrompt(AppLanguage language) => switch (question) {
        FindSymbol(:final symbol) => TurboRaceText.sayFind(symbol).resolve(language),
        LetterStarting(:final word) => TurboRaceText.sayWhichLetterStarts(word).resolve(language),
        ColorQuestion() => TurboRaceText.sayColorGate(answer.spokenName).resolve(language),
        ShapeQuestion() => TurboRaceText.sayShapeGate(answer.spokenName).resolve(language),
      };

  /// After a wrong gate: name the right answer kindly, then move on.
  String teachingLine(int chosen, AppLanguage language) {
    final q = question;
    if (q is LetterStarting) return TurboRaceText.sayStartsWith(q.word, answer.spokenName).resolve(language);
    final picked = chosen >= 0 && chosen < options.length ? options[chosen].spokenName : '';
    return TurboRaceText.sayWeNeeded(picked, answer.spokenName).resolve(language);
  }
}

/// Makes learning-gate questions for a race. Pure logic, so it is easy to test.
class TurboChallengeMaker {
  TurboChallengeMaker(this.kind, this.choices, this.language, [math.Random? random]) : _random = random ?? math.Random();
  final TurboChallengeKind kind;
  final int choices;
  final AppLanguage language;
  final math.Random _random;

  /// Beginner letters first; "Which letter starts…?" only in mixed races.
  TurboChallenge challenge(int gateIndex) {
    switch (kind) {
      case TurboChallengeKind.letters:
        return _letter();
      case TurboChallengeKind.colors:
        return _color();
      case TurboChallengeKind.numbers:
        return _number(5);
      case TurboChallengeKind.shapes:
        return _shape();
      case TurboChallengeKind.mixed:
        return switch (gateIndex % 5) {
          0 => _letter(),
          1 => _color(),
          2 => _number(9),
          3 => _shape(),
          _ => _startingLetter(),
        };
    }
  }

  List<RunCollectTarget> get _letters =>
      RunCollectContent.targets(language, RunCollectTargetMode.letter).where((t) => t.difficulty == 1).toList();

  TurboChallenge _letter() {
    // Early races stay with the first letters of the alphabet.
    final picked = _pick(choices, _letters.take(8).toList());
    final options = [for (final t in picked) TurboGateOption(GateText(t.localizedSymbol(language)), t.localizedSymbol(language))];
    final correct = _index(options.length);
    return TurboChallenge(FindSymbol(options[correct].spokenName), options, correct);
  }

  TurboChallenge _startingLetter() {
    final picked = _pick(choices, _letters);
    final options = [for (final t in picked) TurboGateOption(GateText(t.localizedSymbol(language)), t.localizedSymbol(language))];
    final correct = _index(options.length);
    final word = picked[correct];
    return TurboChallenge(LetterStarting(word.localizedName(language), word.emoji), options, correct);
  }

  TurboChallenge _color() {
    final picked = _pick(choices, CatchLetterColor.values);
    final options = [for (final c in picked) TurboGateOption(GateColor(c), CatchLetterStrings.colorName(c, language))];
    final correct = _index(options.length);
    return TurboChallenge(ColorQuestion(picked[correct]), options, correct);
  }

  TurboChallenge _number(int highest) {
    final picked = _pick(choices, [for (var i = 1; i <= highest; i++) i]);
    final options = [for (final n in picked) TurboGateOption(GateText('$n'), '$n')];
    final correct = _index(options.length);
    return TurboChallenge(FindSymbol(options[correct].spokenName), options, correct);
  }

  TurboChallenge _shape() {
    final picked = _pick(choices, CatchLetterShape.values);
    final options = [for (final s in picked) TurboGateOption(GateShape(s), CatchLetterStrings.shapeName(s, language))];
    final correct = _index(options.length);
    return TurboChallenge(ShapeQuestion(picked[correct]), options, correct);
  }

  /// `count` different items in a random order.
  List<T> _pick<T>(int count, List<T> pool) {
    final remaining = [...pool];
    final picked = <T>[];
    while (picked.length < math.min(count, pool.length) && remaining.isNotEmpty) {
      picked.add(remaining.removeAt(_index(remaining.length)));
    }
    return picked;
  }

  int _index(int count) => _random.nextInt(math.max(1, count));
}
