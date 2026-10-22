import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import '../../core/localization/localized.dart';
import '../../domain/models/app_language.dart';
import 'child_name_voice.dart';
import 'kids_voice.dart';

/// What the child does to the right answer in a game.
enum SpeechAction { catchIt, pop }

/// Soft, child-friendly speech used by the learning games.
class KidsSpeechService {
  KidsSpeechService({String childName = '', bool Function()? isEnabled, String? nameClipPath})
      : childName = childName.trim(),
        _isEnabled = isEnabled ?? (() => true),
        _nameClip = nameClipPath ?? ChildNameVoice.savedClipPath();

  /// The child's name. Said only at milestones (a batch mastered, a destination reached), where
  /// the caller asks for it with `usingName: true` — never in everyday instructions or praise.
  final String childName;

  /// Read before every line, so turning Voice off in settings silences speech right away.
  final bool Function() _isEnabled;

  /// The child saying their own name. When present it is played in place of the spoken name.
  final String? _nameClip;
  AudioPlayer? _clipPlayer;
  int _generation = 0;

  void stop() {
    _generation++;
    _clipPlayer?.stop();
    KidsVoice.tts.stop();
  }

  void dispose() {
    stop();
    _clipPlayer?.dispose();
  }

  void speakLetterInstruction(String letter, String word, AppLanguage language, {bool usingName = false}) {
    final greeting = usingName ? _greeting : '';
    _speak(L('{0}{1} for {2}', args: [greeting, letter, word]).resolve(language), language, withName: usingName);
  }

  void speakWordInstruction(String word, AppLanguage language, {SpeechAction action = SpeechAction.catchIt}) {
    _speak(
        action == SpeechAction.pop
            ? L('Pop {0}!', args: [word]).resolve(language)
            : L('Catch {0}!', key: 'Catch {0}!#2', args: [word]).resolve(language),
        language);
  }

  /// A right answer gets short praise and nothing else: the child already knows what they
  /// caught, and a word tacked on the end ("Well done! A!") only confuses.
  void speakPraise(AppLanguage language) => _speak(L('Well done!', key: 'Well done!#2').resolve(language), language);

  void speakCorrect(String word, AppLanguage language) => speakPraise(language);

  void speakEncouragement(AppLanguage language) => _speak(L('Good try! Try again!').resolve(language), language);

  void speakLevelComplete(AppLanguage language) => _speak(L('Amazing! Level complete!').resolve(language), language);

  void speakGameOver(AppLanguage language) => _speak(L("Great playing! Let's try again!").resolve(language), language);

  /// Speaks any already-localized line. Pass `usingName: true` only for a milestone: the line
  /// then starts with the child's name.
  void speakLine(String text, AppLanguage language, {bool usingName = false}) =>
      _speak(usingName ? '$_greeting$text' : text, language, withName: usingName);

  void speakAskName(AppLanguage language) => _speak(L('Hello! What is your name?').resolve(language), language);

  void speakWelcome(AppLanguage language) =>
      _speak(L("Hi{0}! Let's play and learn!", args: [_nameSuffix]).resolve(language), language, withName: true);

  /// Says one short line, so a grown-up can hear the voice the games use.
  void speakSample(AppLanguage language) =>
      _speak(L('Hello! A for apple. Well done!').resolve(language), language);

  /// ", Riya" — or nothing when no name is saved yet, or when the child's recording says it.
  String get _nameSuffix => childName.isEmpty || _nameClip != null ? '' : ', $childName';

  /// "Riya, " before an instruction — or nothing when no name is saved yet, or when the
  /// child's recording says it.
  String get _greeting => childName.isEmpty || _nameClip != null ? '' : '$childName, ';

  /// Lines that include the child's name start with their own recording, when there is one.
  Future<void> _speak(String text, AppLanguage language, {bool withName = false}) async {
    if (text.isEmpty || !_isEnabled()) return;
    stop();
    final token = _generation;
    final clip = _nameClip;
    if (withName && clip != null && File(clip).existsSync()) {
      final player = _clipPlayer ??= AudioPlayer();
      try {
        final done = player.onPlayerComplete.first;
        await player.play(DeviceFileSource(clip));
        await done.timeout(const Duration(seconds: 5), onTimeout: () {});
        await Future<void>.delayed(const Duration(milliseconds: 150));
      } catch (_) {}
      if (token != _generation) return;
    }
    await _say(spoken(text, language), language);
  }

  static Future<void> _say(String text, AppLanguage language) async {
    final tts = KidsVoice.tts;
    final character = KidsVoice.character();
    final voice = KidsVoice.installedBest(language, character);
    try {
      if (voice != null) {
        await tts.setVoice({'name': voice.name, 'locale': voice.language, 'identifier': voice.identifier});
      } else {
        // No voice for this language on the device: an Indian English voice reads it as best it can.
        await tts.setLanguage(language.voiceCodes.isNotEmpty ? language.voiceCodes.first : 'en-IN');
      }
      // Clear and unhurried, but not dragging: the natural voices can go a touch quicker.
      final isNatural = (voice?.quality ?? 1) > 1;
      await tts.setSpeechRate(0.5 * (isNatural ? 0.9 : 0.84) * character.pace);
      await tts.setPitch(character.pitch(voice?.gender ?? 2));
      await tts.setVolume(1);
      await tts.speak(text);
    } catch (_) {}
  }

  /// The text as the voice should say it. English voices read a lone capital "A" as the word
  /// "a" ("uh"), so wherever it is the letter it is spelled out: "ay for apple", "catch the
  /// letter ay". An "A" that starts a sentence as a word ("A cat…") is left alone.
  static String spoken(String text, AppLanguage language) {
    if (language != AppLanguage.english) return text;
    final pattern = RegExp(r'\bA\b');
    final buffer = StringBuffer();
    var last = 0;
    for (final match in pattern.allMatches(text)) {
      final before = text.substring(0, match.start).trimRight();
      final after = text.substring(match.end);
      final startsSentence = before.isEmpty || '.!?'.contains(before[before.length - 1]);
      final nextWord = RegExp(r'[A-Za-z]+').firstMatch(after)?.group(0) ?? '';
      final followedByWord = after.startsWith(' ') && nextWord.isNotEmpty;
      final isArticle =
          startsSentence && followedByWord && !['for', 'is', 'says', 'and', 'or'].contains(nextWord.toLowerCase());
      buffer.write(text.substring(last, match.start));
      buffer.write(isArticle ? 'A' : 'ay');
      last = match.end;
    }
    buffer.write(text.substring(last));
    return buffer.toString();
  }
}
