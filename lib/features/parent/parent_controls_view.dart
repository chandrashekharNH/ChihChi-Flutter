import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/localization/localized.dart';
import '../../domain/models/app_language.dart';
import '../../services/audio/kids_speech_service.dart';
import '../../services/audio/kids_voice.dart';
import '../../services/progress/progress_service.dart';
import '../ar_explorer/ar_explorer_progress_store.dart';
import 'parent_components.dart';
import 'parent_text.dart';

/// Language, audio and game-experience controls. Each control changes the same saved setting and
/// service the games already read; nothing here is parent-only state.
class ParentControlsView extends StatefulWidget {
  const ParentControlsView({super.key});

  @override
  State<ParentControlsView> createState() => _ParentControlsViewState();
}

class _ParentControlsViewState extends State<ParentControlsView> with WidgetsBindingObserver {
  final _arExplorer = ARExplorerProgressStore();
  final _sample = KidsSpeechService();
  KidsVoiceCharacter _character = KidsVoice.character();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arExplorer.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().languageOrder.listShown());
  }

  /// Back from the phone's settings: a newly installed voice is used at once.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) KidsVoice.refreshInstalledVoices().then((_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sample.dispose();
    _arExplorer.dispose();
    super.dispose();
  }

  String _quality(int q, AppLanguage language) => switch (q) {
        3 => ParentText.voicePremium.resolve(language),
        2 => ParentText.voiceEnhanced.resolve(language),
        _ => ParentText.voiceBasic.resolve(language),
      };

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final progress = context.watch<ProgressService>();
    final language = appState.language;
    final audio = appState.audioService;
    final order = appState.languageOrder;
    final primary = Theme.of(context).colorScheme.primary;
    final voice = KidsVoice.installedBest(language, _character);
    final voiceFooter = voice == null
        ? ParentPlatformText.voiceMissing(language.displayName).resolve(language)
        : voice.quality > 1
            ? ParentPlatformText.voiceGood.resolve(language)
            : ParentPlatformText.voiceTip.resolve(language);

    Widget toggle(String title, bool value, ValueChanged<bool> onChanged) =>
        SwitchListTile.adaptive(title: Text(title), value: value, onChanged: onChanged);

    Widget voiceButton(KidsVoiceCharacter character) {
      final selected = _character == character;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            onTap: () {
              setState(() => _character = character);
              KidsVoice.setCharacter(character);
              _sample.speakSample(language);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? primary.withValues(alpha: 0.18) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? primary : Colors.transparent, width: 2),
              ),
              child: Column(children: [
                Text(character.emoji, style: const TextStyle(fontSize: 24)),
                Text(character.displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
    }

    return ParentPage(title: ParentText.parentControls.resolve(language), children: [
      ListenableBuilder(
        listenable: order,
        builder: (context, _) => ParentSection(
          header: ParentText.language.resolve(language),
          footer: [
            ParentText.languageFooter.resolve(language),
            if (language.needsNativeReview)
              L("This language's text is new and has not yet been checked by a native speaker. Some words may not be quite right.")
                  .resolve(language),
          ].join('\n\n'),
          children: [
            for (final option in order.languages)
              ListTile(
                title: Text(option.displayName),
                subtitle: option == language ? null : Text(option.nameLine.resolve(language)),
                trailing: option == language ? Icon(Icons.check, color: primary) : null,
                onTap: () {
                  appState.setLanguage(option);
                  progress.updateLanguage(option);
                },
              ),
          ],
        ),
      ),
      ParentSection(header: ParentText.audio.resolve(language), footer: ParentText.audioFooter.resolve(language), children: [
        toggle(ParentText.music.resolve(language), audio.musicEnabled, (v) {
          audio.musicEnabled = v;
          progress.setMusicEnabled(v);
        }),
        toggle(ParentText.soundEffects.resolve(language), audio.soundEnabled, (v) {
          audio.soundEnabled = v;
          progress.setSoundEnabled(v);
        }),
        toggle(ParentText.voice.resolve(language), audio.voiceEnabled, (v) {
          audio.voiceEnabled = v;
          progress.setVoiceEnabled(v);
        }),
        toggle(ParentText.vibration.resolve(language), progress.progress.hapticsEnabled, (v) {
          audio.hapticsEnabled = v;
          progress.setHapticsEnabled(v);
        }),
      ]),
      ParentSection(header: ParentText.speakingVoice.resolve(language), footer: voiceFooter, children: [
        for (final girls in [true, false])
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((girls ? ParentText.girlsVoices : ParentText.boysVoices).resolve(language),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryText(context))),
              const SizedBox(height: 8),
              Row(children: [
                for (final c in KidsVoiceCharacter.values.where((c) => c.isGirl == girls)) voiceButton(c),
              ]),
            ]),
          ),
        ListTile(
          title: Text(voice?.label ?? '—'),
          trailing: Text(_quality(voice?.quality ?? 1, language), style: TextStyle(color: secondaryText(context))),
        ),
        ListTile(
          leading: Icon(Icons.play_circle, color: primary),
          title: Text(ParentText.playSample.resolve(language), style: TextStyle(color: primary)),
          onTap: () => _sample.speakSample(language),
        ),
      ]),
      ParentSection(
        header: ParentText.gameExperience.resolve(language),
        footer: ParentText.reducePuzzleMotionFooter.resolve(language),
        children: [
          toggle(ParentText.reducePuzzleMotion.resolve(language), progress.progress.reducedMotion, progress.setReducedMotion),
        ],
      ),
      ParentSection(
        header: ParentText.arExplorer.resolve(language),
        footer: ParentPlatformText.arExplorerFooter.resolve(language),
        children: [
          toggle(ParentText.allowARExplorer.resolve(language), _arExplorer.progress.isAllowed, _arExplorer.setAllowed),
          toggle(ParentText.arVoiceGuidance.resolve(language), _arExplorer.progress.voiceGuidance, _arExplorer.setVoiceGuidance),
          toggle(ParentText.arHints.resolve(language), _arExplorer.progress.hintsEnabled, _arExplorer.setHintsEnabled),
          toggle(ParentText.arLanguageChallenge.resolve(language), _arExplorer.progress.languageChallenge,
              _arExplorer.setLanguageChallenge),
        ],
      ),
    ]);
  }
}
