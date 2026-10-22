import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/emoji_text.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/catch_letter_level.dart';
import '../../domain/models/catch_letter_strings.dart';
import '../../game/engine/game_scene.dart';
import '../../game/scenes/catch_letter_intro_scene.dart';
import '../../services/audio/fun_sound_player.dart';
import '../../services/audio/fun_sound_synth.dart';
import '../../services/audio/kids_speech_service.dart';
import '../../services/progress/progress_service.dart';

/// Plays a Catch Letter world's animated introduction (about 12–18 s) with narration. World 1 also
/// runs the LOOK → FIND → CATCH → REWARD tutorial.
class CatchLetterIntroView extends StatefulWidget {
  const CatchLetterIntroView({super.key, required this.batch, required this.onFinish});
  final CatchLetterBatch batch;
  final VoidCallback onFinish;

  @override
  State<CatchLetterIntroView> createState() => _CatchLetterIntroViewState();
}

class _CatchLetterIntroViewState extends State<CatchLetterIntroView> {
  late final CatchLetterIntroScene _scene = CatchLetterIntroScene(widget.batch);
  late KidsSpeechService _speech;
  final _sounds = FunSoundPlayer();
  String? _caption;
  int? _tutorialStep;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _speech = KidsSpeechService(
      childName: context.read<ProgressService>().progress.childName,
      isEnabled: () => appState.audioService.voiceEnabled,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _speech.dispose();
    _sounds.stop();
    _scene.disposeScene();
    super.dispose();
  }

  /// Waits; false if the intro was skipped or closed meanwhile.
  Future<bool> _wait(double seconds) async {
    await Future<void>.delayed(Duration(milliseconds: (seconds * 1000).round()));
    return mounted && !_finished;
  }

  void _play(FunSound sound) {
    if (context.read<AppState>().audioService.soundEnabled) _sounds.play(sound);
  }

  void _say(String line) {
    if (line.isEmpty) return;
    setState(() => _caption = line);
    _speech.speakLine(line, context.read<AppState>().language);
  }

  Future<void> _run() async {
    final language = context.read<AppState>().language;
    final lines = CatchLetterStrings.introNarration(widget.batch, language);
    // Wait for the scene to get its size.
    if (!await _wait(0.1)) return;
    _scene.enterChihChi();
    _play(FunSound.boing);
    if (!await _wait(1.6)) return;
    _scene.lookAround();
    if (!await _wait(1.1)) return;
    _say(lines.isEmpty ? '' : lines.first);
    _scene.revealWorld();
    _play(FunSound.whoosh);
    if (!await _wait(2.6)) return;
    _scene.showTitle(widget.batch.icon, CatchLetterStrings.batchTitle(widget.batch, language));
    _play(FunSound.tada);
    if (!await _wait(2.0)) return;
    if (widget.batch == CatchLetterBatch.firstAdventure && !await _tutorial()) return;
    if (lines.length > 1) _say(lines[1]);
    _scene.celebrate();
    _play(FunSound.giggle);
    if (!await _wait(3.0)) return;
    _finish();
  }

  /// ChihChi shows how to play: a letter appears, moves, and ChihChi catches it.
  Future<bool> _tutorial() async {
    final appState = context.read<AppState>();
    final language = appState.language;
    final lessons = appState.contentProvider.letterLessons;
    _scene.showFloatingLetter(lessons.isEmpty ? 'A' : lessons.first.symbol);
    _play(FunSound.pop);
    if (!await _wait(1.0)) return false;
    _scene.noticeLetter();
    if (!await _wait(1.0)) return false;
    _scene.moveLetter();
    if (!await _wait(1.5)) return false;
    _scene.catchLetter();
    if (!await _wait(0.5)) return false;
    _play(FunSound.pop);
    if (!await _wait(0.2)) return false;
    _play(FunSound.tada);
    if (!await _wait(1.4)) return false;
    setState(() => _caption = null);
    final steps = CatchLetterStrings.tutorialSteps(language);
    for (var i = 0; i < steps.length; i++) {
      setState(() => _tutorialStep = i);
      _speech.speakLine(steps[i].$2, language);
      if (!await _wait(1.1)) return false;
    }
    if (!await _wait(0.4)) return false;
    setState(() => _tutorialStep = null);
    return true;
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _speech.stop();
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final steps = CatchLetterStrings.tutorialSteps(language);
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: GameView(scene: _scene)),
        SafeArea(
          child: Column(children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: GestureDetector(
                  onTap: _finish,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(30)),
                    child: Text('${CatchLetterStrings.skip(language)} ⏭', style: kid(17, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _tutorialStep == null
                  ? const SizedBox.shrink()
                  : Padding(
                      key: const ValueKey('steps'),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        for (var i = 0; i < steps.length; i++)
                          Expanded(
                            child: SizedBox(
                              child: Opacity(
                                opacity: i <= _tutorialStep! ? 1 : 0.5,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: i == _tutorialStep ? Colors.orange : Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(children: [
                                    EmojiText(steps[i].$1, size: i == _tutorialStep ? 40 : 28),
                                    FittedBox(child: Text(steps[i].$2, style: kid(14, color: Colors.white))),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, a) => SlideTransition(
                position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: _caption == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(_caption),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(22)),
                      child: Text(_caption!, textAlign: TextAlign.center, style: kid(24, color: Colors.white)),
                    ),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ]),
    );
  }
}
