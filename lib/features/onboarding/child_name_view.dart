import 'package:flutter/material.dart';
import 'package:chihchi/core/ui/emoji_text.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/ui_text.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/child_name_voice.dart';
import '../../services/audio/kids_speech_service.dart';
import '../../services/progress/progress_service.dart';
import '../common/name_voice_record_button.dart';

/// Shown on first launch to ask the child's name. The child holds the microphone and says it (the
/// recording is played in games wherever the name is spoken), or types it instead.
class ChildNameView extends StatefulWidget {
  const ChildNameView({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<ChildNameView> createState() => _ChildNameViewState();
}

class _ChildNameViewState extends State<ChildNameView> with SingleTickerProviderStateMixin {
  static const _maxLength = 20;

  final _name = TextEditingController();
  final _focus = FocusNode();
  final _recorder = ChildNameVoiceRecorder();
  KidsSpeechService _speech = KidsSpeechService();
  late final AnimationController _wave =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  String? _greetedName;
  NameRecorderState _lastState = NameRecorderState.idle;

  String get _trimmed => _name.text.trim();
  bool get _hasVoice => _recorder.state == NameRecorderState.recorded;
  bool get _canContinue => _hasVoice || _trimmed.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _recorder.addListener(_recorderChanged);
    _name.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speech.speakAskName(context.read<AppState>().language);
    });
  }

  void _recorderChanged() {
    // Keep the app's own voice out of the child's recording.
    if (_recorder.state == NameRecorderState.recording && _lastState != NameRecorderState.recording) _speech.stop();
    _lastState = _recorder.state;
    setState(() {});
  }

  @override
  void dispose() {
    _recorder.stopEverything();
    _recorder.removeListener(_recorderChanged);
    _recorder.dispose();
    _speech.dispose();
    _wave.dispose();
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canContinue || _greetedName != null) return;
    final appState = context.read<AppState>();
    final progress = context.read<ProgressService>();
    appState.audioService.playEffect(SoundEffect.buttonTap);
    final hadVoice = _hasVoice;
    if (hadVoice) {
      try {
        await _recorder.saveDraft();
      } catch (_) {}
    }
    final childName = _trimmed;
    progress.saveChildProfile(childName);
    _focus.unfocus();
    setState(() => _greetedName = childName);

    // Let the greeting (with the child's own voice, if recorded) finish before closing.
    _speech.stop();
    _speech = KidsSpeechService(childName: childName);
    _speech.speakWelcome(appState.language);
    await Future<void>.delayed(Duration(milliseconds: hadVoice ? 4500 : 2800));
    if (mounted) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final language = appState.language;
    final theme = appState.theme;
    final greeted = _greetedName;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.gradientTop, theme.gradientBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(children: [
                  AnimatedBuilder(
                    animation: _wave,
                    builder: (context, child) => Transform.rotate(
                      angle: (-12 + 30 * _wave.value) * 3.14159 / 180,
                      alignment: Alignment.bottomRight,
                      child: child,
                    ),
                    child: const EmojiText('👋', size: 80),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
                    child: greeted != null
                        ? Text(
                            greeted.isEmpty ? UIText.hiThere.resolve(language) : UIText.hiName(greeted).resolve(language),
                            key: const ValueKey('greeting'),
                            textAlign: TextAlign.center,
                            style: kid(34, color: Colors.white),
                          )
                        : _form(language, theme.primaryColor),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(AppLanguage language, Color primary) {
    return Column(key: const ValueKey('form'), children: [
      Text(UIText.whatsYourName.resolve(language), textAlign: TextAlign.center, style: kid(28, color: Colors.white)),
      const SizedBox(height: 22),
      DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: NameVoiceRecordButton(
          recorder: _recorder,
          title: UIText.holdAndSayName.resolve(language),
          recordingTitle: UIText.listening.resolve(language),
          titleStyle: kid(17, color: Colors.white),
        ),
      ),
      if (_hasVoice) ...[
        const SizedBox(height: 22),
        Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
          _smallButton(UIText.hearIt.resolve(language), Icons.play_arrow, primary, _recorder.playDraft),
          _smallButton(UIText.sayItAgain.resolve(language), Icons.refresh, primary, _recorder.discardDraft),
        ]),
      ],
      if (_recorder.state == NameRecorderState.microphoneDenied) ...[
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
          child: Text(UIText.micOff.resolve(language),
              textAlign: TextAlign.center, style: kid(15, weight: FontWeight.w700, color: Colors.white)),
        ),
      ],
      const SizedBox(height: 22),
      Text(UIText.orTypeIt.resolve(language),
          style: kid(15, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85))),
      const SizedBox(height: 22),
      TextField(
        controller: _name,
        focusNode: _focus,
        maxLength: _maxLength,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.words,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        style: kid(24, weight: FontWeight.w700, color: Colors.black87),
        decoration: InputDecoration(
          counterText: '',
          hintText: UIText.yourName.resolve(language),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 22),
      Semantics(
        button: true,
        enabled: _canContinue,
        child: GestureDetector(
          onTap: _canContinue ? _save : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _canContinue ? Colors.green : Colors.grey.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Text(
              _hasVoice ? UIText.thatsMe.resolve(language) : UIText.letsPlay.resolve(language),
              textAlign: TextAlign.center,
              style: kid(22, color: Colors.white),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _smallButton(String title, IconData icon, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(title, style: kid(16, color: color)),
          ]),
        ),
      );
}
