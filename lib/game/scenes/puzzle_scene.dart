import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import '../../core/ui/palette.dart';
import '../../domain/models/puzzle_models.dart';
import '../engine/draw.dart';
import '../engine/game_scene.dart';
import '../engine/living_backdrop.dart';
import '../engine/sprites.dart';
import '../puzzle/puzzle_art_renderer.dart';
import '../puzzle/puzzle_generator.dart';

class PuzzleSetup {
  const PuzzleSetup({
    required this.art,
    required this.layout,
    required this.pieces,
    required this.pieceScale,
    required this.difficulty,
    required this.reduceMotion,
  });
  final PuzzleArt art;
  final PuzzleLayout layout;
  final Map<int, PieceArt> pieces;

  /// Picture pixels per piece-image pixel.
  final double pieceScale;
  final PuzzleDifficulty difficulty;
  final bool reduceMotion;
}

/// One puzzle piece on the board or in the tray.
class _PieceNode {
  _PieceNode(this.piece, this.art) : rotationSteps = piece.startRotation, _angle = piece.startRotation * math.pi / 2;
  final PuzzlePiece piece;
  final PieceArt art;
  int rotationSteps;
  double _angle;
  bool isPlaced = false;
  bool lifted = false;
  Offset position = Offset.zero;
  Offset home = Offset.zero;
  double scale = 1;
  double opacity = 0;
  double z = 10;
  double flash = 0;
  double wiggle = 0;

  bool get isCorrectlyRotated => rotationSteps % 4 == 0;
}

/// "Build the Picture": board + tray, drag, rotate, magnetic snap, hints and a living finish.
/// Pure presentation — rules (snap, score) come from `PuzzleSnapRule` / `PuzzleScoring`, and the
/// view model reacts through the callbacks.
class PuzzleScene extends GameScene {
  void Function()? onLift;
  void Function()? onMove;
  void Function(int remaining)? onPlaced;
  void Function()? onWrongDrop;
  void Function()? onComplete;

  /// Space kept free for the bars above and below the scene.
  double topInset = 150;
  double bottomInset = 126;

  PuzzleSetup? _setup;
  Rect _board = Rect.zero, _tray = Rect.zero;
  Size _cell = Size.zero;
  double _pixelToPoint = 1;
  double _trayScale = 1;
  List<int> _trayOrder = [];
  final Map<int, _PieceNode> _nodes = {};
  _PieceNode? _dragging;
  Offset _dragOffset = Offset.zero;
  int? selectedPieceID;
  double _nextZ = 20;
  bool _interactive = false;
  static const _liftScale = 1.06;
  LivingBackdrop? _backdrop;
  final Map<int, int> _wrongDrops = {};
  final List<(Rect, int, double)> _glows = [];
  Rect? _nearGlow;
  bool _introPicture = false;
  double _introPictureOpacity = 1;
  bool _finished = false;
  double _finishScale = 1;
  late final _layer = SpriteLayer(timeline);
  final _random = math.Random();

  void setBackdrop(BackdropStyle style, {required bool animates}) {
    _backdrop = LivingBackdrop(style, animates: animates);
    if (size != Size.zero) _backdrop!.layout(size);
  }

  @override
  void resize(Size newSize) {
    _backdrop?.layout(newSize);
    _applyLayout();
  }

  void configure(PuzzleSetup setup) {
    timeline.clear();
    _layer.clear();
    _nodes.clear();
    _wrongDrops.clear();
    _glows.clear();
    _finished = false;
    _dragging = null;
    selectedPieceID = null;
    _interactive = false;
    _setup = setup;
    for (final piece in setup.layout.pieces) {
      final art = setup.pieces[piece.id];
      if (art != null) _nodes[piece.id] = _PieceNode(piece, art);
    }
    _trayOrder = setup.layout.pieces.map((p) => p.id).toList()..shuffle(_random);
    _applyLayout();
  }

  void _applyLayout() {
    final setup = _setup;
    if (setup == null || size.width <= 0) return;
    final available = Rect.fromLTWH(16, topInset, size.width - 32, math.max(100, size.height - topInset - bottomInset));
    if (size.width > size.height) {
      final side = math.min(available.height, available.width * 0.55);
      _board = Rect.fromLTWH(available.left, available.center.dy - side / 2, side, side);
      _tray = Rect.fromLTRB(_board.right + 20, available.top, available.right, available.bottom);
    } else {
      final side = math.min(available.width, available.height * 0.58);
      _board = Rect.fromLTWH(available.center.dx - side / 2, available.top, side, side);
      _tray = Rect.fromLTRB(available.left, _board.bottom + 16, available.right, available.bottom);
    }
    final grid = setup.layout.grid;
    _cell = Size(_board.width / grid.columns, _board.height / grid.rows);
    _pixelToPoint = _board.width / setup.art.full.width / setup.pieceScale;
    _layoutTray();
    for (final node in _nodes.values) {
      if (node == _dragging) continue;
      if (node.isPlaced) {
        node.position = _target(node.piece);
        node.scale = 1;
      } else if (_interactive) {
        node.position = node.home;
        node.scale = _trayScale;
      }
    }
  }

  /// Finds the biggest scale at which every piece fits in the tray, then gives each one a home slot.
  void _layoutTray() {
    final count = math.max(1, _trayOrder.length);
    final box = math.max(_cell.width, _cell.height) * (1 + 2 * PuzzleGenerator.tabRatio);
    const gap = 8.0;
    var scale = 1.0;
    var perRow = 1;
    while (scale > 0.2) {
      perRow = math.max(1, ((_tray.width + gap) / (box * scale + gap)).floor());
      final rows = (count / perRow).ceil();
      if (rows * (box * scale + gap) - gap <= _tray.height) break;
      scale -= 0.04;
    }
    _trayScale = math.max(0.2, scale);
    final slot = box * _trayScale + gap;
    final rows = (count / perRow).ceil();
    final usedHeight = rows * slot - gap;
    for (var i = 0; i < _trayOrder.length; i++) {
      final row = i ~/ perRow, column = i % perRow;
      final inRow = math.min(perRow, count - row * perRow);
      final rowWidth = inRow * slot - gap;
      final x = _tray.center.dx - rowWidth / 2 + column * slot + (slot - gap) / 2;
      final y = _tray.center.dy - usedHeight / 2 + row * slot + (slot - gap) / 2;
      _nodes[_trayOrder[i]]?.home = Offset(x, y);
    }
  }

  Offset _target(PuzzlePiece p) => Offset(_board.left + (p.column + 0.5) * _cell.width, _board.top + (p.row + 0.5) * _cell.height);

  // Intro: whole picture, then it breaks apart

  void playIntro(double seconds, void Function() completion) {
    _introPicture = true;
    _introPictureOpacity = 1;
    for (final n in _nodes.values) {
      n.position = _target(n.piece);
      n.scale = 1;
      n.opacity = 0;
    }
    timeline.after(seconds, () {
      for (final n in _nodes.values) {
        n.opacity = 1;
      }
      timeline.tween(0.2, (t) => _introPictureOpacity = 1 - t, onDone: () => _introPicture = false);
    });
    timeline.after(seconds + 0.25, () => _scatter(completion));
  }

  void _scatter(void Function() completion) {
    for (var i = 0; i < _trayOrder.length; i++) {
      final node = _nodes[_trayOrder[i]];
      if (node == null) continue;
      final from = node.position;
      final to = node.home;
      final fromScale = node.scale;
      timeline.tween(0.5, (t) {
        node.position = Offset.lerp(from, to, t)!;
        node.scale = fromScale + (_trayScale - fromScale) * t;
      }, delay: i * math.min(0.03, 0.9 / math.max(1, _trayOrder.length)));
    }
    timeline.after(1.1, () {
      _interactive = true;
      completion();
    });
  }

  // Touch: pick up, drag, drop

  bool _hits(_PieceNode n, Offset point) {
    final local = point - n.position;
    final a = -n.rotationSteps * math.pi / 2;
    final u = Offset(local.dx * math.cos(a) - local.dy * math.sin(a), local.dx * math.sin(a) + local.dy * math.cos(a));
    const slack = 1.2;
    return u.dx.abs() <= _cell.width / 2 * slack * n.scale && u.dy.abs() <= _cell.height / 2 * slack * n.scale;
  }

  @override
  void dragStart(Offset position) {
    if (!_interactive || _dragging != null) return;
    final candidates = _nodes.values.where((n) => !n.isPlaced).toList()..sort((a, b) => b.z.compareTo(a.z));
    final node = candidates.where((n) => _hits(n, position)).firstOrNull;
    if (node == null) return;
    selectedPieceID = node.piece.id;
    node.z = ++_nextZ;
    final growth = _liftScale / math.max(node.scale, 0.01);
    _dragOffset = (node.position - position) * growth;
    _dragging = node;
    node.lifted = true;
    final from = node.scale;
    timeline.tween(0.08, (t) => node.scale = from + (_liftScale - from) * t);
    onLift?.call();
  }

  @override
  void dragUpdate(Offset position, Offset delta) {
    final node = _dragging;
    if (node == null) return;
    node.position = position + _dragOffset;
    _updateNearGlow(node);
  }

  @override
  void dragEnd() {
    final node = _dragging;
    if (node != null) _drop(node);
  }

  void _drop(_PieceNode node) {
    _dragging = null;
    _nearGlow = null;
    node.lifted = false;
    final setup = _setup;
    if (setup == null) return;
    onMove?.call();
    final destination = _target(node.piece);
    if (PuzzleSnapRule.snaps(node.position, destination, node.rotationSteps, _cell, setup.difficulty)) {
      _place(node, destination);
    } else if (_board.inflate(_cell.shortestSide * 0.2).contains(node.position)) {
      onWrongDrop?.call();
      _sendHome(node, wiggle: true);
      // A second miss with the same piece shows where it goes, so the mistake teaches.
      _wrongDrops[node.piece.id] = (_wrongDrops[node.piece.id] ?? 0) + 1;
      if (_wrongDrops[node.piece.id] == 2) _glowSlot(destination, 2);
    } else {
      _sendHome(node, wiggle: false);
    }
  }

  void _place(_PieceNode node, Offset destination) {
    node.isPlaced = true;
    node.z = 5 + node.piece.id * 0.001;
    final from = node.position, fromScale = node.scale;
    timeline.tween(0.12, (t) {
      node.position = Offset.lerp(from, destination, t)!;
      node.scale = fromScale + (1 - fromScale) * t;
    }, curve: easeOut, onDone: () {
      timeline.tween(0.16, (t) => node.scale = 1 + 0.04 * math.sin(t * math.pi));
    });
    timeline.tween(0.31, (t) => node.flash = t < 0.2 ? 0.55 * t / 0.2 : 0.55 * (1 - (t - 0.2) / 0.8), curve: (x) => x);
    _layer.sparkleBurst(destination, 5, emojis: const ['✨', '⭐'], z: 60);
    final remaining = _nodes.values.where((n) => !n.isPlaced).length;
    onPlaced?.call(remaining);
    if (remaining == 0) _finish();
  }

  void _sendHome(_PieceNode node, {required bool wiggle}) {
    final shake = wiggle && _setup?.reduceMotion == false;
    final start = shake ? 0.14 : 0.0;
    if (shake) timeline.tween(0.14, (t) => node.wiggle = 6 * math.sin(t * 2 * math.pi), curve: (x) => x, onDone: () => node.wiggle = 0);
    timeline.after(start, () {
      final from = node.position, fromScale = node.scale;
      timeline.tween(0.28, (t) {
        node.position = Offset.lerp(from, node.home, t)!;
        node.scale = fromScale + (_trayScale - fromScale) * t;
      });
    });
  }

  void _updateNearGlow(_PieceNode node) {
    final setup = _setup;
    if (setup == null || !setup.difficulty.showsNearGlow) return;
    final destination = _target(node.piece);
    final near = (node.position - destination).distance < _cell.shortestSide * 0.9;
    _nearGlow = near ? Rect.fromCenter(center: destination, width: _cell.width, height: _cell.height) : null;
  }

  // Rotation

  /// Turns the selected (or held) piece a quarter turn clockwise. False if there's nothing to turn.
  bool rotateSelectedPiece() {
    final id = _dragging?.piece.id ?? selectedPieceID;
    final node = id == null ? null : _nodes[id];
    if (!_interactive || node == null || node.isPlaced) return false;
    node.rotationSteps = (node.rotationSteps + 1) % 4;
    final from = node._angle;
    timeline.tween(0.16, (t) => node._angle = from + math.pi / 2 * t, curve: easeOut);
    return true;
  }

  // Hint

  /// Glows the right place for the selected piece (or any piece still in the tray).
  bool showHint() {
    if (!_interactive) return false;
    final unplaced = _nodes.values.where((n) => !n.isPlaced).toList();
    if (unplaced.isEmpty) return false;
    final node = unplaced.where((n) => n.piece.id == selectedPieceID).firstOrNull ?? unplaced[_random.nextInt(unplaced.length)];
    selectedPieceID = node.piece.id;
    _glowSlot(_target(node.piece), 3);
    final base = node.scale;
    timeline.tween(0.3, (t) => node.scale = base * (1 + 0.15 * math.sin(t * math.pi)));
    if (!node.isCorrectlyRotated) {
      final arrow = _layer.add(Sprite(
          text: '↻', position: node.position - Offset(0, _cell.height * 0.5 * node.scale + 10), fontSize: 34, z: 100));
      _layer.fadeOutAndRemove(arrow, 0.3, delay: 1.4);
    }
    return true;
  }

  /// A golden glow on one spot of the board that pulses a few times, then fades.
  void _glowSlot(Offset destination, int pulses) {
    final rect = Rect.fromCenter(center: destination, width: _cell.width, height: _cell.height);
    final entry = (rect, pulses, time);
    _glows.add(entry);
    timeline.after(pulses * 0.6 + 0.3, () => _glows.remove(entry));
  }

  // Finish: the picture comes alive

  void _finish() {
    _interactive = false;
    timeline.after(0.3, () {
      for (final n in _nodes.values) {
        timeline.tween(0.35, (t) => n.flash = t < 0.43 ? 0.6 * t / 0.43 : 0.6 * (1 - (t - 0.43) / 0.57), curve: (x) => x);
      }
    });
    timeline.after(0.7, () {
      _finished = true;
      _finishScale = 1;
      timeline.tween(0.55, (t) => _finishScale = t < 0.45 ? 1 + 0.05 * t / 0.45 : 1.05 - 0.05 * (t - 0.45) / 0.55, curve: (x) => x);
      _confetti();
    });
    timeline.after(1.9, () => onComplete?.call());
  }

  void _confetti() {
    const pieces = ['🎉', '⭐', '✨', '🎈', '🌟', '💫'];
    for (var i = 0; i < 24; i++) {
      final s = _layer.add(Sprite(text: pieces[i % pieces.length], position: _board.center, fontSize: 18 + _random.nextDouble() * 14, z: 80));
      final angle = _random.nextDouble() * 2 * math.pi;
      final distance = _board.width * (0.3 + _random.nextDouble() * 0.45);
      _layer.moveTo(s, _board.center + Offset(math.cos(angle) * distance, math.sin(angle) * distance), 0.9, curve: easeOut);
      timeline.tween(0.9, (t) => s.rotation = math.pi * t);
      _layer.fadeOutAndRemove(s, 0.9);
    }
  }

  /// How a finished picture's living element moves.
  Offset _alive(String emoji, int index, double t, double unit, void Function(double scale, double opacity, double rot) style) {
    final phase = t - (index % 4) * 0.15;
    if (phase < 0) {
      style(1, 1, 0);
      return Offset.zero;
    }
    if (_setup?.reduceMotion == true) {
      style(phase < 0.8 ? 1 + 0.05 * math.sin(phase / 0.8 * math.pi) : 1, 1, 0);
      return Offset.zero;
    }
    if ('🦋🐝🐦🦜🦅🦉🕊️🐞✈️🚁🛸🪁🎈🦇'.contains(emoji)) {
      style(1, 1, 0);
      return Offset(unit * math.sin(phase * 2.6), -unit * 1.2 * math.sin(phase * 2.1));
    }
    if ('🐟🐠🐡🐬🐳🦈🐙🦀🐢🦭🪼🦆🦢'.contains(emoji)) {
      style(1, 1, 0);
      return Offset(unit * 1.5 * (0.5 - 0.5 * math.cos(phase * math.pi)), 0);
    }
    if ('⭐🌟✨🎆🎇☀️🌙🌕🪔💡'.contains(emoji)) {
      final k = 0.5 - 0.5 * math.cos(phase * math.pi * 2);
      style(1 + 0.15 * k, 1 - 0.25 * k, 0);
      return Offset.zero;
    }
    if (emoji == '🚀') {
      style(1, 1, 0);
      return Offset(0, -unit * 2 * (0.5 - 0.5 * math.cos(phase * math.pi / 0.6)));
    }
    if ('🚗🚕🚌🚓🚑🚒🚚🚜🏎️🏍️🛵🚲🛺🚂🚆🚄🚢⛵🚤🚐🛻'.contains(emoji)) {
      style(1, 1, 0);
      final k = 0.5 - 0.5 * math.cos(phase * math.pi / 0.5);
      return Offset(unit * k, -unit * 0.3 * k);
    }
    final k = 0.5 - 0.5 * math.cos(phase * math.pi / 0.35);
    style(1, 1, 0.06 * k);
    return Offset(0, -unit * k);
  }

  @override
  void update(double dt) => _layer.update(dt);

  @override
  void render(Canvas canvas) {
    _backdrop?.render(canvas, time);
    final setup = _setup;
    if (setup == null || _board == Rect.zero) return;
    final frame = RRect.fromRectAndRadius(_board.inflate(10), const Radius.circular(18));
    canvas.drawRRect(frame.shift(const Offset(0, 8)), Draw.fill(const Color(0x2E000000)));
    canvas.drawRRect(frame, Draw.fill(const Color(0xF0FFFFFF)));
    canvas.drawRRect(frame, Draw.stroke(rgb(0.98, 0.78, 0.35), 5));
    final tray = RRect.fromRectAndRadius(_tray, const Radius.circular(18));
    canvas.drawRRect(tray, Draw.fill(const Color(0x38FFFFFF)));
    canvas.drawRRect(tray, Draw.stroke(const Color(0x59FFFFFF), 2));
    final src = Rect.fromLTWH(0, 0, setup.art.full.width.toDouble(), setup.art.full.height.toDouble());
    if (_finished) {
      _renderFinished(canvas, setup, src);
    } else {
      if (setup.difficulty.showsGhostImage) {
        canvas.drawImageRect(setup.art.full, src, _board, Paint()..color = const Color(0x33FFFFFF));
      } else {
        final grid = setup.layout.grid;
        final lines = Draw.stroke(const Color(0x1F000000), 1.5);
        for (var c = 1; c < grid.columns; c++) {
          final x = _board.left + c * _cell.width;
          canvas.drawLine(Offset(x, _board.top), Offset(x, _board.bottom), lines);
        }
        for (var r = 1; r < grid.rows; r++) {
          final y = _board.top + r * _cell.height;
          canvas.drawLine(Offset(_board.left, y), Offset(_board.right, y), lines);
        }
      }
      for (final (rect, pulses, start) in _glows) {
        final t = time - start;
        final a = t < pulses * 0.6 ? 0.65 + 0.35 * math.cos(t / 0.6 * 2 * math.pi) : math.max(0.0, 1 - (t - pulses * 0.6) / 0.3);
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
        canvas.drawRRect(rr, Draw.fill(rgb(1, 0.9, 0.3, 0.35 * a)));
        canvas.drawRRect(rr, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = rgb(1, 0.8, 0.1, a)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4));
      }
      if (_nearGlow != null) {
        final rr = RRect.fromRectAndRadius(_nearGlow!, const Radius.circular(10));
        canvas.drawRRect(rr, Draw.fill(const Color(0x59FFFFFF)));
        canvas.drawRRect(rr, Draw.stroke(rgb(1, 0.85, 0.2), 4));
      }
      final ordered = [..._nodes.values]..sort((a, b) => a.z.compareTo(b.z));
      for (final n in ordered) {
        _renderPiece(canvas, n);
      }
      if (_introPicture) {
        canvas.drawImageRect(setup.art.full, src, _board, Paint()
          ..color = Color.fromRGBO(255, 255, 255, _introPictureOpacity)
          ..filterQuality = FilterQuality.medium);
      }
    }
    _layer.render(canvas);
  }

  void _renderPiece(Canvas canvas, _PieceNode n) {
    if (n.opacity <= 0) return;
    final art = n.art;
    final w = art.face.width * _pixelToPoint, h = art.face.height * _pixelToPoint;
    final anchor = art.anchor * _pixelToPoint;
    canvas.save();
    canvas.translate(n.position.dx + n.wiggle, n.position.dy);
    canvas.scale(n.scale);
    // The shadow falls the same way whatever the piece's turn.
    if (!n.isPlaced) {
      final shadowOffset = n.lifted ? const Offset(10, 14) : const Offset(3, 4);
      canvas.save();
      canvas.translate(shadowOffset.dx, shadowOffset.dy);
      canvas.rotate(n._angle);
      canvas.drawImageRect(art.shadow, Rect.fromLTWH(0, 0, art.shadow.width.toDouble(), art.shadow.height.toDouble()),
          Rect.fromLTWH(-anchor.dx, -anchor.dy, w, h), Paint()..color = Color.fromRGBO(0, 0, 0, n.lifted ? 0.3 : 0.22));
      canvas.restore();
    }
    canvas.rotate(n._angle);
    final dst = Rect.fromLTWH(-anchor.dx, -anchor.dy, w, h);
    canvas.drawImageRect(art.face, Rect.fromLTWH(0, 0, art.face.width.toDouble(), art.face.height.toDouble()), dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Color.fromRGBO(255, 255, 255, n.opacity));
    if (n.flash > 0.01) {
      canvas.drawImageRect(art.shadow, Rect.fromLTWH(0, 0, art.shadow.width.toDouble(), art.shadow.height.toDouble()), dst,
          Paint()..colorFilter = ColorFilter.mode(Color.fromRGBO(255, 255, 255, n.flash), BlendMode.srcIn));
    }
    canvas.restore();
  }

  void _renderFinished(Canvas canvas, PuzzleSetup setup, Rect src) {
    final side = _board.width;
    canvas.save();
    canvas.translate(_board.center.dx, _board.center.dy);
    canvas.scale(_finishScale);
    canvas.translate(-_board.center.dx, -_board.center.dy);
    canvas.drawImageRect(setup.art.base, src, _board, Paint()..filterQuality = FilterQuality.medium);
    final unit = side * 0.03;
    for (var i = 0; i < setup.art.elements.length; i++) {
      final e = setup.art.elements[i];
      var sc = 1.0, op = 1.0, rot = 0.0;
      final offset = _alive(e.emoji, i, time, unit, (s, o, r) {
        sc = s;
        op = o;
        rot = r;
      });
      final at = Offset(_board.left + e.x * side, _board.top + e.y * side) + offset;
      Draw.text(canvas, e.emoji, at, e.size * side, scale: sc, opacity: op, rotation: rot);
    }
    canvas.restore();
  }
}

/// Keeps `ui` in use for image types.
typedef PuzzleImage = ui.Image;
