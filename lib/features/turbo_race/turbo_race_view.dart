import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/ui/kid_text.dart';
import '../../domain/models/app_language.dart';
import '../../game/engine/game_scene.dart';
import '../../services/progress/progress_service.dart';
import '../character/player_character_store.dart';
import '../character/player_marker.dart';
import 'turbo_race_content.dart';
import 'turbo_race_progress_store.dart';
import 'turbo_race_text.dart';
import 'turbo_race_view_model.dart';

/// One race: the 3D-look road, drag-to-steer, the racing HUD, the intro and countdown, pause and results.
class TurboRaceView extends StatefulWidget {
  const TurboRaceView({super.key, required this.race, required this.store});
  final TurboRaceDefinition race;
  final TurboRaceProgressStore store;

  @override
  State<TurboRaceView> createState() => _TurboRaceViewState();
}

class _TurboRaceViewState extends State<TurboRaceView> with WidgetsBindingObserver {
  TurboRaceViewModel? _vm;
  bool _didSave = false;
  late final AppState _appState = context.read<AppState>();
  double _steerStart = 0;
  ui.Image? _face;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _appState.audioService.startBackgroundMusic();
    _loadFace();
    _startAttempt();
  }

  /// The child's own character drives ChihChi's car when they made one.
  Future<void> _loadFace() async {
    final store = context.read<PlayerCharacterStore>();
    final bytes = store.portrait;
    if (!store.isEnabled || bytes == null) return;
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 128);
      final image = (await codec.getNextFrame()).image;
      if (!mounted) return;
      _face = image;
      _vm?.scene.playerFace = image;
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) _vm?.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _appState.audioService.stopBackgroundMusic();
    _vm?.removeListener(_changed);
    _vm?.dispose();
    super.dispose();
  }

  void _changed() {
    final vm = _vm;
    // Save as soon as the race ends, whatever the child taps next.
    if (vm != null && vm.phase == TurboPhase.finished && !_didSave) {
      _didSave = true;
      vm.save(widget.store, context.read<ProgressService>());
    }
    if (mounted) setState(() {});
  }

  void _startAttempt() {
    _vm?.removeListener(_changed);
    _vm?.dispose();
    _didSave = false;
    final store = context.read<PlayerCharacterStore>();
    final vm = TurboRaceViewModel(
      race: widget.race,
      language: _appState.language,
      audioService: _appState.audioService,
      rewardService: _appState.rewardService,
      childName: context.read<ProgressService>().progress.childName,
      usesOwnCharacter: store.isEnabled && store.portrait != null,
    )..addListener(_changed);
    vm.scene.playerFace = _face;
    vm.scene.reduceMotion = context.read<ProgressService>().progress.reducedMotion;
    _vm = vm;
    vm.start();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    final language = _appState.language;
    return Scaffold(
      backgroundColor: Colors.black,
      body: vm == null
          ? const SizedBox.shrink()
          : Stack(children: [
              // Hold anywhere to drive, and slide to steer: the further from where the finger
              // landed, the harder the turn. Lifting the finger lets the car roll to a stop.
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (e) {
                    _steerStart = e.position.dx;
                    vm.setHolding(true);
                    vm.setSteer(0);
                  },
                  onPointerMove: (e) => vm.setSteer((e.position.dx - _steerStart) / 70),
                  onPointerUp: (_) {
                    vm.setHolding(false);
                    vm.setSteer(0);
                  },
                  onPointerCancel: (_) {
                    vm.setHolding(false);
                    vm.setSteer(0);
                  },
                  child: GameView(key: ObjectKey(vm), scene: vm.scene),
                ),
              ),
              if (vm.phase != TurboPhase.finished) SafeArea(child: _TurboHUD(vm: vm, language: language)),
              ..._overlays(vm, language),
            ]),
    );
  }

  List<Widget> _overlays(TurboRaceViewModel vm, AppLanguage language) {
    switch (vm.phase) {
      case TurboPhase.intro:
        return [IgnorePointer(child: _IntroCard(race: widget.race, language: language))];
      case TurboPhase.countdown:
        return [_countdown('${vm.countdown}')];
      case TurboPhase.racing:
        return [if (vm.showsGo) _countdown(TurboRaceText.go.resolve(language))];
      case TurboPhase.paused:
        return [_pauseMenu(vm, language)];
      case TurboPhase.finished:
        final result = vm.result;
        return [
          if (result != null)
            TurboRaceResultView(
              race: widget.race,
              result: result,
              language: language,
              playerName: vm.playerName,
              onContinue: () => Navigator.of(context).pop(),
              onRaceAgain: _startAttempt,
            ),
        ];
    }
  }

  Widget _countdown(String text) => IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            key: ValueKey(text),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 350),
            builder: (context, t, child) => Opacity(opacity: t, child: child),
            child: Text(text,
                style: kid(110, color: Colors.white, shadows: const [
                  Shadow(color: Color(0xCCFF9500), blurRadius: 18),
                  Shadow(color: Color(0x80000000), blurRadius: 4),
                ])),
          ),
        ),
      );

  Widget _pauseMenu(TurboRaceViewModel vm, AppLanguage language) => Positioned.fill(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.55),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('⏸️ ${TurboRaceText.paused.resolve(language)}', style: kid(30, color: Colors.white)),
                  const SizedBox(height: 16),
                  TurboRaceButton(title: TurboRaceText.resume.resolve(language), icon: Icons.play_arrow, primary: true, onTap: vm.resume),
                  const SizedBox(height: 16),
                  TurboRaceButton(title: TurboRaceText.quit.resolve(language), icon: Icons.map, onTap: () => Navigator.of(context).pop()),
                ]),
              ),
            ),
          ),
        ),
      );
}

// HUD

/// Position, lap, mini-map, the learning banner, speed and the boost button. Kept to the edges so
/// the road stays clear.
class _TurboHUD extends StatelessWidget {
  const _TurboHUD({required this.vm, required this.language});
  final TurboRaceViewModel vm;
  final AppLanguage language;

  static final _panel = Colors.black.withValues(alpha: 0.45);

  @override
  Widget build(BuildContext context) {
    final feedback = vm.feedback;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IgnorePointer(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _stat(TurboRaceText.position.resolve(language), '${vm.position}', vm.simulation.cars.length),
                const SizedBox(width: 10),
                _stat(TurboRaceText.lap.resolve(language), '${vm.lap}', vm.race.laps),
              ]),
              const SizedBox(height: 8),
              _Standings(order: vm.standings, playerName: vm.playerName),
            ]),
          ),
          const Spacer(),
          IgnorePointer(
            child: Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
              child: CustomPaint(painter: _MiniMapPainter(vm.scene.miniMap.$1, vm.scene.miniMapCars)),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: TurboRaceText.paused.resolve(language),
            child: GestureDetector(
              onTap: vm.pause,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: _panel, shape: BoxShape.circle),
                child: const Icon(Icons.pause, color: Colors.white),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        IgnorePointer(
          child: Column(children: [
            if (vm.banner != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD133),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Text(vm.banner!, style: kid(20, color: Colors.black)),
              ),
            if (feedback != null) ...[
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: switch (feedback.kind) {
                    TurboFeedbackKind.boost => const Color(0xFF1AB359),
                    TurboFeedbackKind.learn => const Color(0xFFF27366),
                    TurboFeedbackKind.info => Colors.black.withValues(alpha: 0.55),
                  },
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(feedback.text, textAlign: TextAlign.center, style: kid(20, color: Colors.white)),
              ),
            ],
          ]),
        ),
        const Spacer(),
        IgnorePointer(
          child: vm.showsHoldHint && (vm.phase == TurboPhase.racing || vm.phase == TurboPhase.countdown)
              ? _HoldHint(text: TurboRaceText.holdToDrive.resolve(language))
              : vm.phase == TurboPhase.racing && vm.isHolding && !vm.hasSteered
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(30)),
                      child: Text('👉 ${TurboRaceText.steerTip.resolve(language)}', style: kid(17, weight: FontWeight.w700, color: Colors.white)),
                    )
                  : const SizedBox.shrink(),
        ),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(30)),
              child: Text('⭐ ${vm.starsCollected}', style: kid(20, color: Colors.white)),
            ),
          ),
          const Spacer(),
          IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text(vm.speed.toString().padLeft(3, '0'),
                    style: kid(40, color: vm.isBoosting ? Colors.cyanAccent : Colors.white)
                        .copyWith(fontFeatures: const [ui.FontFeature.tabularFigures()], height: 1)),
                Text(TurboRaceText.speedUnit.resolve(language), style: kid(12, weight: FontWeight.w800, color: Colors.white70)),
              ]),
            ),
          ),
          const Spacer(),
          _boostButton(),
        ]),
      ]),
    );
  }

  Widget _stat(String title, String value, int total) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Text(title, style: kid(11, weight: FontWeight.w800, color: Colors.white70)),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(value, style: kid(30, color: Colors.white).copyWith(height: 1)),
            Text('/$total', style: kid(15, weight: FontWeight.w700, color: Colors.white70)),
          ]),
        ]),
      );

  Widget _boostButton() {
    final ready = vm.boostMeter >= 0.99;
    return Semantics(
      button: true,
      label: (ready ? TurboRaceText.boostReady : TurboRaceText.boost).resolve(language),
      child: GestureDetector(
        onTap: ready ? vm.fireBoost : null,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.5),
            boxShadow: ready ? const [BoxShadow(color: Color(0xCCFFEB3B), blurRadius: 12)] : null,
          ),
          child: CustomPaint(
            painter: _RingPainter(vm.boostMeter, ready ? Colors.yellow : Colors.cyan),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('⚡', style: TextStyle(fontSize: 30)),
                Text(TurboRaceText.boost.resolve(language), style: kid(10, color: Colors.white)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color);
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(8.5);
    canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value.clamp(0, 1),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

/// Every racer's face in race order, so the child sees who is ahead and who is close behind.
class _Standings extends StatelessWidget {
  const _Standings({required this.order, required this.playerName});
  final List<int> order;
  final String playerName;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var place = 0; place < order.length; place++)
          () {
            final car = order[place];
            final racer = TurboRacer.forCar(car);
            final isPlayer = car == 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isPlayer ? Colors.yellow : racer.paint.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                    width: 16,
                    child: Text('${place + 1}', style: kid(12, color: isPlayer ? Colors.black : Colors.white.withValues(alpha: 0.85)))),
                if (isPlayer) ...[
                  PlayerMarker(fallback: racer.face, size: 20),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Text(playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: kid(12, color: Colors.black)),
                  ),
                ] else
                  Text(racer.face, style: const TextStyle(fontSize: 15)),
              ]),
            );
          }(),
      ]);
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.track, this.cars);
  final List<Offset> track;
  final List<Offset> cars;

  @override
  void paint(Canvas canvas, Size size) {
    if (track.isEmpty) return;
    Offset s(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    final path = Path()..moveTo(s(track.first).dx, s(track.first).dy);
    for (final p in track.skip(1)) {
      path.lineTo(s(p).dx, s(p).dy);
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: 0.85));
    for (var i = cars.length - 1; i >= 0; i--) {
      final r = i == 0 ? 5.0 : 3.5;
      canvas.drawCircle(s(cars[i]), r, Paint()..color = TurboRacer.forCar(i).paint);
      if (i == 0) {
        canvas.drawCircle(
            s(cars[i]),
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(_MiniMapPainter old) => true;
}

/// A pulsing hand: the car only drives while a finger is on the screen.
class _HoldHint extends StatefulWidget {
  const _HoldHint({required this.text});
  final String text;

  @override
  State<_HoldHint> createState() => _HoldHintState();
}

class _HoldHintState extends State<_HoldHint> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFF7333),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, child) => Transform.translate(offset: Offset(0, -2 + 6 * _c.value), child: child),
            child: const Text('👆', style: TextStyle(fontSize: 34)),
          ),
          const SizedBox(width: 10),
          Text(widget.text, style: kid(22, color: Colors.white)),
        ]),
      );
}

// Intro

/// Where we are going and the three star goals, shown while the camera circles the grid.
class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.race, required this.language});
  final TurboRaceDefinition race;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text(race.icon, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(TurboRaceText.raceNumber(race.number).resolve(language).toUpperCase(), style: kid(13, weight: FontWeight.w800, color: Colors.orange)),
                    Text(race.name(language), style: kid(24, color: Colors.white)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Text('${TurboRaceText.goingTo(race.destination.name(language)).resolve(language)} ${race.destination.landmark}',
                  style: kid(16, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.9))),
              const SizedBox(height: 10),
              TurboRaceGoalList(race: race, language: language),
            ]),
          ),
        ),
      );
}

/// The three star goals; with results, each shows whether it was met.
class TurboRaceGoalList extends StatelessWidget {
  const TurboRaceGoalList({super.key, required this.race, required this.language, this.achieved});
  final TurboRaceDefinition race;
  final AppLanguage language;
  final List<bool>? achieved;

  @override
  Widget build(BuildContext context) {
    Widget goal(String text, int index) {
      final met = achieved?[index];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(met == true ? Icons.star : Icons.star_border, color: met == false ? Colors.white.withValues(alpha: 0.4) : Colors.yellow, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: kid(15, weight: FontWeight.w600, color: met == false ? Colors.white.withValues(alpha: 0.55) : Colors.white)),
          ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      goal(TurboRaceText.goalFinish.resolve(language), 0),
      goal(TurboRaceText.goalLearning(race.learningGoal).resolve(language), 1),
      goal(TurboRaceText.goalBonus(race.bonus).resolve(language), 2),
    ]);
  }
}

class TurboRaceButton extends StatelessWidget {
  const TurboRaceButton({super.key, required this.title, required this.icon, this.primary = false, required this.onTap});
  final String title;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: primary ? const LinearGradient(colors: [Color(0xFFFFD940), Color(0xFFFF9926)], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
            color: primary ? null : Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withValues(alpha: primary ? 0.6 : 0.3), width: 1.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: primary ? Colors.black : Colors.white),
            const SizedBox(width: 8),
            Flexible(child: Text(title, style: kid(19, color: primary ? Colors.black : Colors.white))),
          ]),
        ),
      );
}

String formatRaceTime(double seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds - minutes * 60;
  return '${minutes.toString().padLeft(2, '0')}:${rest.toStringAsFixed(2).padLeft(5, '0')}';
}

// Results

/// The race result: place, time, best lap, learning, stars, rewards and where the journey goes next.
/// Never "You lost": every finish is a finish, and one star always opens the next race.
class TurboRaceResultView extends StatefulWidget {
  const TurboRaceResultView({
    super.key,
    required this.race,
    required this.result,
    required this.language,
    required this.playerName,
    required this.onContinue,
    required this.onRaceAgain,
  });
  final TurboRaceDefinition race;
  final TurboRaceOutcome result;
  final AppLanguage language;
  final String playerName;
  final VoidCallback onContinue;
  final VoidCallback onRaceAgain;

  @override
  State<TurboRaceResultView> createState() => _TurboRaceResultViewState();
}

class _TurboRaceResultViewState extends State<TurboRaceResultView> {
  int _shownStars = 0;

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  Future<void> _reveal() async {
    for (var star = 1; star <= widget.result.stars; star++) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => _shownStars = star);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final l = widget.language;
    final race = widget.race;
    final destination = race.destination;
    Widget stat(String title, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              FittedBox(child: Text(title, style: kid(11, weight: FontWeight.w800, color: Colors.white70))),
              Text(value, style: kid(19, color: Colors.white)),
            ]),
          ),
        );
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1F244D), Color(0xFF0D0F26)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const PlayerMarker(fallback: '🐼', size: 58),
                    const SizedBox(width: 6),
                    Text(r.position == 1 ? '🏆' : '🏁', style: const TextStyle(fontSize: 48)),
                  ]),
                  Text((r.position == 1 ? TurboRaceText.raceComplete : TurboRaceText.greatTry).resolve(l), style: kid(26, color: Colors.white)),
                  Text(TurboRaceText.place(r.position).resolve(l), style: kid(20, weight: FontWeight.w800, color: r.position <= 3 ? Colors.yellow : Colors.white70)),
                  const SizedBox(height: 14),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(i < _shownStars ? Icons.star : Icons.star_border,
                            size: 44, color: i < _shownStars ? Colors.yellow : Colors.white.withValues(alpha: 0.3)),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  Text(TurboRaceText.finishOrder.resolve(l), style: kid(13, weight: FontWeight.w800, color: Colors.white70)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                    for (var place = 0; place < r.finishOrder.length; place++)
                      Container(
                        constraints: const BoxConstraints(minWidth: 44),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        decoration: BoxDecoration(
                          color: r.finishOrder[place] == 0 ? Colors.yellow.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(children: [
                          if (r.finishOrder[place] == 0)
                            PlayerMarker(fallback: TurboRacer.forCar(0).face, size: 34)
                          else
                            Text(TurboRacer.forCar(r.finishOrder[place]).face, style: const TextStyle(fontSize: 24)),
                          Text(place == 0 ? '🥇' : place == 1 ? '🥈' : place == 2 ? '🥉' : '${place + 1}', style: kid(13, color: Colors.white)),
                        ]),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    stat(TurboRaceText.time.resolve(l), formatRaceTime(r.time)),
                    const SizedBox(width: 10),
                    stat(TurboRaceText.bestLap.resolve(l), r.bestLap == null ? '–' : formatRaceTime(r.bestLap!)),
                    const SizedBox(width: 10),
                    stat(TurboRaceText.learning.resolve(l), '${r.gatesCorrect}/${r.totalGates}'),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
                    child: TurboRaceGoalList(race: race, language: l, achieved: r.starGoals),
                  ),
                  const SizedBox(height: 14),
                  Text(TurboRaceText.rewards.resolve(l), style: kid(12, weight: FontWeight.w800, color: Colors.white70)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    for (final grant in r.rewards)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0x4DFFBF33), borderRadius: BorderRadius.circular(30)),
                        child: Text('${grant.type.emoji} +${grant.amount}', style: kid(18, color: Colors.white)),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  Text(TurboRaceText.nextDestination.resolve(l), style: kid(12, weight: FontWeight.w800, color: Colors.white70)),
                  Text(
                    race.arrivesAtDestination
                        ? TurboRaceText.welcomeTo(destination.name(l)).resolve(l)
                        : '${destination.landmark} ${destination.name(l)}',
                    textAlign: TextAlign.center,
                    style: kid(20, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  TurboRaceButton(title: TurboRaceText.continueJourney.resolve(l), icon: Icons.map, primary: true, onTap: widget.onContinue),
                  const SizedBox(height: 10),
                  TurboRaceButton(title: TurboRaceText.raceAgain.resolve(l), icon: Icons.replay, onTap: widget.onRaceAgain),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
