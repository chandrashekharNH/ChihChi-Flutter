import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/ui_text.dart';
import '../../domain/models/world_theme.dart';
import '../../services/audio/audio_service.dart';
import '../../services/progress/progress_service.dart';
import '../common/breathing_background.dart';
import '../common/page_header.dart';
import '../common/readable_width.dart';

class ProgressView extends StatelessWidget {
  const ProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final p = context.watch<ProgressService>().progress;
    final language = appState.language;
    final theme = appState.theme;

    BoxDecoration cardDecoration() => BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8)],
        );

    final done = p.completedLevels.length;
    final profile = Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Row(children: [
        Text(theme.characterEmoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(UIText.level(p.highestUnlockedLevel - 1).resolve(language), style: kid(26, color: theme.primaryColor)),
            const SizedBox(height: 6),
            Text(UIText.world(theme.id).resolve(language),
                style: kid(15, weight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (done / 20).clamp(0, 1)),
                duration: const Duration(milliseconds: 500),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  color: theme.accentColor,
                  backgroundColor: Colors.black.withValues(alpha: 0.1),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(UIText.levelsComplete(done, 20).resolve(language),
                style: kid(12, weight: FontWeight.w500, color: Colors.black54)),
          ]),
        ),
      ]),
    );

    final currentLevel = p.highestUnlockedLevel - 1;
    final worlds = Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🗺 ${UIText.worldExploration.resolve(language)}',
            style: kid(18, weight: FontWeight.w700, color: theme.primaryColor)),
        const SizedBox(height: 14),
        for (final world in WorldTheme.all)
          () {
            final isUnlocked = currentLevel >= world.id.requiredLevel;
            return Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isUnlocked ? theme.primaryColor.withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Opacity(opacity: isUnlocked ? 1 : 0.4, child: Text(world.characterEmoji, style: const TextStyle(fontSize: 24))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(UIText.world(world.id).resolve(language),
                        style: kid(14, weight: FontWeight.w700, color: isUnlocked ? Colors.black87 : Colors.black45)),
                    Text(
                      isUnlocked
                          ? UIText.unlocked.resolve(language)
                          : UIText.reachLevel(world.id.requiredLevel).resolve(language),
                      style: kid(12, weight: FontWeight.w500, color: isUnlocked ? theme.primaryColor : Colors.black45),
                    ),
                  ]),
                ),
                isUnlocked
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.lock, color: Colors.black26),
              ]),
            );
          }(),
      ]),
    );

    Widget mini(String emoji, int count) => Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          Text('$count', style: kid(18, color: theme.primaryColor)),
        ]);

    final rewards = Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🏆 ${UIText.rewardCollection.resolve(language)}',
            style: kid(18, weight: FontWeight.w700, color: theme.primaryColor)),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          mini('⭐', p.stars),
          mini('🍭', p.candy),
          mini('🍦', p.iceCream),
          mini('🍫', p.chocolate),
        ]),
      ]),
    );

    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: BreathingBackground()),
        Column(children: [
          PageHeader(
            title: '📈 ${UIText.myProgress.resolve(language)}',
            onBack: () {
              appState.audioService.playEffect(SoundEffect.buttonTap);
              Navigator.of(context).pop();
            },
          ),
          Expanded(
            child: ListView(padding: readablePadding(context, horizontal: 20, top: 20, bottom: 20), children: [
              profile,
              const SizedBox(height: 20),
              worlds,
              const SizedBox(height: 20),
              rewards,
            ]),
          ),
        ]),
      ]),
    );
  }
}
