import 'dart:io' show Platform;

import '../../core/localization/localized.dart';

/// Text for the Full Adventure screens, in every app language. Lines that name Apple have a
/// Google Play version on Android (these are new lines, so they show in English until translated).
class StoreText {
  static bool get _android => Platform.isAndroid;

  // Child-facing card (no prices, no payment buttons)
  static Localized completedFree(int count) => L('Amazing! You completed your first {0} adventures!', args: [count]);
  static Localized usedFreeUses(int count) => L('Wow! You played all {0} free puzzles!', args: [count]);
  static final partOfFullAdventure = L('This is part of ChihChi Full Adventure!');
  static final askGrownUp = L('Ask a grown-up to unlock more adventures.');
  static final askGrownUpButton = L('Ask a Grown-up');
  static final keepPlaying = L('Keep Playing');

  // Purchase screen (behind the parent gate)
  static final title = L('ChihChi Full Adventure');
  static final subtitle = L('Unlock ChihChi Full Adventure with a one-time purchase.');
  static final benefitLevels = L('All current premium levels and game modes');
  static final benefitWorlds = L('All included learning worlds and languages');
  static final benefitOffline = L('Offline gameplay');
  static final benefitNoSubscription = L('No monthly subscription');
  static final benefitNoRecurring = L('No recurring payments');
  static final unlockButton = L('Unlock Full Adventure');
  static final restoreButton = L('Restore Purchases');
  static final privacyPolicy = L('Privacy Policy');
  static final termsOfUse = L('Terms of Use');
  static final continueFree = L('Continue Playing Free');
  static final loadingPrice = L('Loading price…');
  static final tryAgain = L('Try Again');

  // Status
  static Localized get offline => _android
      ? L("Google Play can't be reached right now. Connect to the internet and try again.")
      : L("The App Store can't be reached right now. Connect to the internet and try again.");
  static final pending = L('Waiting for approval. Full Adventure will unlock as soon as the purchase is approved.');
  static final cancelled = L('The purchase was cancelled.');
  static final failed = L("The purchase couldn't be completed. Please try again.");
  static final purchased = L('Thank you! Full Adventure is unlocked.');
  static final restored = L('Purchases restored. Full Adventure is unlocked.');
  static Localized get nothingToRestore => _android
      ? L('No previous purchase was found for this Google Account.')
      : L('No previous purchase was found for this Apple Account.');
  static final checking = L('Checking purchases…');
  static final unlockedHere = L('Full Adventure is unlocked on this device.');
  static final freeVersion = L(
      'Free version: the first 10 levels of every game, including AR Explorer, plus 10 Free Play and 10 My Photo puzzles.');
  static Localized get paymentsFooter => _android
      ? L('Payments are handled by Google Play. Buying or restoring needs an internet connection; after that, everything plays offline.')
      : L('Payments are handled by Apple. Buying or restoring needs an internet connection; after that, everything plays offline.');
}

/// Links shown on the purchase screen.
class StoreLinks {
  /// TODO before release: replace with ChihChi's own privacy policy page.
  static final privacyPolicy = Uri.parse('https://example.com/chihchi/privacy');

  /// Apple's standard licence agreement on iOS; Google Play's terms on Android.
  static Uri get termsOfUse => Platform.isAndroid
      ? Uri.parse('https://play.google.com/about/play-terms/')
      : Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/');
}
