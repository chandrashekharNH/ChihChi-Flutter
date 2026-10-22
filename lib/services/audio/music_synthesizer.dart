import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/localization/localized.dart';
import '../../domain/models/app_language.dart';

enum _Voice { bell, pad, beep }

/// The background tunes a grown-up can pick from in the Parent Zone. Each is written out as notes
/// below and turned into sound by `MusicSynthesizer` — there are no audio files.
enum GameMusicTrack {
  sunnyDay('☀️', 'Sunny Day'),
  twinkleStar('⭐', 'Twinkle Star'),
  parade('🥁', 'Parade'),
  jungleHop('🐒', 'Jungle Hop'),
  oceanWaves('🌊', 'Ocean Waves'),
  spaceBounce('🚀', 'Space Bounce'),
  candyWaltz('🍭', 'Candy Waltz'),
  rainbowRun('🌈', 'Rainbow Run'),
  sleepyClouds('☁️', 'Sleepy Clouds'),
  peacockDance('🦚', 'Peacock Dance');

  const GameMusicTrack(this.emoji, this._title);
  final String emoji;
  final String _title;

  String title(AppLanguage language) => L(_title).resolve(language);

  static GameMusicTrack? fromRaw(String? raw) {
    for (final t in values) {
      if (t.name == raw) return t;
    }
    return null;
  }

  /// Notes are written "C5" (half a beat) or "C5:2" (two beats); "R" is a rest. The bass line
  /// repeats until the melody ends, so the two always loop together.
  (double bpm, _Voice voice, String melody, String bass) get _score {
    switch (this) {
      case GameMusicTrack.sunnyDay:
        return (116, _Voice.bell, 'C5 E5 G5 A5 G5 E5 D5 C5:1 G4 A4 C5 E5 C5 A4 G4 G4:1', 'C3:2 G3:2 F3:2 G3:2');
      case GameMusicTrack.twinkleStar:
        return (96, _Voice.bell, 'C5:1 C5:1 G5:1 G5:1 A5:1 A5:1 G5:2 F5:1 F5:1 E5:1 E5:1 D5:1 D5:1 C5:2',
            'C3:2 E3:2 F3:2 C3:2 F3:2 C3:2 G3:2 C3:2');
      case GameMusicTrack.parade:
        return (120, _Voice.bell, 'G4 G4 B4 D5 G5:1 D5:1 E5 E5 D5 B4 A4:1 R:1 A4 A4 C5 E5 D5:1 B4:1 A4 B4 A4 F#4 G4:1 R:1',
            'G2:1 D3:1');
      case GameMusicTrack.jungleHop:
        return (126, _Voice.beep, 'A4 C5 D5 E5 D5 C5 A4:1 G4 A4 C5 A4 G4 E4 G4:1 A4 C5 E5 G5 E5 D5 C5:1 D5 C5 A4 G4 A4:1 R:1',
            'A2:1 E3:1 A2:1 G2:1');
      case GameMusicTrack.oceanWaves:
        return (80, _Voice.pad, 'F4 A4 C5 F5 C5 A4 F4 A4 Bb4 D5 F5 D5 Bb4 D5 F5:1 C5 E5 G5 E5 C5 E5 G5:1 F4 A4 C5 F5 C5:1 F5:1',
            'F2:4 Bb2:4 C3:4 F2:4');
      case GameMusicTrack.spaceBounce:
        return (132, _Voice.beep, 'D5 D6 A5 D6 B5 A5 F#5:1 E5 E6 B5 E6 A5 F#5 E5:1 D5 F#5 A5 B5 D6 B5 A5:1 F#5 E5 D5 E5 D5:1 R:1',
            'D3 D3 A2 A2 B2 B2 A2 A2');
      case GameMusicTrack.candyWaltz:
        return (138, _Voice.bell,
            'E5:1 G5 E5 G5:1 F5:1 A5 F5 A5:1 G5:1 B5 G5 D6:1 C6:2 R:1 E5:1 G5 E5 C6:1 A5:1 F5 A5 C6:1 B5:1 G5 D5 G5:1 C5:2 R:1',
            'C3:1 G3:1 G3:1 F3:1 A3:1 A3:1 G3:1 B3:1 B3:1 C3:1 G3:1 G3:1');
      case GameMusicTrack.rainbowRun:
        return (140, _Voice.bell, 'G4 A4 B4 D5 E5 D5 B4 D5 E5 G5 E5 D5 B4 A4 G4:1 A4 B4 D5 E5 G5 E5 D5 B4 A4 B4 A4 G4 E4 G4 G4:1',
            'G2 G3 G2 G3 E2 E3 E2 E3 C3 C4 C3 C4 D3 D4 D3 D4');
      case GameMusicTrack.sleepyClouds:
        return (72, _Voice.pad, 'Eb4:1 G4:1 Bb4:1 G4:1 Ab4:1 C5:1 Bb4:2 G4:1 Bb4:1 Eb5:1 Bb4:1 Ab4:1 G4:1 Eb4:2',
            'Eb3:4 Ab2:4 Eb3:4 Bb2:2 Eb3:2');
      case GameMusicTrack.peacockDance:
        return (108, _Voice.pad, 'C5 D5 E5 G5 B5:1 G5 E5 D5 E5 G5 E5 C5:1 R:1 G5 B5 C6 B5 G5:1 E5 G5 D5 E5 D5 B4 C5:2', 'C3:2 G3:2');
    }
  }
}

/// Generates a looping tune — no audio files required. Pure sample generation, safe on an isolate.
class MusicSynthesizer {
  static const sampleRate = 44100;

  /// Returns a seamlessly looping mono buffer of one tune (a few seconds long).
  static Float32List generate(GameMusicTrack track) {
    final score = track._score;
    final beat = 60.0 / score.$1;
    final melody = notes(score.$3);
    final totalBeats = melody.fold<double>(0, (s, n) => s + n.$2);
    if (totalBeats <= 0) return Float32List(0);

    final pattern = notes(score.$4);
    final bass = <(double, double)>[];
    var filled = 0.0;
    while (filled < totalBeats && pattern.isNotEmpty) {
      for (final note in pattern) {
        if (filled >= totalBeats) break;
        final beats = math.min(note.$2, totalBeats - filled);
        bass.add((note.$1, beats));
        filled += beats;
      }
    }

    final frames = (sampleRate * totalBeats * beat).toInt();
    final out = Float32List(frames);
    switch (score.$2) {
      case _Voice.bell:
        _render(melody, beat, 0.38, 0.008, 0.35, 0.25, const [1.0, 0.45, 0.18, 0.07], out);
      case _Voice.pad:
        _render(melody, beat, 0.32, 0.06, 0.2, 0.7, const [1.0, 0.3, 0.1], out);
      case _Voice.beep:
        _render(melody, beat, 0.26, 0.004, 0.3, 0.45, const [1.0, 0.0, 0.33, 0.0, 0.2], out);
    }
    _render(bass, beat, 0.18, 0.04, 0.0, 0.90, const [1.0, 0.5, 0.12], out);
    for (var i = 0; i < frames; i++) {
      out[i] = out[i].clamp(-1.0, 1.0);
    }
    return out;
  }

  /// Reads "C5 F#4:1 Bb3:2 R:1" into pitches and lengths. A rest is 0 Hz; anything unreadable is skipped.
  static List<(double hz, double beats)> notes(String text) {
    const semitones = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
    final result = <(double, double)>[];
    for (final token in text.split(' ').where((t) => t.isNotEmpty)) {
      final parts = token.split(':');
      final name = parts.first;
      final beats = parts.length > 1 ? (double.tryParse(parts[1]) ?? 0.5) : 0.5;
      if (name == 'R') {
        result.add((0, beats));
        continue;
      }
      var semitone = semitones[name[0]];
      final octave = int.tryParse(name[name.length - 1]);
      if (semitone == null || octave == null) continue;
      if (name.contains('#')) semitone += 1;
      if (name.substring(1).contains('b')) semitone -= 1;
      final midi = 12 * (octave + 1) + semitone;
      result.add((440 * math.pow(2, (midi - 69) / 12).toDouble(), beats));
    }
    return result;
  }

  static void _render(List<(double, double)> notes, double beat, double amplitude, double attack, double decayRatio,
      double sustainLevel, List<double> harmonics, Float32List out) {
    var cursor = 0.0;
    for (final (hz, beats) in notes) {
      final noteDur = beats * beat;
      final startFrame = (cursor * sampleRate).toInt();
      final noteFrames = (noteDur * sampleRate).toInt();
      final attackFrames = (attack * sampleRate).toInt();
      final decayFrames = (noteDur * decayRatio * sampleRate).toInt();
      final releaseFrames = math.min(0.06 * sampleRate, noteFrames * 0.15).toInt();
      if (hz > 0) {
        for (var f = 0; f < noteFrames; f++) {
          final global = startFrame + f;
          if (global >= out.length) break;
          final t = f / sampleRate;
          double env;
          if (f < attackFrames) {
            env = f / math.max(1, attackFrames);
          } else if (decayFrames > 0 && f < attackFrames + decayFrames) {
            env = 1.0 - (f - attackFrames) / decayFrames * (1.0 - sustainLevel);
          } else if (f > noteFrames - releaseFrames) {
            env = sustainLevel * (noteFrames - f) / math.max(1, releaseFrames);
          } else {
            env = sustainLevel;
          }
          var sample = 0.0;
          for (var idx = 0; idx < harmonics.length; idx++) {
            final relAmp = harmonics[idx];
            if (relAmp == 0) continue;
            sample += relAmp * math.sin(2.0 * math.pi * hz * (idx + 1) * t);
          }
          out[global] += sample * amplitude * math.max(0, env);
        }
      }
      cursor += noteDur;
    }
  }
}
