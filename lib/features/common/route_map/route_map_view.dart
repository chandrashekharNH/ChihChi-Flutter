import 'package:flutter/material.dart';
import 'package:chihchi/core/ui/emoji_text.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/ui/kid_text.dart';
import '../../../core/ui/palette.dart';
import '../../../core/ui/seeded_random.dart';
import '../../../domain/models/app_language.dart';
import 'route_map_content.dart';
import 'route_map_text.dart';

/// One tall illustrated map from the start (bottom) to the last land (top): the road winds
/// through each land's levels and ends at its hub. A marker waits at the next level.
///
/// It scrolls by itself. The page opens at the start (bottom), then travels up to the child's
/// level, and follows the marker when it moves. `topInset` leaves room for a top bar drawn over it.
class RouteMapView extends StatefulWidget {
  const RouteMapView({
    super.key,
    required this.content,
    required this.markerSpot,
    required this.onSelectLevel,
    this.onSelectLand,
    required this.marker,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final RouteMapContent content;
  final RouteMapSpot markerSpot;
  final void Function(int level) onSelectLevel;
  final void Function(int land)? onSelectLand;
  final Widget marker;
  final double topInset;
  final double bottomInset;

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> with TickerProviderStateMixin {
  final _scroll = ScrollController();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  late final AnimationController _ripple =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 46));
  double _viewport = 0;
  double _width = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (!reduceMotion) {
      _pulse.repeat(reverse: true);
      _ripple.repeat();
      _drift.repeat(reverse: true);
    }
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    _started = true;
    // Wait for the page to lay out, then travel to the child's level.
    Future<void>.delayed(Duration(milliseconds: reduceMotion ? 100 : 450), () {
      if (mounted) _scrollToMarker(animated: !reduceMotion, duration: const Duration(milliseconds: 1400));
    });
  }

  @override
  void didUpdateWidget(RouteMapView old) {
    super.didUpdateWidget(old);
    if (old.markerSpot != widget.markerSpot && _started) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToMarker(animated: true));
    }
  }

  void _scrollToMarker({required bool animated, Duration duration = const Duration(seconds: 1)}) {
    if (!_scroll.hasClients || _width == 0) return;
    final layout = RouteMapLayout(_width, widget.content);
    final y = layout.point(widget.markerSpot).dy + widget.topInset;
    final target = (y - _viewport / 2).clamp(0.0, _scroll.position.maxScrollExtent);
    if (animated) {
      _scroll.animateTo(target, duration: duration, curve: Curves.easeInOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pulse.dispose();
    _ripple.dispose();
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    return LayoutBuilder(builder: (context, constraints) {
      _viewport = constraints.maxHeight;
      _width = constraints.maxWidth;
      final layout = RouteMapLayout(_width, widget.content);
      return SingleChildScrollView(
        controller: _scroll,
        child: Padding(
          padding: EdgeInsets.only(top: widget.topInset, bottom: widget.bottomInset),
          child: SizedBox(
            width: layout.width,
            height: layout.height,
            child: Stack(clipBehavior: Clip.none, children: [
              ..._lands(layout),
              Positioned.fill(
                child: IgnorePointer(child: CustomPaint(painter: _RoadPainter(layout, widget.markerSpot))),
              ),
              for (final spot in widget.content.journey)
                if (spot != widget.markerSpot) _positioned(layout.point(spot), _spotView(spot, language)),
              _positioned(layout.point(widget.markerSpot), _spotView(widget.markerSpot, language)),
              _positioned(
                layout.point(widget.markerSpot).translate(0, -52),
                IgnorePointer(
                  child: ExcludeSemantics(
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) => Transform.translate(offset: Offset(0, -8 * _pulse.value), child: child),
                      child: widget.marker,
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: IgnorePointer(child: _clouds(layout))),
            ]),
          ),
        ),
      );
    });
  }

  /// Centres a child on a point of the map.
  Widget _positioned(Offset point, Widget child) => Positioned(
        left: point.dx - 150,
        top: point.dy - 150,
        width: 300,
        height: 300,
        child: Center(child: child),
      );

  List<Widget> _lands(RouteMapLayout layout) => [
        Positioned(
          left: 0,
          top: layout.height - RouteMapLayout.startHeight,
          width: layout.width,
          height: RouteMapLayout.startHeight,
          child: _LandBackground(
            colors: widget.content.startColors,
            decorations: widget.content.startDecorations,
            seed: 3,
            isReached: true,
          ),
        ),
        for (var i = 0; i < widget.content.lands.length; i++)
          Positioned(
            left: 0,
            top: layout.landTop(i),
            width: layout.width,
            height: layout.landHeight(i),
            child: _LandBackground(
              colors: widget.content.lands[i].colors,
              decorations: widget.content.lands[i].decorations,
              seed: widget.content.lands[i].id + 3,
              isReached: widget.content.lands[i].isReached,
            ),
          ),
      ];

  Widget _spotView(RouteMapSpot spot, AppLanguage language) {
    if (spot.isStart) return _HubView(hub: widget.content.start, isReached: true);
    if (spot.isHub) {
      final land = widget.content.lands.where((l) => l.id == spot.value).firstOrNull;
      if (land == null) return const SizedBox.shrink();
      final select = widget.onSelectLand;
      return _HubView(
        hub: land.hub,
        isReached: land.isReached,
        onTap: select != null && land.isReached ? () => select(land.id) : null,
      );
    }
    final stop = widget.content.stop(spot.value);
    if (stop == null) return const SizedBox.shrink();
    return _StopView(
      stop: stop,
      openColor: widget.content.openColor,
      isNext: widget.markerSpot == spot,
      hereText: RouteMapText.youAreHere(language),
      pulse: _pulse,
      ripple: _ripple,
      onTap: () {
        if (stop.isPlayable) widget.onSelectLevel(stop.level);
      },
    );
  }

  Widget _clouds(RouteMapLayout layout) {
    final count = (layout.height / 600).floor().clamp(3, 1000);
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, _) => Stack(children: [
        for (var i = 0; i < count; i++)
          Positioned(
            top: layout.height * i / count + 60 - 30,
            left: -60 + (layout.width + 120) * ((i.isEven ? _drift.value : 1 - _drift.value)) + (i % 4) * 30 - 30,
            child: Opacity(
              opacity: 0.75,
              child: Text('☁️', style: TextStyle(fontSize: 40 + (i % 3) * 14.0)),
            ),
          ),
      ]),
    );
  }
}

class _LandBackground extends StatelessWidget {
  const _LandBackground({required this.colors, required this.decorations, required this.seed, required this.isReached});
  final List<Color> colors;
  final List<String> decorations;
  final int seed;
  final bool isReached;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth, height = c.maxHeight;
      final generator = SeededRandom(seed);
      final count = (height / 44).floor().clamp(6, 1000);
      final spots = <Widget>[];
      if (decorations.isNotEmpty) {
        for (var i = 0; i < count; i++) {
          final leftSide = i.isEven;
          final x = width * (leftSide ? 0.03 + generator.next() * 0.14 : 0.83 + generator.next() * 0.14);
          final y = height * (0.08 + generator.next() * 0.86);
          final size = 24 + generator.next() * 14;
          spots.add(Positioned(
            left: x - size / 2,
            top: y - size / 2,
            child: Text(decorations[i % decorations.length], style: TextStyle(fontSize: size)),
          ));
        }
      }
      return Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
          ),
        ),
        ExcludeSemantics(child: Stack(children: spots)),
        if (!isReached) Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.18))),
      ]);
    });
  }
}

/// The winding road, with a gold trail over the part already travelled.
class _RoadPainter extends CustomPainter {
  _RoadPainter(this.layout, this.markerSpot);
  final RouteMapLayout layout;
  final RouteMapSpot markerSpot;

  @override
  void paint(Canvas canvas, Size size) {
    final journey = layout.content.journey;
    final points = journey.map(layout.point).toList();
    final index = journey.indexOf(markerSpot);
    final travelled = (index < 0 ? 0 : index) + 1;
    final road = _path(points);
    canvas.drawPath(
        road,
        Paint()
          ..color = const Color(0xFF4D4D4D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 26
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
    _dashed(canvas, road);
    if (travelled > 1) {
      canvas.drawPath(
          _path(points.take(travelled).toList()),
          Paint()
            ..color = rgb(1, 0.8, 0.2).withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
    }
  }

  void _dashed(Canvas canvas, Path path) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 24) {
        canvas.drawPath(metric.extractPath(d, d + 12), paint);
      }
    }
  }

  Path _path(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1], point = points[i];
      final mid = Offset((previous.dx + point.dx) / 2, (previous.dy + point.dy) / 2);
      path.quadraticBezierTo(previous.dx, mid.dy, mid.dx, mid.dy);
      path.quadraticBezierTo(point.dx, mid.dy, point.dx, point.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.markerSpot != markerSpot || old.layout.width != layout.width;
}

class _HubView extends StatelessWidget {
  const _HubView({required this.hub, required this.isReached, this.onTap});
  final RouteMapHub hub;
  final bool isReached;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget icon = Container(
      width: 104,
      height: 104,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: isReached ? 0.9 : 0.5),
        border: Border.all(color: isReached ? Colors.yellow : Colors.white.withValues(alpha: 0.6), width: 4),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Text(hub.landmark, style: const TextStyle(fontSize: 58)),
    );
    if (!isReached) {
      icon = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.6, 0.3, 0.1, 0, 0, //
          0.2, 0.7, 0.1, 0, 0, //
          0.2, 0.3, 0.5, 0, 0, //
          0, 0, 0, 1, 0,
        ]),
        child: icon,
      );
    }
    final label = Column(mainAxisSize: MainAxisSize.min, children: [
      icon,
      const SizedBox(height: 6),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(30)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(hub.name, maxLines: 1, style: kid(17, color: Colors.white)),
          ),
        ),
      ),
    ]);
    return Semantics(
      button: onTap != null,
      label: hub.name,
      excludeSemantics: true,
      child: onTap == null ? label : GestureDetector(onTap: onTap, child: label),
    );
  }
}

class _StopView extends StatelessWidget {
  const _StopView({
    required this.stop,
    required this.openColor,
    required this.isNext,
    required this.hereText,
    required this.pulse,
    required this.ripple,
    required this.onTap,
  });

  final RouteMapStop stop;
  final Color openColor;
  final bool isNext;
  final String hereText;
  final Animation<double> pulse;
  final Animation<double> ripple;
  final VoidCallback onTap;

  Color get _fill {
    switch (stop.state.kind) {
      case RouteMapStopKind.completed:
        return rgb(0.2, 0.72, 0.4);
      case RouteMapStopKind.open:
        return openColor;
      case RouteMapStopKind.locked:
        return const Color(0xFF8C8C8C);
      case RouteMapStopKind.premium:
        return rgb(0.95, 0.7, 0.15);
    }
  }

  String get _symbol {
    switch (stop.state.kind) {
      case RouteMapStopKind.completed:
        return '✓';
      case RouteMapStopKind.open:
        return stop.icon;
      case RouteMapStopKind.locked:
        return '🔒';
      case RouteMapStopKind.premium:
        return '👑';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = isNext ? 70.0 : 64.0;
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _fill,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 5, offset: Offset(0, 3))],
      ),
      child: SizedBox(
        width: 52,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: EmojiText(_symbol, size: stop.state.isCompleted ? 30 : 26),
        ),
      ),
    );
    return Semantics(
      button: true,
      label: stop.accessibilityLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              if (isNext) ...[
                AnimatedBuilder(
                  animation: ripple,
                  builder: (context, _) => Transform.scale(
                    scale: 1 + 0.6 * ripple.value,
                    child: Opacity(
                      opacity: 1 - ripple.value,
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.yellow.withValues(alpha: 0.45)),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.yellow, width: 5),
                    boxShadow: [
                      BoxShadow(color: Colors.yellow.withValues(alpha: 0.9), blurRadius: 12),
                      BoxShadow(color: Colors.orange.withValues(alpha: 0.6), blurRadius: 20),
                    ],
                  ),
                ),
              ],
              isNext
                  ? AnimatedBuilder(
                      animation: pulse,
                      builder: (context, child) => Transform.scale(scale: 1 + 0.1 * pulse.value, child: child),
                      child: circle,
                    )
                  : circle,
            ]),
          ),
          _label(),
        ]),
      ),
    );
  }

  Widget _label() {
    if (isNext && stop.state == RouteMapStopState.open) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.yellow,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 3, offset: Offset(0, 2))],
        ),
        child: Text('📍 $hereText', maxLines: 1, style: kid(13, color: rgb(0.3, 0.2, 0))),
      );
    }
    switch (stop.state.kind) {
      case RouteMapStopKind.completed:
        final stars = stop.state.stars;
        if (stars == null) return const SizedBox.shrink();
        final shown = stars.clamp(0, 3);
        return Text('⭐' * shown + '☆' * (3 - shown), style: const TextStyle(fontSize: 12));
      case RouteMapStopKind.open:
        final title = stop.title;
        if (title == null) return const SizedBox.shrink();
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(30)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(title, maxLines: 1, style: kid(12, weight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        );
      case RouteMapStopKind.premium:
        return const SizedBox.shrink();
      case RouteMapStopKind.locked:
        final caption = stop.lockedCaption;
        if (caption == null) return const SizedBox.shrink();
        return Text(caption, style: kid(11, weight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.9)));
    }
  }
}
