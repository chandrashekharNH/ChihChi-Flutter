import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/ui_text.dart';
import '../../services/audio/audio_service.dart';
import '../../services/progress/progress_service.dart';
import '../onboarding/child_name_view.dart';
import 'avatar_appearance.dart';
import 'character_studio_view.dart';
import 'character_text.dart';
import 'character_view.dart';

enum _Step { name, offer, studio }

/// First launch: the name, then an optional character. "Maybe Later" is always right there and
/// leads straight into the game with ChihChi as the hero.
class FirstLaunchFlow extends StatefulWidget {
  const FirstLaunchFlow({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<FirstLaunchFlow> createState() => _FirstLaunchFlowState();
}

class _FirstLaunchFlowState extends State<FirstLaunchFlow> {
  _Step _step = _Step.name;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: switch (_step) {
        _Step.name => ChildNameView(key: const ValueKey('name'), onFinished: () => setState(() => _step = _Step.offer)),
        _Step.offer => CharacterOfferView(
            key: const ValueKey('offer'),
            onCreate: () => setState(() => _step = _Step.studio),
            onLater: widget.onFinished,
          ),
        _Step.studio => CharacterStudioView(
            key: const ValueKey('studio'),
            mode: StudioMode.onboarding,
            start: AvatarAppearance.randomLook(),
            onClose: widget.onFinished,
          ),
      },
    );
  }
}

/// "Great, Charvi! 🎉" — make a character, or play now.
class CharacterOfferView extends StatefulWidget {
  const CharacterOfferView({super.key, required this.onCreate, required this.onLater});
  final VoidCallback onCreate;
  final VoidCallback onLater;

  @override
  State<CharacterOfferView> createState() => _CharacterOfferViewState();
}

class _CharacterOfferViewState extends State<CharacterOfferView> {
  final _preview = AvatarAppearance.randomLook();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final language = appState.language;
    final name = context.watch<ProgressService>().progress.childName;
    Widget choice(String title, String subtitle, String icon, Color colour, VoidCallback onTap) => Semantics(
          button: true,
          child: GestureDetector(
            onTap: () {
              appState.audioService.playEffect(SoundEffect.buttonTap);
              onTap();
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(children: [
                Text(icon, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: kid(21, color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: kid(14, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
                  ]),
                ),
              ]),
            ),
          ),
        );
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [appState.theme.gradientTop, appState.theme.gradientBottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(children: [
                  Text(
                    name.isEmpty ? UIText.hiThere.resolve(language) : CharacterText.greatName(name).resolve(language),
                    textAlign: TextAlign.center,
                    style: kid(32, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 240,
                    child: ExcludeSemantics(
                      child: CharacterSceneView(appearance: _preview, animation: CharacterAnimation.wave, allowsTurning: false),
                    ),
                  ),
                  const SizedBox(height: 18),
                  choice(CharacterText.createMyCharacter.resolve(language), CharacterText.createSubtitle.resolve(language), '🎨',
                      Colors.green, widget.onCreate),
                  const SizedBox(height: 18),
                  choice(CharacterText.maybeLater.resolve(language), CharacterText.maybeLaterSubtitle.resolve(language), '🐼',
                      Colors.white.withValues(alpha: 0.25), widget.onLater),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
