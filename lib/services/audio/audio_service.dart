import 'package:audioplayers/audioplayers.dart';

import 'kids_voice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/models/app_language.dart';
import 'music_synthesizer.dart';
import 'sound_files.dart';

enum SoundEffect { correct, wrong, rewardPop, levelComplete, buttonTap, objectCaught, countdown }

/// Background music (a generated tune, looped), and the small taps of feedback the games give.
class AudioService extends ChangeNotifier {
  AudioService() {
    // The music steps back while ChihChi is talking, so every word is easy to hear.
    SpeechActivity.addListener(_onSpeech);
  }

  static const _musicVolume = 0.85;
  static const _musicVolumeUnderSpeech = 0.25;

  bool _musicEnabled = true;
  bool soundEnabled = true;
  bool voiceEnabled = true;
  bool hapticsEnabled = true;
  GameMusicTrack _musicTrack = GameMusicTrack.sunnyDay;

  AudioPlayer? _player;
  String? _loadedPath;
  GameMusicTrack? _loadedTrack;
  bool _loading = false;

  /// A game screen currently wants music (the setting alone is not enough).
  bool _wantsMusic = false;

  /// The Parent Zone is playing a tune so a grown-up can hear it before choosing.
  bool _isPreviewing = false;
  bool _isPlaying = false;
  bool get _shouldPlay => _isInForeground && (_isPreviewing || (_musicEnabled && _wantsMusic));

  /// Android keeps playing after the app leaves the screen (iOS stops it), so music and the voice
  /// pause while ChihChi is in the background and carry on when it comes back.
  bool _isInForeground = true;

  void setAppInForeground(bool inForeground) {
    if (_isInForeground == inForeground) return;
    _isInForeground = inForeground;
    if (inForeground) {
      _playIfReady();
    } else {
      _halt();
      KidsVoice.tts.stop().catchError((_) => 0);
    }
  }

  bool get musicEnabled => _musicEnabled;
  set musicEnabled(bool value) {
    if (value == _musicEnabled) return;
    _musicEnabled = value;
    value ? startBackgroundMusic() : stopBackgroundMusic();
    notifyListeners();
  }

  /// The tune the games play. Changing it swaps the music straight away if it is playing.
  GameMusicTrack get musicTrack => _musicTrack;
  set musicTrack(GameMusicTrack value) {
    if (value == _musicTrack) return;
    _musicTrack = value;
    _loadedPath = null;
    _loadedTrack = null;
    _isPlaying = false;
    _player?.stop();
    _playIfReady();
    notifyListeners();
  }

  // MARK: - Music

  void startBackgroundMusic() {
    if (!_musicEnabled) return;
    _wantsMusic = true;
    _playIfReady();
  }

  void stopBackgroundMusic() {
    _wantsMusic = false;
    if (!_isPreviewing) _halt();
  }

  /// Plays `track` (and makes it the chosen tune) until `endMusicPreview()`, even when no game
  /// is open or music is switched off.
  void previewMusic(GameMusicTrack track) {
    _isPreviewing = true;
    if (track == _musicTrack) {
      _playIfReady();
    } else {
      musicTrack = track;
    }
  }

  void endMusicPreview() {
    _isPreviewing = false;
    if (!_shouldPlay) _halt();
  }

  Future<void> _playIfReady() async {
    if (!_shouldPlay) return;
    if (_loadedPath == null || _loadedTrack != _musicTrack) {
      await _load();
      return;
    }
    if (_isPlaying) return;
    await SoundFiles.configureOnce();
    final player = _player ??= AudioPlayer(playerId: 'chihchi.music');
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_musicVolume);
      await player.play(DeviceFileSource(_loadedPath!));
      _isPlaying = true;
    } catch (_) {}
  }

  void _halt() {
    _isPlaying = false;
    _player?.pause();
  }

  /// Generates the chosen tune away from the main isolate, then starts it if something is still
  /// waiting to hear it.
  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    final track = _musicTrack;
    try {
      final samples = await compute(MusicSynthesizer.generate, track);
      final path = await SoundFiles.write('music_${track.name}', samples, MusicSynthesizer.sampleRate);
      // A different tune may have been picked while this one was being made.
      if (track == _musicTrack) {
        _loadedPath = path;
        _loadedTrack = track;
      }
    } catch (_) {
      // No music rather than a crash.
    }
    _loading = false;
    if (_loadedTrack == _musicTrack) {
      _playIfReady();
    } else if (_shouldPlay) {
      _load();
    }
  }

  void setMusicVolume(double volume) => _player?.setVolume(volume.clamp(0, 1));

  void _onSpeech(bool speaking) {
    if (_isPlaying) _player?.setVolume(speaking ? _musicVolumeUnderSpeech : _musicVolume);
  }

  // MARK: - Sound effects (haptic taps, as on iOS)

  void playEffect(SoundEffect effect) {
    if (!soundEnabled || !hapticsEnabled) return;
    switch (effect) {
      case SoundEffect.correct:
      case SoundEffect.levelComplete:
      case SoundEffect.rewardPop:
        HapticFeedback.mediumImpact();
      case SoundEffect.wrong:
        HapticFeedback.heavyImpact();
      case SoundEffect.buttonTap:
      case SoundEffect.countdown:
        HapticFeedback.lightImpact();
      case SoundEffect.objectCaught:
        HapticFeedback.mediumImpact();
    }
  }

  void playCorrectFeedback() => playEffect(SoundEffect.correct);
  void playWrongFeedback() => playEffect(SoundEffect.wrong);

  /// Kept for the few places that speak without the kids' voice. Games use `KidsSpeechService`.
  void speakText(String text, AppLanguage language) {}

  @override
  void dispose() {
    SpeechActivity.removeListener(_onSpeech);
    _player?.dispose();
    super.dispose();
  }
}
