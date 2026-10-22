# ChihChi Flutter — design

Port of the ChihChi iOS app (SwiftUI/SpriteKit/SceneKit/ARKit, ~35k lines, commit 43361b1 on
`3D-updated`) to Flutter for Android and iOS. Approved 2026-10-22.

## Decisions
- Everything is ported before the first push to github.com/chandrashekharNH/ChihChi-Flutter (`main`).
- Same layers as iOS: `core/`, `data/`, `domain/`, `services/`, `game/`, `features/`.
- State: `provider` + `ChangeNotifier` (iOS `@Observable`). Storage: JSON files per child profile and
  `shared_preferences` (iOS SwiftData/UserDefaults); `flutter_secure_storage` for the purchase cache (Keychain).
- 2D games (Catch Letter, Catch World, Word Hunt, Build the Picture): Flame.
- 3D games (Learn Blaster, Turbo Race) and the personal character: Flame/Canvas with a 3D look
  (perspective, depth, shading), not real 3D models.
- AR Explorer: the same Flutter code on both platforms: `camera` + Google ML Kit on-device labelling and
  object detection (the tapped object's box replaces Vision's cut-out). ML Kit labels differ from Apple's,
  so the object word lists are remapped. Virtual stages (Animals, Adventure) are drawn over the camera.
- Text: all 1,277 `AppText.xcstrings` lines with 22 languages are converted by `tool/convert_strings.py`
  into `assets/i18n/<code>.json`; `L(english, args)` resolves them like iOS `Localized`.
- Purchases: `in_app_purchase` (Google Play Billing + StoreKit), non-consumable `com.chihchi.fulladventure`,
  first 10 levels of every game free, Free Play and My Photo Puzzle 10 free uses each per device.
- Voice: `flutter_tts`; sound effects and music are synthesised in Dart (iOS synthesises them too).

## Known differences from iOS
- Android system icons and fonts; Material widgets styled to match the iOS look.
- 3D scenes are drawn in 2D with depth effects.
- AR object recognition uses ML Kit, so results differ from Apple Vision.

## Verification
- Ported unit tests for platform-free rules (`flutter test`), `flutter analyze` clean,
  `flutter build apk --debug` and `flutter build ios --debug --no-codesign` succeed.
