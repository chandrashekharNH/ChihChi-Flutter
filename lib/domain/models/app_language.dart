import '../../core/localization/localized.dart';

/// The languages ChihChi can be played in. `code` is the saved value, so it never changes.
enum AppLanguage {
  english('en', 'English', 'English', 'EN', '🇬🇧', false, ['en-IN', 'en-US', 'en-GB'], 'en', false),
  kannada('kn', 'ಕನ್ನಡ', 'Kannada', 'ಕ', '🇮🇳', false, ['kn-IN'], 'kn-IN', false),
  hindi('hi', 'हिन्दी', 'Hindi', 'हि', '🇮🇳', false, ['hi-IN'], 'hi-IN', false),
  tamil('ta', 'தமிழ்', 'Tamil', 'த', '🇮🇳', false, ['ta-IN'], 'ta-IN', true),
  telugu('te', 'తెలుగు', 'Telugu', 'తె', '🇮🇳', false, ['te-IN'], 'te-IN', true),
  malayalam('ml', 'മലയാളം', 'Malayalam', 'മ', '🇮🇳', false, ['ml-IN'], 'ml-IN', true),
  marathi('mr', 'मराठी', 'Marathi', 'म', '🇮🇳', false, ['mr-IN'], 'mr-IN', true),
  bengali('bn', 'বাংলা', 'Bengali', 'বা', '🇮🇳', false, ['bn-IN', 'bn-BD'], 'bn-IN', true),
  gujarati('gu', 'ગુજરાતી', 'Gujarati', 'ગુ', '🇮🇳', false, ['gu-IN'], 'gu-IN', true),
  punjabi('pa', 'ਪੰਜਾਬੀ', 'Punjabi', 'ਪੰ', '🇮🇳', false, ['pa-IN', 'pa-Guru-IN'], 'pa-IN', true),
  odia('or', 'ଓଡ଼ିଆ', 'Odia', 'ଓ', '🇮🇳', false, ['or-IN'], 'or-IN', true),
  urdu('ur', 'اردو', 'Urdu', 'ار', '🇮🇳', true, ['ur-IN', 'ur-PK'], 'ur-IN', true),
  spanish('es', 'Español', 'Spanish', 'ES', '🇪🇸', false, ['es-ES', 'es-MX', 'es-US'], 'es', true),
  french('fr', 'Français', 'French', 'FR', '🇫🇷', false, ['fr-FR', 'fr-CA'], 'fr', true),
  german('de', 'Deutsch', 'German', 'DE', '🇩🇪', false, ['de-DE'], 'de', true),
  portuguese('pt', 'Português', 'Portuguese', 'PT', '🇧🇷', false, ['pt-BR', 'pt-PT'], 'pt-BR', true),
  russian('ru', 'Русский', 'Russian', 'RU', '🇷🇺', false, ['ru-RU'], 'ru', true),
  indonesian('id', 'Bahasa Indonesia', 'Indonesian', 'ID', '🇮🇩', false, ['id-ID'], 'id', true),
  italian('it', 'Italiano', 'Italian', 'IT', '🇮🇹', false, ['it-IT'], 'it', true),
  japanese('ja', '日本語', 'Japanese', 'あ', '🇯🇵', false, ['ja-JP'], 'ja', true),
  chinese('zh', '中文', 'Chinese', '中', '🇨🇳', false, ['zh-CN', 'zh-TW', 'zh-HK'], 'zh-Hans', true),
  arabic('ar', 'العربية', 'Arabic', 'ع', '🇦🇪', true, ['ar-001', 'ar-SA'], 'ar', true);

  const AppLanguage(this.code, this.ownName, this.englishName, this.shortLabel, this.flag, this.isRightToLeft,
      this.voiceCodes, this.localeID, this.needsNativeReview);

  /// Saved code ("kn").
  final String code;

  /// The language's name in its own script ("ಕನ್ನಡ").
  final String ownName;
  final String englishName;

  /// One or two characters for the 🌐 button ("EN", "ಕ").
  final String shortLabel;
  final String flag;
  final bool isRightToLeft;

  /// Voice languages, best first.
  final List<String> voiceCodes;

  /// Used to format dates and numbers.
  final String localeID;

  /// Written by Claude and not yet checked by someone who speaks it.
  final bool needsNativeReview;

  String get displayName => ownName;
  String get localScript => ownName;

  /// The language's name, said in the app's current language ("Kannada", "ಕನ್ನಡ"…).
  Localized get nameLine => L(englishName, key: 'language.$code');

  static AppLanguage? fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return null;
  }
}
