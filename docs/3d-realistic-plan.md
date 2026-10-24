# Realistic 3D for ChihChi (Flutter) — plan and progress

Started 2026-10-24. Goal from the owner: make ChihChi look realistic 3D, game by game, on Android and
iOS from this Flutter app. Turbo Race first, then every other game.

## Decisions (owner)

- **Look:** photo-realistic.
- **Drivers:** realistic 3D animals (each racer's animal) in the cars.
- **Models:** AI-generated (Meshy/Tripo); the owner generates them from prompts we write, we convert
  and fit them. Until then the cars use the CC-BY Khronos car below.
- **Platform:** this Flutter app is the future for both Android and iOS; the native iOS app gets no
  new 3D work.

## Engine: flutter_scene

Compared on 2026-10-24 with a throwaway test (same car, ground and sky in each engine):

| | flutter_scene 0.24.3 (Flutter GPU) | Thermion 0.5.0 (Filament) |
|---|---|---|
| iPhone 15 Pro Max | 72 fps, 45–50 fps once warm (one car, full post-processing) | stalled, no frames reported |
| Android emulator (GLES) | 3–30 fps, sky drew black | 50–58 fps, sky and shadows correct |
| Setup | needs Flutter 3.47+, Flutter GPU switched on | plugin needed a compileSdk override |

Chosen: **flutter_scene** (works on a real iPhone, maintained by the Flutter GPU author, draws
inside Flutter so the HUD overlays need no changes). To check on a real Android phone: the black
sky (likely the emulator's OpenGL ES path).

Setup it needs:
- Flutter **3.47.8** or newer (this Mac had 3.44.1; run `flutter upgrade`).
- `flutter pub add flutter_scene` and `dart run flutter_scene:init --no-skills`.
- Flutter GPU on: iOS `Info.plist` `FLTEnableFlutterGPU = true`; Android manifest
  `<meta-data android:name="io.flutter.embedding.android.EnableFlutterGPU" android:value="true" />`.
- Read the package's agent skills (`skills/flutter_scene-*` in the package) before writing code:
  `vector_math.dart` (not `_64`), whole-value transforms, `SceneView`, `scene.environmentSettings`.

## Done

- `assets/models/race_car.glb` (43k triangles, 2.3 MB) for the player and
  `assets/models/race_car_far.glb` (13.7k triangles, 1.1 MB) for rivals, from Khronos
  **CarConcept** (Eric Chadwick, © Darmstadt Graphics Group, **CC-BY 4.0** — credit in the app's
  About page is required). Source: github.com/KhronosGroup/glTF-Sample-Assets, Models/CarConcept.
  Layout: `Car` › `Body` (one draw per material) + `WheelFrontL/R`, `WheelRearL/R` (origin at the
  hub, spin/steer these). Material **`Paint`** is the body colour, recoloured per racer.
- `tools/models/optimize_car.mjs` (gltf-transform): strips interior, keeps wheels, joins by
  material, simplifies, tinted glass instead of transmission, 1024 px WebP textures.
  `cd tools/models && npm install && node optimize_car.mjs in.glb out.glb [--ratio 0.25] [--error 0.002]`
  (rivals: `--ratio 0.06 --error 0.012`).

## Next steps

1. **3D Turbo Race renderer** (new `lib/game/scenes/turbo_race_3d.dart`), drawing from the
   existing `TurboRaceSimulation` (rules unchanged), keeping `TurboRaceScene` (2.5D painter) as the
   fallback where Flutter GPU is unavailable:
   - sky: HDR per `TurboSky` (Poly Haven CC0, e.g. `kloofendal_48d_partly_cloudy_puresky`)
   - road ribbon with asphalt texture (Poly Haven `asphalt_01`), kerbs, barriers, lane paint
     (`depthLayer` to avoid z-fighting), grass (`aerial_grass_rock`), start gantry
   - scenery from `_buildScenery` as lit 3D props (later replaced by models)
   - gates (text/shape panels via textures from Flutter images), stars, boost pads
   - cars: GLB instances, per-racer `Paint`, spinning/steering wheels, boost flames, shadows
   - chase and intro cameras as in `TurboRaceScene`; name tags and confetti as Flutter overlay
   - look: start from the package's "showcase" preset, profile on phone, adaptive quality on
2. **The 9 missing worlds (races 6–50):** Forest Town, Underground City, Coastal City, Desert
   Kingdom, Snow City, Mountain Kingdom, Dino Valley, Future City, Magic Kingdom — new
   `TurboEnvironment`/`TurboSky` cases, scenery, surfaces and weather, race definitions
   (see the iOS Turbo Race plan phases 2–4).
3. **AI model prompts** for the owner: 8 racer cars (no wheels) + 1 wheel, 8 animal drivers,
   scenery per world.
4. **Other games, one at a time:** Catch Letter, Catch World, Learn Blaster, Build the Picture,
   AR Explorer, the child's character.

Tests for each step: `flutter analyze`, `flutter test`, Android emulator, the owner's iPhone.
