import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../progress/child_profile_files.dart';

/// The child saying their own name: one short clip per child, kept only on this device, never
/// uploaded. Games play it wherever they would speak the child's name.
class ChildNameVoice {
  static const fileName = 'child-name-voice.m4a';

  static File file([Directory? directory]) => File('${(directory ?? ChildProfileFiles.activeDirectory).path}/$fileName');

  static bool hasSavedVoice([Directory? directory]) => file(directory).existsSync();

  static String? savedClipPath([Directory? directory]) {
    final f = file(directory);
    return f.existsSync() ? f.path : null;
  }

  /// Replaces any saved clip with the recording at `draft`.
  static Future<void> save(String draft, [Directory? directory]) async {
    final target = file(directory);
    await target.parent.create(recursive: true);
    if (await target.exists()) await target.delete();
    await File(draft).copy(target.path);
  }

  static Future<void> delete([Directory? directory]) async {
    try {
      await file(directory).delete();
    } catch (_) {}
  }
}

enum NameRecorderState { idle, recording, recorded, microphoneDenied }

/// Records and plays back the child's name. Hold to record (up to 4 seconds), then listen, then
/// keep it with `saveDraft()`. Very short taps are ignored.
class ChildNameVoiceRecorder extends ChangeNotifier {
  static const maxDuration = Duration(seconds: 4);
  static const minimumDuration = Duration(milliseconds: 400);

  NameRecorderState state = NameRecorderState.idle;

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  DateTime? _startedAt;
  Timer? _autoStop;
  String? _draftPath;

  void _set(NameRecorderState s) {
    state = s;
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (state == NameRecorderState.recording) return;
    await _player.stop();
    try {
      if (!await _recorder.hasPermission()) {
        _set(NameRecorderState.microphoneDenied);
        return;
      }
      final draft = '${Directory.systemTemp.path}/child-name-draft.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 22050, numChannels: 1),
        path: draft,
      );
      _draftPath = draft;
      _startedAt = DateTime.now();
      _set(NameRecorderState.recording);
      _autoStop = Timer(maxDuration, stopRecording);
    } catch (_) {
      _set(NameRecorderState.idle);
    }
  }

  Future<void> stopRecording() async {
    final startedAt = _startedAt;
    if (startedAt == null) return;
    _startedAt = null;
    _autoStop?.cancel();
    final length = DateTime.now().difference(startedAt);
    try {
      await _recorder.stop();
    } catch (_) {}
    if (length >= minimumDuration && _draftPath != null) {
      _set(NameRecorderState.recorded);
      playDraft();
    } else {
      _deleteDraft();
      _set(NameRecorderState.idle);
    }
  }

  void playDraft() {
    if (state != NameRecorderState.recorded || _draftPath == null) return;
    _play(_draftPath!);
  }

  void playSaved() {
    final path = ChildNameVoice.savedClipPath();
    if (path != null) _play(path);
  }

  /// Keeps the new recording as the child's name voice.
  Future<void> saveDraft() async {
    if (state != NameRecorderState.recorded || _draftPath == null) return;
    await ChildNameVoice.save(_draftPath!);
  }

  void discardDraft() {
    _player.stop();
    _deleteDraft();
    if (state == NameRecorderState.recorded) _set(NameRecorderState.idle);
  }

  void stopEverything() {
    if (state == NameRecorderState.recording) stopRecording();
    _player.stop();
  }

  void _play(String path) {
    _player.stop().then((_) => _player.play(DeviceFileSource(path))).catchError((_) {});
  }

  void _deleteDraft() {
    final path = _draftPath;
    if (path == null) return;
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoStop?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}
