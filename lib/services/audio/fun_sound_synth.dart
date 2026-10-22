import 'dart:math' as math;
import 'dart:typed_data';

/// Cartoon sound effects, synthesized — no audio files required.
enum FunSound { pew, pop, tada, fanfare, wahWah, boing, honk, squeak, whoosh, giggle }

enum _Wave { sine, square, triangle, saw }

class FunSoundSynth {
  static const sampleRate = 44100;
  static final _random = math.Random(7);

  static double _wave(_Wave wave, double phase) {
    switch (wave) {
      case _Wave.sine:
        return math.sin(2 * math.pi * phase);
      case _Wave.square:
        return phase < 0.5 ? 1 : -1;
      case _Wave.triangle:
        return 4 * (phase - 0.5).abs() - 1;
      case _Wave.saw:
        return 2 * phase - 1;
    }
  }

  static Float32List render(FunSound sound) => Float32List.fromList(_render(sound));

  static List<double> _render(FunSound sound) {
    switch (sound) {
      case FunSound.pew:
        return _tone(0.18, _Wave.square, 0.18, (t) => 1500 * math.pow(280.0 / 1500.0, t / 0.18).toDouble(),
            (t) => math.exp(-t * 10));
      case FunSound.pop:
        return _balloonPop();
      case FunSound.tada:
        return _arpeggio(const [523.25, 659.25, 783.99, 1046.5], 0.08, 0.35, 0.3);
      case FunSound.fanfare:
        return _arpeggio(const [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5], 0.12, 0.6, 0.3);
      case FunSound.wahWah:
        return _sadTrombone();
      case FunSound.boing:
        return _tone(0.55, _Wave.triangle, 0.4,
            (t) => 170 + 170 * (1 - math.exp(-t * 7)) + 70 * math.sin(2 * math.pi * 13 * t) * math.exp(-t * 4),
            (t) => math.min(t / 0.005, 1) * math.exp(-t * 4.5));
      case FunSound.honk:
        final beep = _mix(_tone(0.15, _Wave.square, 0.12, (_) => 392, (t) => _gate(t, 0.15)),
            _tone(0.15, _Wave.square, 0.12, (_) => 494, (t) => _gate(t, 0.15)));
        return [...beep, ..._silence(0.06), ...beep];
      case FunSound.squeak:
        final one = _tone(0.2, _Wave.square, 0.12,
            (t) => 1100 + 700 * math.sin(math.pi * t / 0.2) + 60 * math.sin(2 * math.pi * 30 * t), (t) => _gate(t, 0.2));
        return [...one, ..._silence(0.05), ...one];
      case FunSound.whoosh:
        return _whoosh();
      case FunSound.giggle:
        final out = <double>[];
        for (var index = 0; index < 5; index++) {
          final base = 950.0 - index * 70;
          out.addAll(_tone(0.07, _Wave.sine, 0.35, (t) => base + 90 * math.sin(2 * math.pi * 28 * t), (t) => _gate(t, 0.07)));
          out.addAll(_silence(0.045));
        }
        return out;
    }
  }

  static List<double> _tone(double duration, _Wave wave, double volume, double Function(double) frequency,
      double Function(double) envelope) {
    final count = (duration * sampleRate).toInt();
    final out = List<double>.filled(count, 0);
    var phase = 0.0;
    for (var index = 0; index < count; index++) {
      final t = index / sampleRate;
      phase += frequency(t) / sampleRate;
      phase -= phase.floorToDouble();
      out[index] = _wave(wave, phase) * envelope(t) * volume;
    }
    return out;
  }

  /// Short attack and release so notes don't click.
  static double _gate(double t, double duration) => math.max(0, math.min(t / 0.005, 1) * math.min((duration - t) / 0.03, 1));

  static List<double> _silence(double duration) => List<double>.filled((duration * sampleRate).toInt(), 0);

  static List<double> _mix(List<double> a, List<double> b) => List<double>.generate(
      math.max(a.length, b.length), (i) => (i < a.length ? a[i] : 0) + (i < b.length ? b[i] : 0));

  static List<double> _arpeggio(List<double> notes, double step, double hold, double volume) {
    final out = <double>[];
    for (var index = 0; index < notes.length; index++) {
      final hz = notes[index];
      final duration = index == notes.length - 1 ? hold : step;
      out.addAll(_mix(
        _tone(duration, _Wave.triangle, volume, (_) => hz, (t) => _gate(t, duration) * math.exp(-t * 2)),
        _tone(duration, _Wave.sine, volume * 0.4, (_) => hz * 2, (t) => _gate(t, duration) * math.exp(-t * 6)),
      ));
    }
    return out;
  }

  static List<double> _balloonPop() {
    final count = (0.12 * sampleRate).toInt();
    final out = List<double>.filled(count, 0);
    var phase = 0.0;
    for (var index = 0; index < count; index++) {
      final t = index / sampleRate;
      final noise = (_random.nextDouble() * 2 - 1) * math.exp(-t * 55);
      phase += 150 / sampleRate;
      final thump = math.sin(2 * math.pi * phase) * math.exp(-t * 30);
      out[index] = noise * 0.6 + thump * 0.5;
    }
    return out;
  }

  static List<double> _sadTrombone() {
    const notes = [(349.23, 0.2), (329.63, 0.2), (311.13, 0.55)];
    final out = <double>[];
    for (var index = 0; index < notes.length; index++) {
      final (hz, duration) = notes[index];
      final isLast = index == notes.length - 1;
      out.addAll(_tone(duration, _Wave.saw, 0.13, (t) => hz + (isLast ? 7 * math.sin(2 * math.pi * 6 * t) : 0),
          (t) => _gate(t, duration)));
    }
    return out;
  }

  static List<double> _whoosh() {
    const duration = 0.45;
    final count = (duration * sampleRate).toInt();
    final out = List<double>.filled(count, 0);
    var filtered = 0.0;
    for (var index = 0; index < count; index++) {
      final t = index / sampleRate;
      final shape = math.sin(math.pi * t / duration);
      final cutoff = 0.02 + 0.25 * shape;
      filtered += cutoff * ((_random.nextDouble() * 2 - 1) - filtered);
      out[index] = filtered * shape * 1.4;
    }
    return out;
  }
}
