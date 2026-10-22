import 'package:flutter/material.dart';

import '../../core/ui/kid_text.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/ui_text.dart';

class WrongCatchLabel {
  const WrongCatchLabel(this.symbol, this.name);

  /// Shown large: an emoji, a letter or a colour swatch.
  final String symbol;

  /// Said and shown under the symbol; empty for decoys that have no name.
  final String name;

  @override
  bool operator ==(Object other) => other is WrongCatchLabel && other.symbol == symbol && other.name == name;
  @override
  int get hashCode => Object.hash(symbol, name);
}

/// What the child caught by mistake and what they were looking for, so a wrong catch still
/// teaches: "🐶 Dog! We're looking for 🍎 Apple."
class WrongCatchNote {
  const WrongCatchNote(this.caught, this.target);
  final WrongCatchLabel caught;
  final WrongCatchLabel target;

  String spokenLine(AppLanguage language) {
    final lookingFor = '${UIText.lookingFor.resolve(language)} ${target.name}';
    return caught.name.isEmpty ? lookingFor : '${caught.name}! $lookingFor';
  }

  @override
  bool operator ==(Object other) => other is WrongCatchNote && other.caught == caught && other.target == target;
  @override
  int get hashCode => Object.hash(caught, target);
}

/// The feedback card for a wrong catch, shared by the catch games.
class WrongCatchCard extends StatelessWidget {
  const WrongCatchCard({super.key, required this.note, required this.language});
  final WrongCatchNote note;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        label: note.spokenLine(language),
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(24)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _label(note.caught, 54, true, Colors.white),
              const SizedBox(height: 12),
              Text(UIText.lookingFor.resolve(language),
                  style: kid(16, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85))),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.yellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.yellow.withValues(alpha: 0.7), width: 2),
                ),
                child: _label(note.target, 40, false, Colors.yellow),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  /// The symbol, with its name beside it when the name adds something (not for a plain letter).
  Widget _label(WrongCatchLabel label, double size, bool exclaim, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label.symbol, style: kid(size, color: color)),
      if (label.name.isNotEmpty && label.name != label.symbol) ...[
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            _capitalizingFirst(label.name) + (exclaim ? '!' : ''),
            maxLines: 2,
            style: kid(size * 0.5, color: color),
          ),
        ),
      ],
    ]);
  }

  static String _capitalizingFirst(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
