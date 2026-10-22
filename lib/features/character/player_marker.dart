import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'character_view.dart';
import 'player_character_store.dart';

/// The child's face on maps and scoreboards: their character's portrait when they made one,
/// otherwise the usual emoji (ChihChi, a rocket, a puzzle piece…).
class PlayerMarker extends StatelessWidget {
  const PlayerMarker({super.key, required this.fallback, this.size = 52});
  final String fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlayerCharacterStore>();
    const shadow = [BoxShadow(color: Color(0x59000000), blurRadius: 4, offset: Offset(0, 3))];
    final portrait = store.portrait;
    if (store.isEnabled && portrait != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: shadow,
        ),
        child: ClipOval(child: Image.memory(portrait, fit: BoxFit.cover, gaplessPlayback: true)),
      );
    }
    return Text(fallback,
        style: TextStyle(fontSize: size * 0.88, shadows: const [Shadow(color: Color(0x59000000), blurRadius: 4, offset: Offset(0, 3))]));
  }
}

/// The child's own character in a corner of a game, cheering along: a celebration for each right
/// answer, a little sad shrug for a miss, and a winning spin when the level is done. Taps pass
/// straight through to the game. Shows nothing when the child plays as ChihChi.
class PlayerBuddy extends StatefulWidget {
  const PlayerBuddy({super.key, required this.correct, required this.mistakes, required this.isComplete});
  final int correct;
  final int mistakes;
  final bool isComplete;

  @override
  State<PlayerBuddy> createState() => _PlayerBuddyState();
}

class _PlayerBuddyState extends State<PlayerBuddy> {
  CharacterAnimation _animation = CharacterAnimation.wave;
  int _cue = 0;

  @override
  void didUpdateWidget(PlayerBuddy old) {
    super.didUpdateWidget(old);
    if (widget.correct > old.correct) _play(CharacterAnimation.celebrate);
    if (widget.mistakes > old.mistakes) _play(CharacterAnimation.sad);
    if (widget.isComplete && !old.isComplete) _play(CharacterAnimation.win);
  }

  void _play(CharacterAnimation next) {
    _animation = next;
    _cue += 1;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PlayerCharacterStore>();
    if (!store.isEnabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          width: 92,
          height: 112,
          child: CharacterSceneView(appearance: store.appearance, animation: _animation, cue: _cue, allowsTurning: false),
        ),
      ),
    );
  }
}

/// Places the child's cheering character in a bottom corner of a game screen (the other corner
/// from ChihChi, where ChihChi appears).
class PlayerBuddyOverlay extends StatelessWidget {
  const PlayerBuddyOverlay({
    super.key,
    required this.child,
    required this.correct,
    required this.mistakes,
    required this.isComplete,
    this.bottomInset = 24,
    this.alignment = AlignmentDirectional.bottomStart,
  });

  final Widget child;
  final int correct, mistakes;
  final bool isComplete;
  final double bottomInset;
  final AlignmentDirectional alignment;

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(child: child),
        Positioned.fill(
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: EdgeInsets.fromLTRB(6, 0, 6, bottomInset),
              child: PlayerBuddy(correct: correct, mistakes: mistakes, isComplete: isComplete),
            ),
          ),
        ),
      ]);
}
