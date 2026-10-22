# Port progress (iOS → Flutter)

Source: `../ChihChi/ChihChi/` at commit 43361b1. Design: `docs/design.md`.
Update this file after each batch.

## Done
- core/localization (Localized, LanguageOrder + location, ranker, geography, content names), i18n JSON
- data: game content (en/kn/hi + 19 language packs), run-collect content, puzzle library, PlayerProgress
- domain/models (all)
- services: progress (ProgressService, ChildProfileFiles), reward, difficulty, theme, update (iOS lookup only)
- services/audio: music + fun-sound synth, AudioService (music loop, haptics), FunSoundPlayer,
  KidsVoice / KidsSpeechService (flutter_tts, pitch per character), ChildNameVoice (+ recorder)
- core/store: PremiumAccess, FreeUses, EntitlementManager (secure cache), StoreManager (in_app_purchase)
- core/app_state.dart
- Common UI: breathing background, play-boost HUD, wrong-catch card, name recorder button, session tracking,
  route map (content/layout/view/top bar/text/game adapters), page header
- App shell: main.dart (providers, first-launch flow, RTL, localisation delegates), Home, ChildNameView,
  Settings, language picker, Rewards, Progress, LevelSelection (chooser + Catch Letter / shared maps)
- Parent Zone: gate + session, dashboard, statistics VM, components (fl_chart), game detail, weekly, settings hub,
  children, music, child profile, controls, privacy, reset, about, support; ParentText (+ Android wording)
- Store UI: FullAdventureUnlockFlow (card → gate → purchase), FullAdventureView, StoreText (+ Google Play wording)
- Character: AvatarAppearance, MeasuredFace, PlayerCharacterStore, 3D-look renderer (character_model + character_view:
  projected shaded spheres/capsules, depth-sorted, drag to turn, all 11 animations), portrait PNG, studio, photo flow
  (camera + ML Kit face detection), FirstLaunchFlow / offer, PlayerMarker, PlayerBuddy
- AR data: ARHuntContent vocabulary, ARExplorerContent, world content, missions/judge, progress store, ARExplorerText
- Platform config: iOS permission strings + Podfile 15.5 + deployment 15.5; Android permissions, TTS query, minSdk 24
- Verified: flutter analyze clean; debug APK runs on Pixel 9 Pro emulator (name → offer → Home → Catch Letter map)

- Games (all six), opened from `lib/features/levels/game_screens.dart`:
  - Catch Letter and Catch World on a small 2D engine (`lib/game/engine`: scene clock, tweens, sprites, cached text images).
  - Build the Picture: generator, art renderer, drag-and-snap scene, home (difficulty, 100-level map, free play,
    My Photo Puzzle with camera/gallery), game screen with hint/rotate/look, results and grand finale.
  - Learn Blaster: the playroom drawn in 2D with perspective (walls, floor, rug, toys, balloons on depth lanes),
    hold-and-aim blaster, tap to fire.
  - Turbo Race: track, learning gates, simulation, progress file, world-journey map, and a chase-camera renderer that
    projects the road, kerbs, scenery boxes, cars, gates, stars and boost pads with fog.
  - AR Explorer: home, levels, hunts, intro, camera notice, play screen, My AR World. Camera + ML Kit labelling and
    object finding on the tapped area; ChihChi's pieces are drawn over the camera (no world tracking on Flutter).
- Tests: `flutter test` (46): Turbo Race (track, gates, simulation, progress, balance over 20 seeds), Build the
  Picture, game difficulty, AR recognition rules, Full Adventure free levels, character rendering.
- App icon from the iOS AppIcon (iOS icon set and Android mipmaps).
- Verified 2026-10-22: `flutter analyze` clean; `flutter test` passes; debug APK runs every game on the Pixel 9 Pro
  emulator; `flutter build ios --no-codesign` builds.

## Still open
- Native-speaker review of the translations (same as iOS), plus the English-only Android/Google Play lines.
- Google Play: create the product `com.chihchi.fulladventure`; set the real privacy policy URL (placeholder).
- iOS can only be tested on a real iPhone (ML Kit has no arm64 simulator build).

## Notes
- AR Explorer recognition uses ML Kit, whose scores run higher than Apple's: its thresholds are higher than iOS's
  and faces/people count as "something else", so a face is never taught as an object.
- Turbo Race balance: iOS races in 32-bit floats, Dart in 64-bit, so a seed plays out differently; the balance
  tests check rates over 20 seeds.
- Build the Picture: the two-finger twist to rotate is replaced by the Rotate button.
- Artwork folder in iOS is empty, so games draw emoji (ArtworkLibrary not needed).
- iOS restore of purchases may prompt for a password, so on iOS ownership comes from the cache, the purchase
  stream and the Restore button; Android queries owned purchases quietly at launch.
- Desktop is synced by iCloud, which breaks Xcode code signing ("detritus"). `build` is a link to
  ~/Library/Caches/ChihChiFlutterBuild; keep it that way.
- ML Kit has no arm64 iOS-simulator build and iOS 26 simulators can't run x86_64 apps: test iOS on a real iPhone,
  or use the Android emulator (`flutter emulators --launch Pixel_9_Pro`).
- App id is CSOrg.com.ChihChi on both iOS and Android (same as the iOS app; user decision 2026-10-22). The Kotlin namespace stays com.chihchi.chihchi.
- New English-only lines (need translating): Android/Google Play variants in StoreText and ParentPlatformText.
- test/visual/render_character_test.dart renders sample characters to PNG (`--dart-define=OUT=dir`).
