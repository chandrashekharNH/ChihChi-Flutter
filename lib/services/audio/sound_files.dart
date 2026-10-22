import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import 'wav.dart';

/// Generated sounds are written once as WAV files in the app's temporary folder, because the
/// players on both platforms play files most reliably.
class SoundFiles {
  static Directory? _folder;

  static Future<String> write(String name, Float32List samples, int sampleRate) async {
    _folder ??= await Directory('${(await getTemporaryDirectory()).path}/chihchi_sounds').create(recursive: true);
    final file = File('${_folder!.path}/$name.wav');
    await file.writeAsBytes(wavBytes(samples, sampleRate), flush: true);
    return file.path;
  }

  /// ChihChi's sounds play alongside other apps' audio and respect the silent switch, as on iOS.
  static Future<void> configureOnce() async {
    if (_configured) return;
    _configured = true;
    try {
      await AudioPlayer.global.setAudioContext(AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
        respectSilence: true,
      ).build());
    } catch (_) {}
  }

  static bool _configured = false;
}

/// Tells the rest of the app when ChihChi is talking, so the music can step back.
class SpeechActivity {
  static final List<void Function(bool speaking)> _listeners = [];

  static void addListener(void Function(bool speaking) listener) => _listeners.add(listener);
  static void removeListener(void Function(bool speaking) listener) => _listeners.remove(listener);

  static void started() {
    for (final l in List.of(_listeners)) {
      l(true);
    }
  }

  static void ended() {
    for (final l in List.of(_listeners)) {
      l(false);
    }
  }
}
