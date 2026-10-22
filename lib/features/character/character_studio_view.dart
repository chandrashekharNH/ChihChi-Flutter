import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/localization/localized.dart';
import '../../core/ui/kid_text.dart';
import '../../core/ui/palette.dart';
import '../../data/storage/player_progress.dart';
import '../../domain/models/app_language.dart';
import '../../services/audio/audio_service.dart';
import '../../services/progress/progress_service.dart';
import 'avatar_appearance.dart';
import 'character_photo_flow.dart';
import 'character_text.dart';
import 'character_view.dart';
import 'measured_face.dart';
import 'player_character_store.dart';

/// First launch shows "Maybe Later"; My Character (from Home) shows the ChihChi switch.
enum StudioMode { onboarding, editing }

enum _Category {
  kid('🧒'),
  skin('🎨'),
  hair('💇'),
  face('😊'),
  glasses('👓'),
  outfit('👕'),
  hat('🧢'),
  extras('🎒');

  const _Category(this.icon);
  final String icon;

  Localized get title => switch (this) {
        kid => CharacterText.boyOrGirl,
        skin => CharacterText.skin,
        hair => CharacterText.hair,
        face => CharacterText.face,
        glasses => CharacterText.glasses,
        outfit => CharacterText.outfit,
        hat => CharacterText.hat,
        extras => CharacterText.extras,
      };
}

final _purple = rgb(0.35, 0.2, 0.7);

/// Copies every choice of `source` into `target`.
void _copyInto(AvatarAppearance target, AvatarAppearance source) {
  final s = source.copy();
  target
    ..skinTone = s.skinTone
    ..faceShape = s.faceShape
    ..hairStyle = s.hairStyle
    ..hairColor = s.hairColor
    ..eyes = s.eyes
    ..eyeColor = s.eyeColor
    ..brows = s.brows
    ..glasses = s.glasses
    ..top = s.top
    ..topColor = s.topColor
    ..bottoms = s.bottoms
    ..bottomsColor = s.bottomsColor
    ..shoesColor = s.shoesColor
    ..hat = s.hat
    ..backpack = s.backpack
    ..measured = s.measured;
}

/// Make or change the child's character: a big preview that reacts to every pick, simple picture
/// cards per category, "Surprise me!", "From my photo", and Use / Skip. Nothing is saved until
/// "Use This Character" — every change is a draft.
class CharacterStudioView extends StatefulWidget {
  const CharacterStudioView({super.key, required this.mode, required this.start, required this.onClose});
  final StudioMode mode;
  final AvatarAppearance start;
  final VoidCallback onClose;

  @override
  State<CharacterStudioView> createState() => _CharacterStudioViewState();
}

class _CharacterStudioViewState extends State<CharacterStudioView> {
  late AvatarAppearance _draft = widget.start.copy();
  _Category _category = _Category.hair;
  int _cue = 0;
  CharacterAnimation _animation = CharacterAnimation.wave;

  /// The face measured from the child's photo, kept so they can switch back to it.
  late MeasuredFace? _photoFace = widget.start.measured;

  @override
  void initState() {
    super.initState();
    // Not chosen yet: start on the boy / girl cards.
    if (context.read<ProgressService>().progress.childGender == null) _category = _Category.kid;
  }

  /// Every pick shows straight away: the character reacts with a little move.
  void _update(void Function(AvatarAppearance) change) {
    context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
    setState(() {
      final next = _draft.copy();
      change(next);
      _draft = next;
      const reactions = [
        CharacterAnimation.wave,
        CharacterAnimation.jump,
        CharacterAnimation.celebrate,
        CharacterAnimation.collect,
        CharacterAnimation.dance,
      ];
      _animation = reactions[_cue % reactions.length];
      _cue += 1;
    });
  }

  void _close() {
    context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
    widget.onClose();
  }

  Future<void> _photo() async {
    context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
    final hinted = await Navigator.of(context).push<AvatarAppearance>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => CharacterPhotoFlow(start: _draft)),
    );
    if (hinted == null || !mounted) return;
    _photoFace = hinted.measured ?? _photoFace;
    _update((look) => _copyInto(look, hinted));
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<AppState>().language;
    final progress = context.watch<ProgressService>();
    final store = context.watch<PlayerCharacterStore>();
    final name = progress.progress.childName;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [rgb(0.55, 0.78, 1), rgb(0.72, 0.6, 1)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Semantics(
                  button: true,
                  label: CharacterText.skip.resolve(language),
                  child: GestureDetector(
                    onTap: _close,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      name.isEmpty ? CharacterText.myCharacter.resolve(language) : CharacterText.charactersName(name).resolve(language),
                      maxLines: 1,
                      style: kid(22, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 44),
              ]),
            ),
            SizedBox(
              height: 300,
              child: Stack(children: [
                Positioned.fill(
                  child: Semantics(
                    label: CharacterText.myCharacter.resolve(language),
                    child: CharacterSceneView(appearance: _draft, animation: _animation, cue: _cue),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 4,
                  child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 6, children: [
                    _chip('🎲 ${CharacterText.surpriseMe.resolve(language)}',
                        () => _update((look) => _copyInto(look, AvatarAppearance.randomLook()))),
                    _chip('📸 ${CharacterText.fromMyPhoto.resolve(language)}', _photo),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final item in _Category.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Semantics(
                        button: true,
                        selected: _category == item,
                        child: GestureDetector(
                          onTap: () {
                            context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
                            setState(() => _category = item);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 70,
                            decoration: BoxDecoration(
                              color: _category == item ? Colors.white : Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(item.icon, style: const TextStyle(fontSize: 24)),
                              Text(item.title.resolve(language),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: kid(11, weight: FontWeight.w800, color: _category == item ? _purple : Colors.white)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Column(children: _options(language, progress)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Column(children: [
                Semantics(
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      context.read<AppState>().audioService.playEffect(SoundEffect.buttonTap);
                      store.save(_draft);
                      widget.onClose();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 5, offset: Offset(0, 3))],
                      ),
                      child: Text(CharacterText.useThisCharacter.resolve(language),
                          textAlign: TextAlign.center, style: kid(22, color: Colors.white)),
                    ),
                  ),
                ),
                if (widget.mode == StudioMode.onboarding)
                  _secondary(CharacterText.maybeLater.resolve(language), _close)
                else if (store.isEnabled)
                  _secondary(CharacterText.turnOff.resolve(language), () {
                    store.turnOff();
                    widget.onClose();
                  })
                else if (store.hasCharacter)
                  _secondary(CharacterText.turnOn.resolve(language), () {
                    store.turnOn();
                    widget.onClose();
                  }),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _secondary(String title, VoidCallback onTap) =>
      TextButton(onPressed: onTap, child: Text(title, style: kid(17, weight: FontWeight.w700, color: Colors.white)));

  Widget _chip(String title, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Text(title, style: kid(15, color: _purple)),
        ),
      );

  List<Widget> _options(AppLanguage language, ProgressService progress) {
    switch (_category) {
      case _Category.kid:
        return [
          Row(children: [
            for (final gender in ChildGender.values) ...[
              if (gender != ChildGender.values.first) const SizedBox(width: 10),
              Expanded(child: _genderChoice(gender, language, progress)),
            ],
          ]),
        ];
      case _Category.skin:
        return [
          ..._faceSwitch(language),
          _colours(SkinTone.values, (l) => l.skinTone, (l, v) => l.skinTone = v, (v) => v.color),
          // A measured face brings its own shape.
          if (_draft.measured == null)
            _cards<FaceShape>(FaceShape.values, (l) => l.faceShape, (l, v) => l.faceShape = v, (shape) {
              return Container(
                width: shape == FaceShape.wide ? 40 : (shape == FaceShape.oval ? 28 : 34),
                height: shape == FaceShape.oval ? 40 : (shape == FaceShape.wide ? 30 : 34),
                decoration: BoxDecoration(color: _draft.skinTone.color, borderRadius: BorderRadius.circular(40)),
              );
            }),
        ];
      case _Category.hair:
        return [
          _emojis(HairStyle.values, (l) => l.hairStyle, (l, v) => l.hairStyle = v, _hairIcon),
          _colours(HairColor.values, (l) => l.hairColor, (l, v) => l.hairColor = v, (v) => v.color),
        ];
      case _Category.face:
        return [
          ..._faceSwitch(language),
          _emojis(Eyes.values, (l) => l.eyes, (l, v) => l.eyes = v, _eyesIcon),
          _colours(EyeColor.values, (l) => l.eyeColor, (l, v) => l.eyeColor = v, (v) => v.color),
          _emojis(Brows.values, (l) => l.brows, (l, v) => l.brows = v, _browsIcon),
        ];
      case _Category.glasses:
        return [_emojis(Glasses.values, (l) => l.glasses, (l, v) => l.glasses = v, _glassesIcon)];
      case _Category.outfit:
        return [
          _emojis(Top.values, (l) => l.top, (l, v) => l.top = v, _topIcon),
          _colours(Outfit.values, (l) => l.topColor, (l, v) => l.topColor = v, (v) => v.color),
          if (_draft.top != Top.dress) ...[
            _emojis(Bottoms.values, (l) => l.bottoms, (l, v) => l.bottoms = v, _bottomsIcon),
            _colours(Outfit.values, (l) => l.bottomsColor, (l, v) => l.bottomsColor = v, (v) => v.color),
          ],
          _colours(Outfit.values, (l) => l.shoesColor, (l, v) => l.shoesColor = v, (v) => v.color, icon: '👟'),
        ];
      case _Category.hat:
        return [_emojis(Hat.values, (l) => l.hat, (l, v) => l.hat = v, _hatIcon)];
      case _Category.extras:
        return [_emojis<bool>(const [false, true], (l) => l.backpack, (l, v) => l.backpack = v, (v) => v ? '🎒' : '🚫')];
    }
  }

  /// Boy or girl: remembered for this child, and gives the character matching hair and clothes.
  Widget _genderChoice(ChildGender gender, AppLanguage language, ProgressService progress) {
    final selected = progress.progress.childGender == gender;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () {
          progress.setChildGender(gender);
          _update((look) => _copyInto(look, look.styled(gender)));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? Colors.yellow : Colors.transparent, width: 4),
          ),
          child: Column(children: [
            Text(gender.emoji, style: const TextStyle(fontSize: 44)),
            Text((gender == ChildGender.boy ? CharacterText.boy : CharacterText.girl).resolve(language),
                style: kid(17, color: _purple)),
          ]),
        ),
      ),
    );
  }

  /// The child's own measured face or the standard one — offered once a photo has been taken.
  List<Widget> _faceSwitch(AppLanguage language) {
    if (_photoFace == null) return const [];
    Widget choice(String title, bool isOn) {
      final selected = (_draft.measured != null) == isOn;
      return Expanded(
        child: GestureDetector(
          onTap: () => _update((l) => l.measured = isOn ? _photoFace : null),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? Colors.yellow : Colors.transparent, width: 4),
            ),
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(title, maxLines: 1, style: kid(16, color: _purple))),
          ),
        ),
      );
    }

    return [
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Row(children: [
          choice('📸 ${CharacterText.photoFace.resolve(language)}', true),
          const SizedBox(width: 10),
          choice('😊 ${CharacterText.cartoonFace.resolve(language)}', false),
        ]),
      ),
    ];
  }

  Widget _emojis<T>(List<T> values, T Function(AvatarAppearance) get, void Function(AvatarAppearance, T) set,
          String Function(T) icon) =>
      _cards<T>(values, get, set, (v) => Text(icon(v), style: const TextStyle(fontSize: 32)));

  Widget _colours<T>(List<T> values, T Function(AvatarAppearance) get, void Function(AvatarAppearance, T) set,
          Color Function(T) colour, {String? icon}) =>
      _cards<T>(
          values,
          get,
          set,
          (v) => Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: colour(v), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: icon == null ? null : Text(icon, style: const TextStyle(fontSize: 18)),
              ));

  Widget _cards<T>(List<T> values, T Function(AvatarAppearance) get, void Function(AvatarAppearance, T) set,
      Widget Function(T) label) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 10, runSpacing: 10, children: [
        for (final value in values)
          () {
            final selected = get(_draft) == value;
            return Semantics(
              button: true,
              selected: selected,
              label: value is Enum ? value.name : '$value',
              child: GestureDetector(
                onTap: () => _update((l) => set(l, value)),
                child: SizedBox(
                  child: Container(
                    width: 62,
                    height: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? Colors.yellow : Colors.transparent, width: 4),
                    ),
                    child: label(value),
                  ),
                ),
              ),
            );
          }(),
      ]),
    );
  }

  static String _hairIcon(HairStyle s) => switch (s) {
        HairStyle.short => '✂️',
        HairStyle.spiky => '🦔',
        HairStyle.curly => '🌀',
        HairStyle.bob => '💁',
        HairStyle.ponytail => '🐴',
        HairStyle.buns => '🍡',
        HairStyle.long => '👸',
        HairStyle.none => '🥚',
      };

  static String _eyesIcon(Eyes e) => switch (e) {
        Eyes.round => '👀',
        Eyes.happy => '😊',
        Eyes.sparkle => '🤩',
        Eyes.sleepy => '😴',
      };

  static String _browsIcon(Brows b) => switch (b) {
        Brows.soft => '🙂',
        Brows.bold => '😠',
        Brows.raised => '🤨',
      };

  static String _glassesIcon(Glasses g) => switch (g) {
        Glasses.none => '🚫',
        Glasses.round => '👓',
        Glasses.square => '🤓',
        Glasses.star => '🌟',
      };

  static String _topIcon(Top t) => switch (t) {
        Top.tee => '👕',
        Top.hoodie => '🧥',
        Top.jersey => '🎽',
        Top.dress => '👗',
      };

  static String _bottomsIcon(Bottoms b) => switch (b) {
        Bottoms.shorts => '🩳',
        Bottoms.pants => '👖',
        Bottoms.skirt => '🩰',
      };

  static String _hatIcon(Hat h) => switch (h) {
        Hat.none => '🚫',
        Hat.cap => '🧢',
        Hat.beanie => '🧶',
        Hat.crown => '👑',
        Hat.bow => '🎀',
      };
}
