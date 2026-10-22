import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/localization/localized.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/ui_text.dart';
import '../../domain/models/world_theme.dart';
import '../../services/audio/audio_service.dart';
import '../../services/progress/progress_service.dart';
import '../common/breathing_background.dart';
import '../common/page_header.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final progress = context.watch<ProgressService>();
    final theme = appState.theme;
    final language = appState.language;
    final order = appState.languageOrder;
    final audio = appState.audioService;

    Widget languageSection() => SettingsCard(
          title: UIText.language.resolve(language),
          color: theme.primaryColor,
          cardColor: theme.cardColor,
          child: ListenableBuilder(
            listenable: order,
            builder: (context, _) => Column(children: [
              for (final l in order.languages)
                _Row(
                  selected: l == language,
                  color: theme.primaryColor,
                  onTap: () {
                    audio.playEffect(SoundEffect.buttonTap);
                    appState.setLanguage(l);
                    progress.updateLanguage(l);
                  },
                  leading: Text(l.flag, style: const TextStyle(fontSize: 22)),
                  title: l.displayName,
                  subtitle: order.suggested.contains(l) ? L('Suggested for you').resolve(language) : null,
                ),
            ]),
          ),
        );

    Widget worldSection() => SettingsCard(
          title: UIText.worldTheme.resolve(language),
          color: theme.primaryColor,
          cardColor: theme.cardColor,
          child: Column(children: [
            for (final world in WorldTheme.all)
              () {
                final isUnlocked = progress.progress.highestUnlockedLevel > world.id.requiredLevel;
                return _Row(
                  selected: theme.id == world.id,
                  color: theme.primaryColor,
                  enabled: isUnlocked,
                  onTap: () {
                    audio.playEffect(SoundEffect.buttonTap);
                    appState.setWorld(world.id);
                    progress.updateWorld(world.id);
                  },
                  leading: Text(world.characterEmoji, style: const TextStyle(fontSize: 22)),
                  title: UIText.world(world.id).resolve(language),
                  badge: isUnlocked ? null : 'Lv.${world.id.requiredLevel}',
                );
              }(),
          ]),
        );

    Widget toggle(String label, bool value, ValueChanged<bool> onChanged) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: kid(16, weight: FontWeight.w500, color: Colors.black87))),
            Switch.adaptive(value: value, activeTrackColor: theme.primaryColor, onChanged: onChanged),
          ]),
        );

    Widget audioSection() => SettingsCard(
          title: UIText.audio.resolve(language),
          color: theme.primaryColor,
          cardColor: theme.cardColor,
          child: Column(children: [
            toggle(UIText.music.resolve(language), audio.musicEnabled, (v) {
              audio.musicEnabled = v;
              progress.setMusicEnabled(v);
            }),
            const Divider(height: 1),
            toggle(UIText.soundEffects.resolve(language), audio.soundEnabled, (v) {
              audio.soundEnabled = v;
              progress.setSoundEnabled(v);
            }),
            const Divider(height: 1),
            toggle(UIText.voice.resolve(language), audio.voiceEnabled, (v) {
              audio.voiceEnabled = v;
              progress.setVoiceEnabled(v);
            }),
            const Divider(height: 1),
            toggle(UIText.haptics.resolve(language), progress.progress.hapticsEnabled, (v) {
              audio.hapticsEnabled = v;
              progress.setHapticsEnabled(v);
            }),
          ]),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) => order.listShown());
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: BreathingBackground()),
        Column(children: [
          PageHeader(
            title: UIText.settings.resolve(language),
            onBack: () {
              audio.playEffect(SoundEffect.buttonTap);
              Navigator.of(context).pop();
            },
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(20), children: [
              languageSection(),
              const SizedBox(height: 16),
              worldSection(),
              const SizedBox(height: 16),
              audioSection(),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.leading,
    required this.title,
    this.subtitle,
    this.badge,
    this.enabled = true,
  });

  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String? subtitle;
  final String? badge;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(title,
                        style: kid(16, weight: FontWeight.w600, color: enabled ? Colors.black87 : Colors.black38)),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration:
                          BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
                      child: Text(badge!, style: kid(12, weight: FontWeight.w500, color: Colors.black45)),
                    ),
                  ],
                ]),
                if (subtitle != null) Text(subtitle!, style: kid(12, weight: FontWeight.w500, color: Colors.black45)),
              ]),
            ),
            if (selected)
              Icon(Icons.check_circle, color: color, size: 20)
            else if (!enabled)
              const Icon(Icons.lock, color: Colors.black38, size: 16),
          ]),
        ),
      ),
    );
  }
}
