import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/app_language.dart';
import 'sound_files.dart';

/// What matters about an installed voice when choosing.
class VoiceOption {
  const VoiceOption({
    required this.identifier,
    required this.name,
    required this.language,
    required this.quality,
    this.isNovelty = false,
    this.gender = 0,
  });

  final String identifier;
  final String name;
  final String language;

  /// 1 basic, 2 enhanced, 3 premium.
  final int quality;
  final bool isNovelty;

  /// 1 male, 2 female, 0 unknown.
  final int gender;

  /// Reads one entry of `FlutterTts.getVoices` (iOS and Android describe voices differently).
  static VoiceOption? fromPlatform(Object? raw) {
    if (raw is! Map) return null;
    final name = '${raw['name'] ?? ''}';
    final locale = '${raw['locale'] ?? ''}'.replaceAll('_', '-');
    if (name.isEmpty || locale.isEmpty) return null;
    final qualityText = '${raw['quality'] ?? ''}'.toLowerCase();
    final quality = qualityText.contains('premium') || qualityText.contains('very high')
        ? 3
        : qualityText.contains('enhanced') || qualityText.contains('high')
            ? 2
            : 1;
    final genderText = '${raw['gender'] ?? ''}'.toLowerCase();
    final gender = genderText == 'male' ? 1 : (genderText == 'female' ? 2 : 0);
    final identifier = '${raw['identifier'] ?? name}';
    final networkOnly = '${raw['network_required'] ?? ''}' == '1' || name.contains('network');
    return VoiceOption(
      identifier: identifier,
      name: name,
      language: locale,
      quality: networkOnly ? 0 : quality,
      isNovelty: identifier.contains('novelty'),
      gender: gender,
    );
  }
}

/// The six children who can be the games' voice: three girls and three boys, each with their own
/// height of voice, pace and liveliness.
enum KidsVoiceCharacter {
  mia('Mia', '🎀', 380, 1, 1.06),
  tara('Tara', '🌸', 520, 1.07, 1.14),
  anu('Anu', '🦋', 240, 0.94, 1.0),
  arjun('Arjun', '⚽', 180, 1, 1.04),
  kabir('Kabir', '🚀', 330, 1.07, 1.12),
  rohan('Rohan', '🦁', 60, 0.94, 0.96);

  const KidsVoiceCharacter(this.displayName, this.emoji, this._centsAboveWoman, this.pace, this.liveliness);

  final String displayName;
  final String emoji;

  /// How many hundredths of a note higher than a woman's voice this child sounds.
  final double _centsAboveWoman;

  /// Speaking speed against the usual pace.
  final double pace;

  /// How much the voice rises and falls.
  final double liveliness;

  bool get isGirl => this == mia || this == tara || this == anu;
  int get gender => isGirl ? 2 : 1;

  /// A man's voice starts lower, so it is lifted further to reach the same child.
  double cents(int voiceGender) => voiceGender == 1 ? _centsAboveWoman + 380 : _centsAboveWoman;

  /// The speech pitch for the platform voice (1 = unchanged; the engines accept 0.5…2).
  double pitch(int voiceGender) => (math.pow(2, cents(voiceGender) / 1200) * liveliness).clamp(0.5, 2.0).toDouble();

  static KidsVoiceCharacter? fromRaw(String? raw) {
    for (final c in values) {
      if (c.name == raw) return c;
    }
    return null;
  }
}

/// Picks the voice the games speak with: the most natural one installed for the language.
class KidsVoice {
  static const _characterKey = 'kidsVoiceCharacter';
  static KidsVoiceCharacter _character = KidsVoiceCharacter.mia;
  static List<VoiceOption> _installed = [];
  static final FlutterTts tts = FlutterTts();
  static bool _ready = false;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _character = KidsVoiceCharacter.fromRaw(prefs.getString(_characterKey)) ?? KidsVoiceCharacter.mia;
    await _prepareEngine();
    await refreshInstalledVoices();
  }

  static Future<void> _prepareEngine() async {
    if (_ready) return;
    _ready = true;
    try {
      if (Platform.isIOS) {
        await tts.setSharedInstance(true);
        await tts.setIosAudioCategory(IosTextToSpeechAudioCategory.ambient,
            [IosTextToSpeechAudioCategoryOptions.mixWithOthers], IosTextToSpeechAudioMode.defaultMode);
      }
      await tts.awaitSpeakCompletion(false);
      tts.setStartHandler(SpeechActivity.started);
      tts.setCompletionHandler(SpeechActivity.ended);
      tts.setCancelHandler(SpeechActivity.ended);
      tts.setErrorHandler((_) => SpeechActivity.ended());
    } catch (_) {}
  }

  /// Looked up again when a grown-up returns from the phone's settings, so a newly downloaded
  /// voice is used at once.
  static Future<void> refreshInstalledVoices() async {
    try {
      final voices = await tts.getVoices;
      if (voices is List) _installed = voices.map(VoiceOption.fromPlatform).whereType<VoiceOption>().toList();
    } catch (_) {
      _installed = [];
    }
  }

  static KidsVoiceCharacter character() => _character;

  static Future<void> setCharacter(KidsVoiceCharacter character) async {
    _character = character;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_characterKey, character.name);
  }

  static List<String> languageCodes(AppLanguage language) => language.voiceCodes;

  /// The best option: a voice of the chosen kind if the language has one, then highest quality,
  /// then the preferred accent. Joke voices and the old robotic families are never chosen.
  static VoiceOption? best(List<VoiceOption> options, List<String> languageCodes,
      [KidsVoiceCharacter character = KidsVoiceCharacter.mia]) {
    bool matchesLanguage(VoiceOption o) =>
        languageCodes.any((code) => o.language.toLowerCase() == code.toLowerCase());
    final usable = options
        .where((o) =>
            matchesLanguage(o) &&
            !o.isNovelty &&
            o.quality > 0 &&
            !o.identifier.contains('eloquence') &&
            !o.identifier.contains('speech.synthesis.voice'))
        .toList();
    final matching = usable.where((o) => o.gender == character.gender).toList();
    final pool = matching.isEmpty ? usable : matching;
    if (pool.isEmpty) return null;
    int rank(VoiceOption o) {
      final i = languageCodes.indexWhere((c) => c.toLowerCase() == o.language.toLowerCase());
      return i < 0 ? 1 << 30 : i;
    }

    pool.sort((a, b) {
      if (a.quality != b.quality) return b.quality.compareTo(a.quality);
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return a.name.compareTo(b.name);
    });
    return pool.first;
  }

  static VoiceOption? installedBest(AppLanguage language, [KidsVoiceCharacter? character]) =>
      best(_installed, languageCodes(language), character ?? _character);

  /// Whether this phone has any voice for `language` (Parent Controls warns when it doesn't).
  static bool hasVoice(AppLanguage language) => installedBest(language) != null;
}
