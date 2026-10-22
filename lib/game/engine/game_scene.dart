import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

// A small 2D game engine shared by the games: a scene that updates every frame and paints itself,
// timers and tweens that follow the scene's clock (so pause and slow motion apply to them), and a
// widget that runs a scene. Coordinates are screen points with y pointing down.

double easeInOut(double t) => t <= 0 ? 0 : (t >= 1 ? 1 : t * t * (3 - 2 * t));
double easeOut(double t) => t <= 0 ? 0 : (t >= 1 ? 1 : 1 - (1 - t) * (1 - t));
double easeIn(double t) => t <= 0 ? 0 : (t >= 1 ? 1 : t * t);

/// Something that happens over time on the scene's clock.
class GameTween {
  GameTween(this.duration, this.onUpdate, {this.curve = easeInOut, this.onDone, this.delay = 0});
  final double duration;
  final void Function(double t) onUpdate;
  final double Function(double) curve;
  final VoidCallback? onDone;
  double delay;
  double _elapsed = 0;
  bool _cancelled = false;

  bool get isDone => _cancelled || _elapsed >= duration;
  void cancel() => _cancelled = true;

  /// Returns true once finished.
  bool step(double dt) {
    if (_cancelled) return true;
    if (delay > 0) {
      delay -= dt;
      if (delay > 0) return false;
      dt = -delay;
      delay = 0;
    }
    _elapsed += dt;
    onUpdate(curve(duration <= 0 ? 1 : math.min(1, _elapsed / duration)));
    if (_elapsed >= duration) {
      onDone?.call();
      return true;
    }
    return false;
  }
}

/// Runs tweens and delayed calls.
class Timeline {
  final List<GameTween> _tweens = [];

  GameTween tween(double duration, void Function(double t) onUpdate,
      {double Function(double) curve = easeInOut, VoidCallback? onDone, double delay = 0}) {
    final t = GameTween(duration, onUpdate, curve: curve, onDone: onDone, delay: delay);
    _tweens.add(t);
    return t;
  }

  /// Calls `action` after `seconds` of scene time.
  GameTween after(double seconds, VoidCallback action) => tween(0, (_) {}, delay: seconds, onDone: action);

  void update(double dt) {
    if (_tweens.isEmpty) return;
    final running = List.of(_tweens);
    for (final t in running) {
      if (t.step(dt)) _tweens.remove(t);
    }
  }

  void clear() {
    for (final t in _tweens) {
      t.cancel();
    }
    _tweens.clear();
  }

  bool get isEmpty => _tweens.isEmpty;
}

/// One game's world. Subclasses update their state in `update` and draw it in `render`.
abstract class GameScene extends ChangeNotifier {
  Size size = Size.zero;

  /// Seconds of scene time (stops while paused, slows in slow motion).
  double time = 0;
  bool isPaused = false;

  /// 1 normally; below 1 while a slow-motion power-up is running.
  double timeScale = 1;
  final timeline = Timeline();
  bool reduceMotion = false;

  /// Called when the view first gets a size and whenever it changes.
  void resize(Size newSize) {}

  void update(double dt);
  void render(Canvas canvas);

  void tapDown(Offset position) {}
  void dragStart(Offset position) {}
  void dragUpdate(Offset position, Offset delta) {}
  void dragEnd() {}

  /// Called by the view each frame with real seconds.
  void tick(double realDt) {
    if (isPaused) return;
    final dt = math.min(realDt, 0.05) * timeScale;
    time += dt;
    timeline.update(dt);
    update(dt);
  }

  void repaint() => notifyListeners();

  @mustCallSuper
  void disposeScene() => timeline.clear();
}

/// Shows a scene and runs it every frame.
class GameView extends StatefulWidget {
  const GameView({super.key, required this.scene, this.handlesDrag = false});
  final GameScene scene;
  final bool handlesDrag;

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (widget.scene.size == Size.zero) return;
    widget.scene.tick(dt);
    widget.scene.repaint();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.scene.reduceMotion = MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      if (size != widget.scene.size && size.width > 0 && size.height > 0) {
        widget.scene.size = size;
        widget.scene.resize(size);
      }
      final paint = RepaintBoundary(
        child: CustomPaint(painter: _ScenePainter(widget.scene), size: size),
      );
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          widget.scene.tapDown(e.localPosition);
          if (widget.handlesDrag) widget.scene.dragStart(e.localPosition);
        },
        onPointerMove: widget.handlesDrag ? (e) => widget.scene.dragUpdate(e.localPosition, e.delta) : null,
        onPointerUp: widget.handlesDrag ? (_) => widget.scene.dragEnd() : null,
        onPointerCancel: widget.handlesDrag ? (_) => widget.scene.dragEnd() : null,
        child: paint,
      );
    });
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene) : super(repaint: scene);
  final GameScene scene;

  @override
  void paint(Canvas canvas, Size size) => scene.render(canvas);

  @override
  bool shouldRepaint(_ScenePainter old) => old.scene != scene;
}
