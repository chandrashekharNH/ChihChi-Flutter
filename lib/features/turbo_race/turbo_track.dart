import 'dart:math' as math;

/// A small 3D vector (x right, y up, z towards the viewer at the start).
class V3 {
  const V3(this.x, this.y, this.z);
  final double x, y, z;

  static const zero = V3(0, 0, 0);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(x * x + y * y + z * z);
  V3 get normalized {
    final l = length;
    return l > 1e-6 ? this * (1 / l) : const V3(0, 0, -1);
  }

  double distanceTo(V3 o) => (this - o).length;
  static V3 lerp(V3 a, V3 b, double t) => V3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);
}

/// A race track's centre line: a smooth closed loop through the race's control points, resampled
/// every ~1 m so any distance along it maps to a position in constant time. Cars live on it as
/// (distance along the lap, sideways offset from the centre).
class TurboTrack {
  /// Half the road's width; three lanes fit inside.
  static const halfWidth = 7.0;

  /// Centre of each lane, left to right, as a sideways offset.
  static const laneOffsets = [-4.6, 0.0, 4.6];

  late final double length;
  late final List<V3> _points;
  late final double _step;

  TurboTrack(List<V3> controlPoints) {
    final dense = _catmullRom(controlPoints, 40);
    final cumulative = <double>[0];
    for (var i = 1; i < dense.length; i++) {
      cumulative.add(cumulative[i - 1] + dense[i - 1].distanceTo(dense[i]));
    }
    final total = cumulative.last + dense.last.distanceTo(dense.first);
    final count = math.max(8, total.round());
    final step = total / count;
    final even = <V3>[];
    var segment = 0;
    for (var sample = 0; sample < count; sample++) {
      final target = sample * step;
      while (segment + 1 < cumulative.length && cumulative[segment + 1] < target) {
        segment++;
      }
      final start = dense[segment];
      final end = segment + 1 < dense.length ? dense[segment + 1] : dense[0];
      final span = (segment + 1 < cumulative.length ? cumulative[segment + 1] : total) - cumulative[segment];
      final t = span > 0 ? (target - cumulative[segment]) / span : 0.0;
      even.add(V3.lerp(start, end, t));
    }
    _points = even;
    length = total;
    _step = step;
  }

  int get sampleCount => _points.length;

  /// Distance wrapped into one lap.
  double wrap(double distance) {
    final w = distance % length;
    return w < 0 ? w + length : w;
  }

  /// The centre of the road at a distance along the lap.
  V3 centre(double distance) {
    final s = wrap(distance) / _step;
    final index = s.floor() % _points.length;
    final next = (index + 1) % _points.length;
    return V3.lerp(_points[index], _points[next], s - s.floor());
  }

  /// Unit direction of travel (level, ignoring slopes) at a distance.
  V3 forward(double distance) {
    final ahead = centre(distance + 2) - centre(distance - 2);
    final level = V3(ahead.x, 0, ahead.z);
    return level.length > 0.0001 ? level.normalized : const V3(0, 0, -1);
  }

  /// Unit direction to the right of travel.
  V3 right(double distance) {
    final f = forward(distance);
    return V3(-f.z, 0, f.x);
  }

  /// A point on the road: `lateral` metres to the right of the centre.
  V3 position(double distance, double lateral) => centre(distance) + right(distance) * lateral;

  /// How sharply the road turns here (radians per metre, signed: + turns right).
  double curvature(double distance) {
    final a = forward(distance - 6), b = forward(distance + 6);
    final cross = a.x * b.z - a.z * b.x;
    return math.asin(cross.clamp(-1.0, 1.0)) / 12;
  }

  /// Evenly spaced centre points, for drawing the road and the mini-map.
  List<V3> samples(double metres) {
    final count = math.max(8, length ~/ metres);
    return [for (var i = 0; i < count; i++) centre(i * length / count)];
  }

  static List<V3> _catmullRom(List<V3> c, int samplesPerSpan) {
    final n = c.length;
    final result = <V3>[];
    for (var i = 0; i < n; i++) {
      final p0 = c[(i - 1 + n) % n], p1 = c[i], p2 = c[(i + 1) % n], p3 = c[(i + 2) % n];
      for (var s = 0; s < samplesPerSpan; s++) {
        final t = s / samplesPerSpan, t2 = t * t, t3 = t2 * t;
        final a = p1 * 2;
        final b = (p2 - p0) * t;
        final cc = (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2;
        final d = (p1 * 3 - p0 + p3 - p2 * 3) * t3;
        result.add((a + b + cc + d) * 0.5);
      }
    }
    return result;
  }
}
