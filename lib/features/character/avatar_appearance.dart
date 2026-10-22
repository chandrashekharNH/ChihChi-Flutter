import 'dart:math' as math;
import 'dart:ui';

import '../../core/ui/palette.dart';
import '../../data/storage/player_progress.dart';
import 'measured_face.dart';

enum SkinTone { porcelain, light, beige, tan, golden, brown, deep, ebony }

enum FaceShape { round, oval, wide }

enum HairStyle { short, spiky, curly, bob, ponytail, buns, long, none }

enum HairColor { black, darkBrown, brown, auburn, blonde, ginger, pink, blue }

enum Eyes { round, happy, sparkle, sleepy }

enum EyeColor { brown, black, hazel, green, blue }

enum Brows { soft, bold, raised }

enum Glasses { none, round, square, star }

enum Top { tee, hoodie, jersey, dress }

enum Bottoms { shorts, pants, skirt }

enum Hat { none, cap, beanie, crown, bow }

enum Outfit { red, orange, yellow, green, teal, blue, purple, pink }

T _pick<T>(List<T> values, math.Random r) => values[r.nextInt(values.length)];

T _byName<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    values.where((v) => v.name == raw).firstOrNull ?? fallback;

/// Everything a child chose for their character, plus the face measurements from their photo if
/// they used one. Only choices and numbers are saved — never a photo.
class AvatarAppearance {
  AvatarAppearance({
    this.skinTone = SkinTone.tan,
    this.faceShape = FaceShape.round,
    this.hairStyle = HairStyle.short,
    this.hairColor = HairColor.darkBrown,
    this.eyes = Eyes.round,
    this.eyeColor = EyeColor.brown,
    this.brows = Brows.soft,
    this.glasses = Glasses.none,
    this.top = Top.tee,
    this.topColor = Outfit.blue,
    this.bottoms = Bottoms.shorts,
    this.bottomsColor = Outfit.teal,
    this.shoesColor = Outfit.red,
    this.hat = Hat.none,
    this.backpack = false,
    this.measured,
  });

  SkinTone skinTone;
  FaceShape faceShape;
  HairStyle hairStyle;
  HairColor hairColor;
  Eyes eyes;
  EyeColor eyeColor;
  Brows brows;
  Glasses glasses;
  Top top;
  Outfit topColor;
  Bottoms bottoms;
  Outfit bottomsColor;
  Outfit shoesColor;
  Hat hat;
  bool backpack;

  /// Measurements of the child's own face (from "From my photo"); null draws the standard face.
  MeasuredFace? measured;

  static AvatarAppearance get standard => AvatarAppearance();

  AvatarAppearance copy() => AvatarAppearance.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'skinTone': skinTone.name,
        'faceShape': faceShape.name,
        'hairStyle': hairStyle.name,
        'hairColor': hairColor.name,
        'eyes': eyes.name,
        'eyeColor': eyeColor.name,
        'brows': brows.name,
        'glasses': glasses.name,
        'top': top.name,
        'topColor': topColor.name,
        'bottoms': bottoms.name,
        'bottomsColor': bottomsColor.name,
        'shoesColor': shoesColor.name,
        'hat': hat.name,
        'backpack': backpack,
        if (measured != null) 'measured': measured!.toJson(),
      };

  /// Missing or unknown values fall back to the default, so older saves keep loading after new
  /// options are added.
  factory AvatarAppearance.fromJson(Map<String, dynamic> j) {
    final d = AvatarAppearance();
    MeasuredFace? measured;
    try {
      if (j['measured'] is Map) measured = MeasuredFace.fromJson((j['measured'] as Map).cast<String, dynamic>());
    } catch (_) {}
    return AvatarAppearance(
      skinTone: _byName(SkinTone.values, j['skinTone'], d.skinTone),
      faceShape: _byName(FaceShape.values, j['faceShape'], d.faceShape),
      hairStyle: _byName(HairStyle.values, j['hairStyle'], d.hairStyle),
      hairColor: _byName(HairColor.values, j['hairColor'], d.hairColor),
      eyes: _byName(Eyes.values, j['eyes'], d.eyes),
      eyeColor: _byName(EyeColor.values, j['eyeColor'], d.eyeColor),
      brows: _byName(Brows.values, j['brows'], d.brows),
      glasses: _byName(Glasses.values, j['glasses'], d.glasses),
      top: _byName(Top.values, j['top'], d.top),
      topColor: _byName(Outfit.values, j['topColor'], d.topColor),
      bottoms: _byName(Bottoms.values, j['bottoms'], d.bottoms),
      bottomsColor: _byName(Outfit.values, j['bottomsColor'], d.bottomsColor),
      shoesColor: _byName(Outfit.values, j['shoesColor'], d.shoesColor),
      hat: _byName(Hat.values, j['hat'], d.hat),
      backpack: j['backpack'] is bool ? j['backpack'] as bool : d.backpack,
      measured: measured,
    );
  }

  /// A first look for a new character: random colours, with hair and clothes that suit a boy or
  /// a girl when that was chosen.
  static AvatarAppearance starter(ChildGender? gender, [math.Random? random]) {
    final look = randomLook(random)..glasses = Glasses.none;
    return look.styled(gender, random);
  }

  /// The same character with a boy's or a girl's hair and clothes. Colours, face and everything
  /// else stay; with no choice nothing changes.
  AvatarAppearance styled(ChildGender? gender, [math.Random? random]) {
    final r = random ?? math.Random();
    final look = copy();
    switch (gender) {
      case ChildGender.boy:
        look.hairStyle = _pick([HairStyle.short, HairStyle.spiky, HairStyle.curly], r);
        look.top = _pick([Top.tee, Top.hoodie, Top.jersey], r);
        look.bottoms = _pick([Bottoms.shorts, Bottoms.pants], r);
        if (look.hat == Hat.bow || look.hat == Hat.crown) look.hat = Hat.none;
      case ChildGender.girl:
        look.hairStyle = _pick([HairStyle.bob, HairStyle.ponytail, HairStyle.buns, HairStyle.long], r);
        look.top = _pick([Top.dress, Top.tee, Top.hoodie], r);
        look.bottoms = _pick([Bottoms.skirt, Bottoms.shorts, Bottoms.pants], r);
        if (look.hat == Hat.cap) look.hat = Hat.bow;
      case null:
        break;
    }
    return look;
  }

  /// "Surprise me!": any combination is a valid, friendly look.
  static AvatarAppearance randomLook([math.Random? random]) {
    final r = random ?? math.Random();
    return AvatarAppearance(
      skinTone: _pick(SkinTone.values, r),
      faceShape: _pick(FaceShape.values, r),
      hairStyle: _pick(HairStyle.values, r),
      hairColor: _pick(HairColor.values, r),
      eyes: _pick(Eyes.values, r),
      eyeColor: _pick(EyeColor.values, r),
      brows: _pick(Brows.values, r),
      glasses: r.nextBool() ? Glasses.none : _pick(Glasses.values, r),
      top: _pick(Top.values, r),
      topColor: _pick(Outfit.values, r),
      bottoms: _pick(Bottoms.values, r),
      bottomsColor: _pick(Outfit.values, r),
      shoesColor: _pick(Outfit.values, r),
      hat: r.nextBool() ? Hat.none : _pick(Hat.values, r),
      backpack: r.nextBool(),
    );
  }

  @override
  bool operator ==(Object other) => other is AvatarAppearance && '${other.toJson()}' == '${toJson()}';
  @override
  int get hashCode => '${toJson()}'.hashCode;
}

extension SkinToneColor on SkinTone {
  Color get color => switch (this) {
        SkinTone.porcelain => rgb(1.0, 0.88, 0.8),
        SkinTone.light => rgb(0.98, 0.8, 0.68),
        SkinTone.beige => rgb(0.93, 0.74, 0.58),
        SkinTone.tan => rgb(0.85, 0.64, 0.47),
        SkinTone.golden => rgb(0.78, 0.56, 0.38),
        SkinTone.brown => rgb(0.62, 0.42, 0.28),
        SkinTone.deep => rgb(0.46, 0.3, 0.2),
        SkinTone.ebony => rgb(0.33, 0.21, 0.14),
      };
}

extension HairColorValue on HairColor {
  Color get color => switch (this) {
        HairColor.black => rgb(0.1, 0.09, 0.1),
        HairColor.darkBrown => rgb(0.26, 0.16, 0.1),
        HairColor.brown => rgb(0.45, 0.28, 0.15),
        HairColor.auburn => rgb(0.55, 0.2, 0.12),
        HairColor.blonde => rgb(0.95, 0.8, 0.45),
        HairColor.ginger => rgb(0.88, 0.45, 0.18),
        HairColor.pink => rgb(1.0, 0.5, 0.75),
        HairColor.blue => rgb(0.3, 0.55, 1.0),
      };
}

extension EyeColorValue on EyeColor {
  Color get color => switch (this) {
        EyeColor.brown => rgb(0.4, 0.24, 0.12),
        EyeColor.black => rgb(0.12, 0.1, 0.1),
        EyeColor.hazel => rgb(0.55, 0.45, 0.2),
        EyeColor.green => rgb(0.2, 0.55, 0.3),
        EyeColor.blue => rgb(0.25, 0.5, 0.9),
      };
}

extension OutfitColor on Outfit {
  Color get color => switch (this) {
        Outfit.red => rgb(0.93, 0.25, 0.25),
        Outfit.orange => rgb(1.0, 0.55, 0.15),
        Outfit.yellow => rgb(1.0, 0.82, 0.2),
        Outfit.green => rgb(0.3, 0.75, 0.35),
        Outfit.teal => rgb(0.15, 0.7, 0.7),
        Outfit.blue => rgb(0.25, 0.5, 0.95),
        Outfit.purple => rgb(0.6, 0.35, 0.9),
        Outfit.pink => rgb(1.0, 0.45, 0.7),
      };
}
