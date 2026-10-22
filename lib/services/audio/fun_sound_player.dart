import 'package:audioplayers/audioplayers.dart';

import 'fun_sound_synth.dart';
import 'sound_files.dart';

/// Plays short synthesized effects on a small pool of players so sounds can overlap.
class FunSoundPlayer {
  FunSoundPlayer({int voices = 6}) {
    for (var i = 0; i < voices; i++) {
      _players.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
    }
    _prepare();
  }

  final List<AudioPlayer> _players = [];
  int _next = 0;
  bool _stopped = false;

  /// Each sound is rendered once per app run and shared by every player.
  static final Map<FunSound, String> _paths = {};
  static Future<void>? _preparing;

  Future<void> _prepare() => _preparing ??= () async {
        await SoundFiles.configureOnce();
        for (final sound in FunSound.values) {
          _paths[sound] = await SoundFiles.write('fx_${sound.name}', FunSoundSynth.render(sound), FunSoundSynth.sampleRate);
        }
      }();

  void play(FunSound sound) {
    if (_stopped || _players.isEmpty) return;
    final path = _paths[sound];
    if (path == null) return;
    final player = _players[_next];
    _next = (_next + 1) % _players.length;
    player.stop().then((_) => player.play(DeviceFileSource(path), volume: 0.9)).catchError((_) {});
  }

  void stop() {
    _stopped = true;
    for (final p in _players) {
      p.stop();
      p.dispose();
    }
    _players.clear();
  }
}
