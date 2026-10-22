import 'dart:math' as math;
import 'dart:ui';

import '../../domain/models/puzzle_models.dart';

/// One side of a piece: straight (picture border), a knob sticking out, or a hole.
enum PuzzleEdge {
  blank(-1),
  flat(0),
  tab(1);

  const PuzzleEdge(this.value);
  final int value;

  PuzzleEdge get opposite => switch (this) {
        PuzzleEdge.blank => PuzzleEdge.tab,
        PuzzleEdge.tab => PuzzleEdge.blank,
        PuzzleEdge.flat => PuzzleEdge.flat,
      };
}

class PuzzlePiece {
  const PuzzlePiece({
    required this.id,
    required this.row,
    required this.column,
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
    required this.startRotation,
  });

  final int id, row, column;
  final PuzzleEdge top, right, bottom, left;

  /// Quarter turns clockwise the piece starts with; 0 = correct orientation.
  final int startRotation;

  PuzzlePiece withRotation(int r) =>
      PuzzlePiece(id: id, row: row, column: column, top: top, right: right, bottom: bottom, left: left, startRotation: r);
}

class PuzzleLayout {
  const PuzzleLayout(this.grid, this.pieces, this.usesJigsawShapes);
  final PuzzleGrid grid;
  final List<PuzzlePiece> pieces;
  final bool usesJigsawShapes;
}

/// Cuts a picture into pieces. Pure logic, no UI — the same engine serves every puzzle.
class PuzzleGenerator {
  /// Knob size as a fraction of the smaller cell side.
  static const tabRatio = 0.2;

  /// Grid for a difficulty, growing through the 10 puzzles of an adventure world (`step` 0…9) or
  /// picked at random for free play / replays (`step` null).
  static PuzzleGrid grid(PuzzleDifficulty difficulty, int? step, [math.Random? random]) {
    final grids = difficulty.grids;
    if (step == null) return grids[(random ?? math.Random()).nextInt(grids.length)];
    final index = math.min(grids.length - 1, math.max(0, step) * grids.length ~/ PuzzleWorld.puzzlesPerWorld);
    return grids[index];
  }

  static PuzzleLayout makeLayout(PuzzleGrid grid, PuzzleDifficulty difficulty, [math.Random? random]) {
    final rng = random ?? math.Random();
    final jigsaw = difficulty.usesJigsawShapes;
    // Edge between (r, c) and the piece below / to the right: tab = knob on (r, c).
    final below = List.generate(grid.rows, (_) => List.filled(grid.columns, PuzzleEdge.flat));
    final toRight = List.generate(grid.rows, (_) => List.filled(grid.columns, PuzzleEdge.flat));
    for (var r = 0; r < grid.rows; r++) {
      for (var c = 0; c < grid.columns; c++) {
        if (jigsaw && r < grid.rows - 1) below[r][c] = rng.nextBool() ? PuzzleEdge.tab : PuzzleEdge.blank;
        if (jigsaw && c < grid.columns - 1) toRight[r][c] = rng.nextBool() ? PuzzleEdge.tab : PuzzleEdge.blank;
      }
    }
    var pieces = <PuzzlePiece>[
      for (var r = 0; r < grid.rows; r++)
        for (var c = 0; c < grid.columns; c++)
          PuzzlePiece(
            id: r * grid.columns + c,
            row: r,
            column: c,
            top: r == 0 ? PuzzleEdge.flat : below[r - 1][c].opposite,
            right: toRight[r][c],
            bottom: below[r][c],
            left: c == 0 ? PuzzleEdge.flat : toRight[r][c - 1].opposite,
            startRotation: difficulty.requiresRotation ? rng.nextInt(4) : 0,
          ),
    ];
    // With rotation on, make sure most pieces really need turning.
    if (difficulty.requiresRotation && pieces.where((p) => p.startRotation != 0).length < pieces.length ~/ 2) {
      pieces = [for (final p in pieces) p.startRotation == 0 ? p.withRotation(1) : p];
    }
    return PuzzleLayout(grid, pieces, jigsaw);
  }

  static double tabSize(Size cell) => math.min(cell.width, cell.height) * tabRatio;

  /// Outline of a piece in image coordinates (y down). The cell occupies
  /// `(margin, margin, cell.width, cell.height)`; knobs reach into the margin.
  static Path outline(PuzzlePiece piece, Size cell, bool jigsaw) {
    final margin = tabSize(cell);
    final rect = Rect.fromLTWH(margin, margin, cell.width, cell.height);
    if (!jigsaw) {
      return Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(math.min(cell.width, cell.height) * 0.06)));
    }
    final path = Path()..moveTo(rect.left, rect.top);
    _edge(path, rect.topLeft, rect.topRight, const Offset(0, -1), piece.top, margin);
    _edge(path, rect.topRight, rect.bottomRight, const Offset(1, 0), piece.right, margin);
    _edge(path, rect.bottomRight, rect.bottomLeft, const Offset(0, 1), piece.bottom, margin);
    _edge(path, rect.bottomLeft, rect.topLeft, const Offset(-1, 0), piece.left, margin);
    return path..close();
  }

  /// A classic jigsaw knob: straight, a narrow neck, a round head, straight again.
  static void _edge(Path path, Offset start, Offset end, Offset outward, PuzzleEdge edge, double size) {
    if (edge == PuzzleEdge.flat) {
      path.lineTo(end.dx, end.dy);
      return;
    }
    final d = edge.value.toDouble();
    Offset p(double u, double v) => Offset(
        start.dx + (end.dx - start.dx) * u + outward.dx * v * size * d, start.dy + (end.dy - start.dy) * u + outward.dy * v * size * d);
    final a = p(0.37, 0);
    path.lineTo(a.dx, a.dy);
    final c1 = p(0.29, 0.55), c2 = p(0.33, 1.0), m = p(0.5, 1.0);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, m.dx, m.dy);
    final c3 = p(0.67, 1.0), c4 = p(0.71, 0.55), b = p(0.63, 0);
    path.cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, b.dx, b.dy);
    path.lineTo(end.dx, end.dy);
  }
}

class PuzzleSnapRule {
  /// A drop snaps when it lands close enough to the piece's own place and is turned the right way.
  static bool snaps(Offset drop, Offset target, int rotation, Size cell, PuzzleDifficulty difficulty) {
    if (rotation % 4 != 0) return false;
    return (drop - target).distance <= math.min(cell.width, cell.height) * difficulty.snapTolerance;
  }
}

class PuzzleScoring {
  static double targetTime(int pieces, PuzzleDifficulty difficulty) => math.max(1, pieces) * difficulty.secondsPerPiece;

  /// 100…1000. Young children always get the full score for finishing.
  static int score(PuzzleRunStats stats, PuzzleDifficulty difficulty) {
    if (!difficulty.scoresMistakes) return 1000;
    var score = 1000.0;
    score -= stats.wrongPlacements * 25;
    score -= stats.hints * 40;
    final target = targetTime(stats.pieces, difficulty);
    if (stats.time > target) score -= math.min(300, (stats.time - target) * 2);
    return score.clamp(100, 1000).round();
  }

  /// 2…5 stars — always encouraging. Mistakes only count from Normal up.
  static int stars(PuzzleRunStats stats, PuzzleDifficulty difficulty) {
    if (!difficulty.scoresMistakes) return 5;
    var stars = 5;
    final wrongRate = stats.wrongPlacements / math.max(1, stats.pieces);
    if (wrongRate > 0.25) stars -= 1;
    if (wrongRate > 0.75) stars -= 1;
    if (stats.hints > 0) stars -= 1;
    if (difficulty.showsTimeChallenge && stats.time > targetTime(stats.pieces, difficulty)) stars -= 1;
    return math.max(2, stars);
  }
}
