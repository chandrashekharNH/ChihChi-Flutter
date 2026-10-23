import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/kid_text.dart';
import '../../core/ui/palette.dart';
import '../../domain/models/ui_text.dart';
import '../../services/audio/audio_service.dart';
import '../../services/progress/progress_service.dart';
import '../common/breathing_background.dart';
import '../common/page_header.dart';

class RewardsView extends StatelessWidget {
  const RewardsView({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final p = context.watch<ProgressService>().progress;
    final language = appState.language;
    final theme = appState.theme;

    Widget card(String emoji, String name, int count, Color color, Color background) => Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          // Shrinks to fit small screens and large text instead of overflowing the tile.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(emoji, style: const TextStyle(fontSize: 50)),
              const SizedBox(height: 10),
              Text('$count', style: kid(36, color: color)),
              const SizedBox(height: 10),
              Text(name, style: kid(15, weight: FontWeight.w600, color: Colors.black54)),
            ]),
          ),
        );

    Widget stat(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(children: [
            Expanded(child: Text(label, style: kid(15, weight: FontWeight.w500, color: Colors.black54))),
            Text(value, style: kid(15, weight: FontWeight.w700, color: theme.primaryColor)),
          ]),
        );

    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: BreathingBackground()),
        Column(children: [
          PageHeader(
            title: '🎁 ${UIText.myRewards.resolve(language)}',
            onBack: () {
              appState.audioService.playEffect(SoundEffect.buttonTap);
              Navigator.of(context).pop();
            },
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(20), children: [
              GridView.count(
                // Four across on tablets so the tiles stay a sensible size.
                crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.95,
                children: [
                  card('⭐', UIText.stars.resolve(language), p.stars, Colors.amber, rgb(1, 0.95, 0.7)),
                  card('🍭', UIText.candy.resolve(language), p.candy, rgb(0.9, 0.3, 0.5), rgb(1, 0.9, 0.93)),
                  card('🍦', UIText.iceCream.resolve(language), p.iceCream, rgb(0.95, 0.55, 0.2), rgb(1, 0.95, 0.88)),
                  card('🍫', UIText.chocolate.resolve(language), p.chocolate, rgb(0.55, 0.28, 0.1), rgb(0.96, 0.88, 0.78)),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('📊 ${UIText.myProgress.resolve(language)}',
                      style: kid(18, weight: FontWeight.w700, color: theme.primaryColor)),
                  stat(UIText.levelReached.resolve(language), '${p.highestUnlockedLevel - 1}'),
                  stat(UIText.correctAnswers.resolve(language), '${p.totalCorrectAnswers}'),
                  stat(UIText.bestStreak.resolve(language), '🔥 ${p.bestStreak}'),
                  stat(UIText.accuracy.resolve(language), '${(p.accuracy * 100).round()}%'),
                ]),
              ),
            ]),
          ),
        ]),
      ]),
    );
  }
}
