import 'dart:math' as math;

import 'package:chihchi/core/ui/emoji_text.dart';
import 'package:flutter/material.dart';

import '../../core/ui/kid_text.dart';
import '../../domain/models/app_language.dart';
import '../../domain/models/reward_type.dart';
import '../../domain/models/ui_text.dart';
import '../../domain/models/world_theme.dart';

/// A dark rounded card that springs in, used for game messages.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.child, this.opacity = 0.55, this.padding = 28});
  final Widget child;
  final double opacity;
  final double padding;

  @override
  Widget build(BuildContext context) => SpringIn(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: opacity), borderRadius: BorderRadius.circular(24)),
          child: child,
        ),
      );
}

/// Scales a child in from a little smaller with a springy overshoot.
class SpringIn extends StatelessWidget {
  const SpringIn({super.key, required this.child, this.from = 0.85});
  final Widget child;
  final double from;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: from, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Opacity(
            opacity: ((v - from) / (1 - from)).clamp(0, 1),
            child: Transform.translate(offset: Offset(0, 24 * (1 - v) / (1 - from)), child: child)),
        child: child,
      );
}

/// Party-popper emojis that burst out around a correct answer.
class PartyPopperCelebration extends StatelessWidget {
  const PartyPopperCelebration({super.key});

  static const _particles = [
    ('🎉', -90.0, -35.0), ('🎊', 85.0, -45.0), ('⭐', -110.0, 35.0), ('🍭', 105.0, 25.0),
    ('🍦', -55.0, 70.0), ('🍫', 65.0, 65.0), ('✨', 0.0, -75.0), ('🎈', 125.0, -5.0),
  ];

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, v, _) => Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            for (var i = 0; i < _particles.length; i++)
              Transform.translate(
                offset: Offset(_particles[i].$2 * v, 15 + (_particles[i].$3 - 15) * v),
                child: Transform.rotate(
                  angle: v * i * 35 * math.pi / 180,
                  child: Opacity(
                    opacity: v.clamp(0, 1),
                    child: Transform.scale(
                      scale: 0.35 + 0.65 * v,
                      child: EmojiText(_particles[i].$1, size: i.isEven ? 28 : 24),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
}

/// "🎉 Amazing! +1 🍭" after a right answer.
class CorrectOverlay extends StatelessWidget {
  const CorrectOverlay({super.key, required this.message, required this.grants});
  final String message;
  final List<RewardGrant> grants;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Center(
          child: Stack(alignment: Alignment.center, children: [
            const Positioned(top: -12, child: PartyPopperCelebration()),
            GameCard(
              opacity: 0.6,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🎉', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 14),
                Text(message, textAlign: TextAlign.center, style: kid(28, color: Colors.yellow)),
                for (final g in grants) Text(g.displayText, style: kid(20, weight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ]),
        ),
      );
}

/// "🐥❓ Oops! Try again!" after a miss with nothing to name.
class OopsOverlay extends StatelessWidget {
  const OopsOverlay({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Center(
          child: GameCard(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🐥❓', style: TextStyle(fontSize: 50)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: kid(24, weight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      );
}

/// The pause screen: resume or leave the game.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.language, required this.color, required this.onResume, required this.onExit});
  final AppLanguage language;
  final Color color;
  final VoidCallback onResume;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.65),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('⏸ ${UIText.paused.resolve(language)}', style: kid(28, color: Colors.white)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onResume,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(40)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.play_arrow, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(UIText.resume.resolve(language), style: kid(18, weight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.home, color: Colors.white70),
                label: Text(UIText.exitGame.resolve(language), style: kid(16, weight: FontWeight.w600, color: Colors.white70)),
              ),
            ]),
          ),
        ),
      );
}

/// Rewards of a level added up by kind.
List<(RewardType, int)> aggregatedRewards(List<RewardGrant> grants) {
  final totals = <RewardType, int>{};
  for (final g in grants) {
    totals[g.type] = (totals[g.type] ?? 0) + g.amount;
  }
  return [
    for (final t in RewardType.values)
      if ((totals[t] ?? 0) > 0) (t, totals[t]!),
  ];
}

/// The level-complete card: stars, numbers, rewards and Continue.
class LevelCompleteOverlay extends StatelessWidget {
  const LevelCompleteOverlay({
    super.key,
    required this.language,
    required this.theme,
    required this.stars,
    required this.lines,
    required this.rewards,
    required this.onContinue,
    this.extra,
    this.title,
  });

  final AppLanguage language;
  final WorldTheme theme;
  final int stars;
  final List<String> lines;
  final List<RewardGrant> rewards;
  final VoidCallback onContinue;
  final Widget? extra;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final totals = aggregatedRewards(rewards);
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.7),
        child: Center(
          child: SingleChildScrollView(
            child: SpringIn(
              from: 0.88,
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [theme.gradientTop, theme.gradientBottom], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const _Bounce(child: EmojiText('🎉', size: 60)),
                  const SizedBox(height: 20),
                  Text(title ?? UIText.levelComplete.resolve(language), textAlign: TextAlign.center, style: kid(32, color: Colors.yellow)),
                  const SizedBox(height: 20),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Opacity(opacity: i < stars ? 1 : 0.3, child: Text('⭐', style: TextStyle(fontSize: i < stars ? 40 : 28))),
                      ),
                  ]),
                  for (final line in lines) ...[
                    const SizedBox(height: 10),
                    Text(line, textAlign: TextAlign.center, style: kid(16, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
                  ],
                  if (extra != null) ...[const SizedBox(height: 16), extra!],
                  if (totals.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                      child: Column(children: [
                        for (final (type, amount) in totals)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text('${type.emoji} ${UIText.rewardName(type).resolve(language)} +$amount',
                                style: kid(18, weight: FontWeight.w700, color: Colors.white)),
                          ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: onContinue,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.yellow,
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4)],
                      ),
                      child: Text('${UIText.continueButton.resolve(language)} ▶', style: kid(20, color: theme.gradientBottom)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bounce extends StatefulWidget {
  const _Bounce({required this.child});
  final Widget child;

  @override
  State<_Bounce> createState() => _BounceState();
}

class _BounceState extends State<_Bounce> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
    ..repeat(reverse: true);
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.dismissed && ++_count >= 3) _c.stop();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: Tween(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)), child: widget.child);
}

/// The countdown bar at the bottom of a timed game.
class TimerBar extends StatelessWidget {
  const TimerBar({super.key, required this.remaining, required this.limit});
  final double remaining, limit;

  @override
  Widget build(BuildContext context) {
    final ratio = (remaining / limit).clamp(0.0, 1.0);
    final color = ratio > 0.5 ? Colors.green : (ratio > 0.25 ? Colors.yellow : Colors.red);
    return IgnorePointer(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: ratio, minHeight: 8, color: color, backgroundColor: Colors.white.withValues(alpha: 0.2)),
        ),
        const SizedBox(height: 4),
        Text('⏱ ${remaining.round()}', style: kid(13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
      ]),
    );
  }
}

/// A small dark capsule for HUD numbers.
class HudChip extends StatelessWidget {
  const HudChip({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(30)),
        child: child,
      );
}
