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

### Two trackers: body **and** racquet

On top of the 17-point body pose, a second tracker follows the **racquet**
(`lib/core/engine/racquet.dart`). MoveNet has no racquet keypoints, so the
racquet is modelled as a rigid **forearm extension** — a handle→throat→tip
skeleton continuing the elbow→wrist line — and **drawn live over the player**.
It feeds the brain the **racquet angle** at contact (swinging on the line of
the shot, or lagging/flailing), the **racquet reach** on serves, and a
**`racquet_confidence`** (0–1: racquet-head sweep + arm extension) so the coach
**hedges or stays quiet instead of mistaking a stray empty-hand wave for a
real shot**. It reads the racquet-arm line and gross orientation, *not* the
grip or open/closed face twist (still verbal-only — not pose-sensible). The
data contract (`racquetPose(..., detected:)`) already accepts measured racquet
keypoints, so bundling an optical racquet model later
(`tool/fetch_models.sh --racquet`) upgrades every racquet metric in place and
makes the confidence an authoritative presence gate. See
[`docs/TENNIS_COACHING_KNOWLEDGE.md`](docs/TENNIS_COACHING_KNOWLEDGE.md).

## Tracking, live analysis, and the post-session debrief

Every shot is stored with its **full deviation list** (id, phase,
direction, severity), not just the headline problem, and each session
persists a computed **insights blob**
(`lib/core/session/session_insights.dart`): per-stroke averages/best/worst,
per-swing-phase scores, per-metric in-range rates split into session halves
(improving / worsening / steady), a score timeline, a consistency index,
clean-streak and best-shot markers, and the goal-metric outcome.

Live, the HUD shows a last-12-shots sparkline, the coach's current focus
metric, and a clean-streak counter; the coach speaks deterministic
**milestones** on top of technique cues — new session best, clean-streak
calls, and a check-in every ten shots with the running average and trend
(all three personalities carry dedicated phrase-bank slots for these).

The summary screen renders the insights (timeline, stroke breakdown,
swing-phase bars with the weakest phase called out, consistency / streak /
best-shot chips), and **"Ask your coach" is grounded in the same data**:
the Gemma chat receives the full insights JSON plus aggregates of the last
5 sessions (the prompt's history slot), and the Lite coach answers
stroke-, phase-, timeline-, consistency-, best-shot- and
progress-versus-history questions from the stored numbers alone.

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
assets/reference/   per-stroke/tier ideal ranges (literature-derived) +
                    coaching_knowledge.json (faults→causes→fixes→drills,
                    keyed to metric id; see docs/TENNIS_COACHING_KNOWLEDGE.md)
```

## Building

First-time Android toolchain setup (Flutter/JDK/SDK/NDK versions + wireless
ADB) is documented in [`docs/DEV_SETUP.md`](docs/DEV_SETUP.md).

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
flutter test                             # 155 tests
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

- **16 KB page alignment**: the APK uses modern page-aligned packaging
  (`useLegacyPackaging = false`), so everything we build plus most bundled
  libs are 16 KB-aligned. Five prebuilt vendor binaries inside `flutter_gemma`
  (`libqdrant_edge_ffi.so`, `libQnnHtpV{73,75,79,81}Skel.so`) are still
  4 KB-aligned and can only be fixed upstream; they don't affect current
  devices (16 KB pages are opt-in on Android 15).
- Reference ranges are encoded from published coaching literature and
  validated on synthetic kinematic fixtures; the literature behind every
  range — plus a metric-by-metric fault/cause/fix/drill knowledge base — is
  documented in [`docs/TENNIS_COACHING_KNOWLEDGE.md`](docs/TENNIS_COACHING_KNOWLEDGE.md)
  and the machine-readable `assets/reference/coaching_knowledge.json`. Tuning
  against real labeled footage (the original M1 plan) is the next data
  milestone.
- Forehand/backhand discrimination from a pure side view is geometrically
  ambiguous in 2D; the orientation classifier degrades gracefully
  ("limited angle — footwork cues only").
- Gemma 4 E4B "Pro" model: planned as a file-import upgrade in Settings
  (keeps the no-INTERNET claim); UI hook exists, import flow not yet wired.
- `file_picker` rides a 12.0.0 beta: wakelock_plus 1.6.1 moved to win32 6
  and the beta is the first file_picker release that follows — pin back to
  stable as soon as 12.0.0 lands (`pubspec.yaml` documents this).
- iOS: model file iCloud-backup exclusion needs a small platform channel
  (TODO in `model_manager.dart`); device-matrix perf/thermal tuning
  (PRD M6) requires physical hardware.
