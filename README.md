# RallyCoach — Personal Offline AI Tennis Coach (POAT)

Mount your phone anywhere on the court, pick a drill, and get continuous
spoken coaching as you hit — like having a pro on the fence. **Everything
runs on the phone.** No wifi, no cloud, no account, no subscription. The
Android build ships **without the INTERNET permission** as proof.

## How it works — a 3-tier on-device brain

| Tier | Tech | Role |
|---|---|---|
| Live | MoveNet Thunder/Lightning (TFLite) + rule-based biomechanics engine (Dart) | Per-frame pose, shot detection, instant deterministic cues (<2.5s, always available — "Lite mode") |
| Shot | **Gemma 4 E2B** (`.litertlm`, bundled in the APK) via flutter_gemma/LiteRT-LM | Contextual spoken cue per shot, racing a 4s deadline against the rule cue |
| Session | Same Gemma model — or the deterministic Lite coach when the model is absent | Natural-language summary headline, encouragement, post-session "Ask your coach" chat (Lite mode answers from the stored session facts via `lib/core/brain/lite_coach.dart`) |

The camera path rotates each frame upright (sensor orientation vs device
orientation), letterboxes it so the player is never stretched, and
One-Euro-smooths the keypoints (`lib/core/pose/pose_smoother.dart`) before
the engine sees them. Live shot-detection windows are specified in
milliseconds and adapt to the measured frame rate, so thermal fps drops
don't silently change detection behavior.

Every LLM cue passes a **validator** (`lib/core/brain/cue_validator.dart`)
before it is spoken: it must reference a metric that actually deviated,
contain no numbers, stay short, and not repeat itself — otherwise the
deterministic rule cue speaks instead. The LLM never invents scores.

Camera frames flow camera → pose isolate → engine → discarded. **No video
ever touches disk**; only session summaries persist (SQLite/drift).

## Repo layout

```
lib/core/engine/    pose normalization, shot detection/classification,
                    phase segmentation, technique scoring, cue selection
                    — a 1:1 port of python_lab/engine_math.py
lib/core/session/   live shot processor, orchestrator state machine,
                    summary generator, calibration
lib/core/coach/     TTS queue (newest-wins, 1 cue/6s, swing mute,
                    caption mirroring), 3 personality phrase banks
lib/core/brain/     bundled-model manager, Gemma runner, prompt builder,
                    cue validator, grounded coach chat
lib/core/camera/    camera stream → YUV/BGRA → MoveNet (device-only)
lib/core/storage/   drift schema: sessions, shot_stats, stroke_trends
lib/features/       screens (Fresh Court design: white + ball green)
python_lab/         DEV-ONLY: reference math, synthetic swing fixtures,
                    shared test vectors, phrase-bank builder
assets/reference/   per-stroke/tier ideal ranges (literature-derived)
```

## Building

```bash
tool/fetch_models.sh           # MoveNet (public, ~18 MB, committed)
tool/fetch_models.sh --gemma   # + Gemma 4 E2B (~2.6 GB, ungated HF,
                               #   split into <2 GB APK-safe chunks)
flutter pub get
flutter build apk --release    # ≈2.8 GB APK with the brain bundled
```

Built **without** the Gemma chunks the app still works fully in **Lite
mode** (rule-engine cues, deterministic summaries; chat explains itself
honestly). With chunks bundled, first launch does a one-time on-device
unpack (no network). Coach Brain needs a ≥6 GB-RAM device; below that the
app stays Lite automatically.

Distribution is sideload-first (own website): the APK exceeds Play Store
size limits by design — one download, everything included, works on an
airplane forever.

## Tests

```bash
flutter analyze                          # zero issues
flutter test                             # 123 tests
(cd python_lab && python3 validate_engine.py)  # engine math validation
```

The engine's Dart port is pinned to the Python reference by
`test/fixtures/engine_vectors.json` (exact labels/indices, ±0.5 on
angles/scores). The cue validator is pinned by 16 adversarial fixtures.
The orchestrator integration tests drive recorded keypoint streams through
the entire loop with faked speech/LLM/database.

To regenerate fixtures after changing engine math (change Python first,
then mirror in Dart):

```bash
cd python_lab
python3 biomech_reference.py && python3 validate_engine.py
python3 make_test_vectors.py && python3 prompt_evals.py
python3 build_phrase_banks.py
```

## Known follow-ups (v1 scope notes)

- **Kotlin Gradle Plugin deprecation**: the Android build warns that
  `flutter_gemma`, `flutter_tts`, `large_file_handler`, `package_info_plus`,
  `thermal` and `wakelock_plus` still apply the legacy Kotlin Gradle Plugin,
  which future Flutter releases will reject. All six are already at their
  latest pub versions; `android/gradle.properties` documents the migration
  steps to take as soon as Built-in-Kotlin releases of those plugins land.

- Reference ranges are encoded from published coaching literature and
  validated on synthetic kinematic fixtures; tuning against real labeled
  footage (the original M1 plan) is the next data milestone.
- Forehand/backhand discrimination from a pure side view is geometrically
  ambiguous in 2D; the orientation classifier degrades gracefully
  ("limited angle — footwork cues only").
- Gemma 4 E4B "Pro" model: planned as a file-import upgrade in Settings
  (keeps the no-INTERNET claim); UI hook exists, import flow not yet wired.
- iOS: model file iCloud-backup exclusion needs a small platform channel
  (TODO in `model_manager.dart`); device-matrix perf/thermal tuning
  (PRD M6) requires physical hardware.
