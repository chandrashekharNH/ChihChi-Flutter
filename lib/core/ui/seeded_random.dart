/// A small repeatable random sequence (xorshift), so scenery lands in the same place every time.
class SeededRandom {
  SeededRandom(int seed) : _state = (seed * 0x9E3779B97F4A7C15) | 1;

  int _state;

  /// 0 ..< 1
  double next() {
    _state ^= _state << 13;
    _state ^= _state >>> 7;
    _state ^= _state << 17;
    return ((_state >>> 1) % 1000000) / 1000000;
  }
}
