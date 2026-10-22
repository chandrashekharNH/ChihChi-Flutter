import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../../game/engine/draw.dart';
import '../../game/engine/game_scene.dart';
import 'ar_explorer_recognition.dart';
import 'ar_explorer_world_content.dart';

sealed class StageHit {
  const StageHit();
}

class CompanionHit extends StageHit {
  const CompanionHit();
}

class AnimalHit extends StageHit {
  const AnimalHit(this.id);
  final String id;
}

class PortalHit extends StageHit {
  const PortalHit();
}

class TreasureHit extends StageHit {
  const TreasureHit();
}

enum TreasureDirection { ahead, left, right, behind }

enum CameraState { starting, running, denied, failed }

class _Piece {
  _Piece(this.kind, this.emoji, this.position, this.size, {this.id = '', this.tappable = true});
  final String kind; // companion, animal, portal, scenery, treasure, item
  final String emoji;
  final String id;
  Offset position;
  final double size;
  final bool tappable;
  double age = 0;
  double delay = 0;
  double hop = 0;
  double hopHeight = 0.3;
  Offset? flyTo;
  double flyAge = 0;
  bool removed = false;
}

class _Marker {
  _Marker(this.position, this.color);
  final Offset position;
  final Color color;
  double age = 0;
}

class _Spark {
  _Spark(this.position, this.velocity, this.color);
  Offset position, velocity;
  final Color color;
  double age = 0;
}

/// The camera and ChihChi's own pictures in front of it. On iOS these stand in the room with ARKit;
/// here they are drawn over the live camera where the child placed them. The camera picture is only
/// read when the child taps (one photo, cut up and deleted at once).
class ARExplorerEngine extends GameScene {
  ARExplorerEngine({this.showsVirtualContent = false});

  final bool showsVirtualContent;
  final recognizer = ARObjectRecognizer();
  CameraController? controller;
  final state = ValueNotifier(CameraState.starting);
  bool _busy = false;

  final List<_Piece> _pieces = [];
  final List<_Marker> _markers = [];
  final List<_Spark> _sparks = [];
  Timer? _autoPlace;
  final _random = math.Random();

  /// My AR World keeps only this many items standing at once.
  static const maxWorldItems = 12;

  _Piece? get _companion => _pieces.where((p) => p.kind == 'companion' && !p.removed).firstOrNull;
  bool get hasStage => _companion != null;

  // Camera

  Future<void> start() async {
    state.value = CameraState.starting;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state.value = CameraState.failed;
        return;
      }
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final c = CameraController(back, ResolutionPreset.high, enableAudio: false);
      controller = c;
      await c.initialize();
      try {
        await c.setFlashMode(FlashMode.off);
      } catch (_) {}
      state.value = CameraState.running;
    } on CameraException catch (e) {
      state.value = e.code.contains('Denied') || e.code.contains('denied') ? CameraState.denied : CameraState.failed;
    } catch (_) {
      state.value = CameraState.failed;
    }
  }

  Future<void> restartAfterFailure() async {
    await controller?.dispose();
    controller = null;
    await start();
  }

  void pause() {
    isPaused = true;
    final c = controller;
    if (c != null && c.value.isInitialized) c.pausePreview().catchError((_) {});
  }

  void resume() {
    isPaused = false;
    final c = controller;
    if (c != null && c.value.isInitialized) c.resumePreview().catchError((_) {});
  }

  Future<void> stop() async {
    _autoPlace?.cancel();
    final c = controller;
    controller = null;
    await c?.dispose();
    recognizer.close();
  }

  /// One photo, cut into small pictures around the tap. Null while busy or when the camera can't.
  Future<TapCrops?> crops(Offset point) async {
    final c = controller;
    if (_busy || c == null || !c.value.isInitialized || c.value.isTakingPicture) return null;
    _busy = true;
    try {
      final file = await c.takePicture();
      return await recognizer.crops(file.path, point, size);
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }

  // Stage

  StageHit? stageHit(Offset point) {
    if (!hasStage) return null;
    for (final p in _pieces.reversed) {
      if (p.removed || !p.tappable) continue;
      if ((point - (p.position - Offset(0, p.size * 0.45))).distance <= p.size * 0.6) {
        switch (p.kind) {
          case 'companion':
            return const CompanionHit();
          case 'animal':
            return AnimalHit(p.id);
          case 'portal':
            return const PortalHit();
          case 'treasure':
            return const TreasureHit();
        }
      }
    }
    return null;
  }

  /// A small glowing ring where the child tapped.
  Offset showMarker(Offset point, Color tint) {
    _markers.add(_Marker(point, tint));
    return point;
  }

  /// Puts ChihChi where the child tapped, low enough in the view to be on the floor or a table.
  bool placeStage(Offset point, String companionEmoji) {
    if (hasStage || size.isEmpty || point.dy < size.height * 0.3) return false;
    final spot = showsVirtualContent ? point + Offset(-size.width * 0.16, 0) : point;
    _add(_Piece('companion', companionEmoji, _clampSpot(spot), 110));
    return true;
  }

  Offset _clampSpot(Offset p) => Offset(p.dx.clamp(50.0, math.max(50.0, size.width - 50)), p.dy.clamp(120.0, math.max(120.0, size.height - 40)));

  /// In camera hunts ChihChi finds its own spot, low in the view.
  void placeCompanionAutomatically(String emoji) {
    if (showsVirtualContent || hasStage) return;
    _autoPlace?.cancel();
    _autoPlace = Timer(const Duration(milliseconds: 1200), () {
      if (!hasStage && !size.isEmpty) placeStage(Offset(size.width * 0.18, size.height * 0.56), emoji);
    });
  }

  void _add(_Piece p, {double delay = 0}) {
    p.delay = reduceMotion ? 0 : delay;
    p.age = reduceMotion ? 1 : 0;
    _pieces.add(p);
  }

  Offset get _stage => _companion?.position ?? Offset(size.width / 2, size.height * 0.6);

  /// Shows an animal next to ChihChi (replacing the previous one).
  void showAnimal(ARExplorerAnimal animal) {
    if (!hasStage) return;
    _remove((p) => p.kind == 'animal');
    _add(_Piece('animal', animal.emoji, _clampSpot(_stage + Offset(size.width * 0.32, -10)), 190, id: animal.id));
    _hopPiece(_companion);
  }

  /// The animal's happy little jump when tapped.
  void reactAnimal() => _hopPiece(_pieces.where((p) => p.kind == 'animal' && !p.removed).firstOrNull, height: 0.5);

  void showPortal() {
    if (!hasStage || _pieces.any((p) => p.kind == 'portal' && !p.removed)) return;
    _add(_Piece('portal', '🌀', _clampSpot(_stage + Offset(size.width * 0.34, -14)), 170));
  }

  /// The portal opens: a few pictures of the world stand around it.
  void openPortal(ARAdventureWorld world) {
    final portal = _pieces.where((p) => p.kind == 'portal' && !p.removed).firstOrNull;
    final centre = portal?.position ?? _stage;
    _hopPiece(portal, height: 0.2);
    const angles = [-1.2, -0.45, 0.45, 1.2];
    for (var i = 0; i < math.min(angles.length, world.scenery.length); i++) {
      final radius = (i.isEven ? 0.42 : 0.32) * size.width;
      final at = centre + Offset(math.sin(angles[i]) * radius, -math.cos(angles[i]) * radius * 0.45 - 40);
      _add(_Piece('scenery', world.scenery[i], _clampSpot(at), 110, tappable: false), delay: 0.15 * i);
    }
    celebrate();
  }

  /// Hides a treasure somewhere around the view: small, near the edges.
  void hideTreasure(ARTreasure treasure) {
    if (!hasStage) return;
    _remove((p) => p.kind == 'treasure');
    final left = _random.nextBool();
    final x = left ? size.width * (0.08 + _random.nextDouble() * 0.2) : size.width * (0.72 + _random.nextDouble() * 0.2);
    final y = size.height * (0.28 + _random.nextDouble() * 0.3);
    _add(_Piece('treasure', treasure.emoji, Offset(x, y), 70));
  }

  /// My AR World: stands a collected item where the child taps. The oldest goes when there are too many.
  bool placeItem(String emoji, Offset point) {
    if (!hasStage || point.dy < size.height * 0.2) return false;
    final placed = _pieces.where((p) => p.kind == 'item' && !p.removed).toList();
    if (placed.length >= maxWorldItems) placed.first.removed = true;
    _add(_Piece('item', emoji, _clampSpot(point), 110, tappable: false));
    _hopPiece(_companion);
    return true;
  }

  void removeTreasure() => _remove((p) => p.kind == 'treasure');

  /// The treasure flies to ChihChi and disappears.
  void collectTreasure() {
    final piece = _pieces.where((p) => p.kind == 'treasure' && !p.removed).firstOrNull;
    if (piece == null) return;
    if (reduceMotion || _companion == null) {
      piece.removed = true;
      celebrate();
      return;
    }
    piece.flyTo = _companion!.position - const Offset(0, 60);
    piece.flyAge = 0;
  }

  /// Where a hidden treasure is on screen.
  TreasureDirection? treasureDirection() {
    final piece = _pieces.where((p) => p.kind == 'treasure' && !p.removed).firstOrNull;
    if (piece == null) return null;
    if (piece.position.dx < size.width * 0.33) return TreasureDirection.left;
    if (piece.position.dx > size.width * 0.67) return TreasureDirection.right;
    return TreasureDirection.ahead;
  }

  /// Clears animals, the portal, scenery, treasure and items, keeping ChihChi.
  void clearStagePieces() => _remove((p) => p.kind != 'companion');

  void _remove(bool Function(_Piece) test) {
    for (final p in _pieces) {
      if (test(p)) p.removed = true;
    }
  }

  /// Two happy hops and a few sparkles.
  void celebrate() {
    final c = _companion;
    _hopPiece(c);
    Timer(const Duration(milliseconds: 450), () => _hopPiece(_companion));
    final at = c?.position ?? Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 26; i++) {
      final a = -math.pi / 2 + (_random.nextDouble() - 0.5) * 2.4;
      _sparks.add(_Spark(at - const Offset(0, 60), Offset(math.cos(a), math.sin(a)) * (160 + _random.nextDouble() * 220),
          Draw.hsv(_random.nextDouble(), 0.7, 1)));
    }
  }

  /// ChihChi walks a little toward something the child found, then back.
  void approach(Offset point) {
    final c = _companion;
    if (reduceMotion || c == null) {
      _hopPiece(c);
      return;
    }
    final home = c.position;
    final step = point - home;
    final length = step.distance;
    if (length < 10) return;
    final there = home + step / length * math.min(length * 0.5, size.width * 0.25);
    timeline.tween(0.6, (t) => c.position = Offset.lerp(home, there, t)!, onDone: () {
      _hopPiece(c);
      timeline.tween(0.6, (t) => c.position = Offset.lerp(there, home, t)!, delay: 1.6);
    });
  }

  void _hopPiece(_Piece? p, {double height = 0.3}) {
    if (reduceMotion || p == null) return;
    p.hop = 0.38;
    p.hopHeight = height;
  }

  // Frame

  @override
  void update(double dt) {
    for (final p in _pieces) {
      p.age += dt;
      p.hop = math.max(0, p.hop - dt);
      if (p.flyTo != null) {
        p.flyAge += dt;
        if (p.flyAge > 0.65) {
          p.removed = true;
          p.flyTo = null;
          celebrate();
        }
      }
    }
    _pieces.removeWhere((p) => p.removed);
    for (final m in [..._markers]) {
      m.age += dt;
      if (m.age > 1.5) _markers.remove(m);
    }
    for (final s in [..._sparks]) {
      s.age += dt;
      s.velocity += Offset(0, 500 * dt);
      s.position += s.velocity * dt;
      if (s.age > 1.2) _sparks.remove(s);
    }
    repaint();
  }

  @override
  void render(Canvas canvas) {
    for (final m in _markers) {
      final k = m.age / 1.5;
      canvas.drawCircle(m.position, 18 + 14 * k, Draw.stroke(m.color.withValues(alpha: (1 - k) * 0.9), 4));
      canvas.drawCircle(m.position, 6, Draw.fill(m.color.withValues(alpha: 1 - k)));
    }
    final sorted = [..._pieces]..sort((a, b) => a.position.dy.compareTo(b.position.dy));
    for (final p in sorted) {
      final grow = easeOut(((p.age - p.delay) / 0.35).clamp(0.0, 1.0));
      if (grow <= 0) continue;
      var at = p.position;
      var scale = grow;
      if (p.flyTo != null) {
        final k = easeIn((p.flyAge / 0.6).clamp(0.0, 1.0));
        at = Offset.lerp(p.position, p.flyTo!, k)!;
        scale *= 1 - 0.7 * k;
      }
      final hop = p.hop > 0 ? math.sin((1 - p.hop / 0.38) * math.pi) * p.hopHeight * p.size : 0.0;
      // A soft shadow on the floor, then the picture standing on it.
      canvas.drawOval(Rect.fromCenter(center: at, width: p.size * 0.7 * scale, height: p.size * 0.16 * scale),
          Draw.fill(const Color(0x44000000)));
      final bob = reduceMotion ? 0.0 : math.sin(time * 2 + p.position.dx) * (p.kind == 'treasure' ? 6 : 2);
      if (p.kind == 'portal') {
        final c = at - Offset(0, p.size * 0.5 + hop);
        for (var ring = 0; ring < 4; ring++) {
          final r = p.size * (0.48 - ring * 0.1) * scale;
          canvas.drawOval(Rect.fromCenter(center: c, width: r * 1.4, height: r * 2),
              Draw.stroke(Draw.hsv((time * 0.3 + ring * 0.18) % 1, 0.7, 1, 0.9), 6));
        }
        Draw.text(canvas, '✨', c, p.size * 0.3 * scale);
      } else {
        if (p.kind == 'treasure' && !reduceMotion) {
          canvas.drawCircle(at - Offset(0, p.size * 0.45), p.size * (0.55 + 0.08 * math.sin(time * 5)),
              Draw.fill(const Color(0x55FFE066)));
        }
        Draw.text(canvas, p.emoji, at - Offset(0, p.size * 0.45 + hop + bob), p.size * scale, shadow: true);
      }
    }
    for (final s in _sparks) {
      canvas.drawCircle(s.position, 4, Draw.fill(s.color.withValues(alpha: (1 - s.age / 1.2).clamp(0, 1))));
    }
  }

  @override
  void disposeScene() {
    _autoPlace?.cancel();
    state.dispose();
    super.disposeScene();
  }
}
