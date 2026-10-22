import 'dart:async';

import 'package:chihchi/core/ui/emoji_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/localization/localized.dart';
import '../../core/ui/kid_text.dart';
import '../../core/ui/palette.dart';
import '../../domain/models/game_engagement.dart';

/// Shows a game's streak and power-ups at the side of the screen: a flame while the child is on
/// fire, a snowflake button when a slow-motion has been earned, a frosty tint while it runs, and a
/// crown banner at the start of every boss level.
class PlayBoostHUD extends StatefulWidget {
  const PlayBoostHUD({
    super.key,
    required this.child,
    required this.boost,
    required this.isSlowMotion,
    required this.level,
    required this.onSlowMotion,
  });

  final Widget child;
  final PlayBoost boost;
  final bool isSlowMotion;
  final int level;
  final VoidCallback onSlowMotion;

  @override
  State<PlayBoostHUD> createState() => _PlayBoostHUDState();
}

class _PlayBoostHUDState extends State<PlayBoostHUD> with SingleTickerProviderStateMixin {
  bool _showsBossBanner = false;
  Timer? _bannerTimer;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    _scheduleBanner();
  }

  @override
  void didUpdateWidget(PlayBoostHUD old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level) _scheduleBanner();
  }

  void _scheduleBanner() {
    _bannerTimer?.cancel();
    if (!PlayBoost.isBossLevel(widget.level)) return;
    _showsBossBanner = true;
    _bannerTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _showsBossBanner = false);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final boost = widget.boost;
    final hasCharge = !widget.isSlowMotion && boost.slowMotionCharges > 0;
    if (hasCharge && !reduceMotion) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
    return Stack(children: [
      Positioned.fill(child: widget.child),
      if (widget.isSlowMotion)
        Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Colors.cyan.withValues(alpha: 0.14)))),
      Positioned.directional(
        textDirection: Directionality.of(context),
        end: 8,
        top: 0,
        bottom: 0,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (boost.isOnFire)
              Semantics(
                label: L('On fire! Bonus stars').resolve(language),
                child: IgnorePointer(child: _chip('🔥', '×${boost.streak}', Colors.orange)),
              ),
            if (boost.isOnFire) const SizedBox(height: 12),
            if (widget.isSlowMotion)
              IgnorePointer(child: _chip('❄️', '', Colors.cyan))
            else if (boost.slowMotionCharges > 0)
              Semantics(
                button: true,
                label: L('Slow motion').resolve(language),
                child: GestureDetector(
                  onTap: widget.onSlowMotion,
                  child: FadeTransition(
                    opacity: Tween(begin: 1.0, end: 0.7).animate(_pulse),
                    child: _chip('❄️', boost.slowMotionCharges > 1 ? '×${boost.slowMotionCharges}' : '', Colors.cyan),
                  ),
                ),
              ),
          ]),
        ),
      ),
      if (_showsBossBanner)
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, scale, child) => Opacity(opacity: ((scale - 0.4) / 0.6).clamp(0, 1), child: child),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [rgb(0.6, 0.25, 0.9), rgb(1, 0.5, 0.2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 12, offset: Offset(0, 6))],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('👑', style: TextStyle(fontSize: 70)),
                    Text(L('Boss Level!').resolve(language), style: kid(34, color: Colors.white)),
                    const Text('⭐⭐⭐', style: TextStyle(fontSize: 26)),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _chip(String emoji, String label, Color tint) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          EmojiText(emoji, size: 30),
          if (label.isNotEmpty) Text(label, style: kid(17, color: Colors.white)),
        ]),
      );
}
