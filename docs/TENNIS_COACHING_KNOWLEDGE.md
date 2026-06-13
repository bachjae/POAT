# Tennis Coaching Knowledge Base

This document is the human-readable companion to
[`assets/reference/coaching_knowledge.json`](../assets/reference/coaching_knowledge.json).
It compiles the tennis technique knowledge that drives the RallyCoach
"brain" — the kind of thing a good club or academy coach charges by the hour
to teach — and ties every piece of it to **a metric the engine can actually
measure from a 2D MoveNet pose**, with sources.

The goal: when the engine detects that your *arm angle*, *body position*,
*wrist position*, *swing/contact height* or *leg position* is off, the coach
knows **why it matters, what's probably causing it, and the fix and drill that
will help** — grounded in published biomechanics and ITF/USPTA-style coaching,
not vibes.

> **What the camera can and can't see.** MoveNet returns 17 body keypoints
> (nose, eyes, ears, shoulders, elbows, wrists, hips, knees, ankles). That is
> enough to measure **joint angles and positions**. It is **not** enough to
> see the **grip, the racket face, true wrist flexion/extension, ball spin or
> ball speed** — there are no hand, finger or racket keypoints. So grip and
> wrist *action* are coached as spoken advice only; the measurable proxies for
> "wrist" are wrist **position** (`contact_in_front`, `contact_height`,
> `wrist_finish_height`). The app is honest about this rather than faking a
> score it can't compute.

---

## 1. The one idea behind everything: the kinetic chain

Tennis power is generated **proximal-to-distal** — from the big, slow body
parts to the small, fast ones, in sequence:

```
ground reaction → legs → hips → trunk (X-factor) → shoulder → elbow → wrist → racket
```

Each link adds speed to the one after it. A weak or mistimed link "leaks"
energy (so the arm has to muscle the shot) and raises injury risk. Almost
every checkpoint below is a checkpoint on this chain
([Knudson & Elliott, *Biomechanics and tennis*][s3];
[Kovacs review][biomech]).

Coaching corollaries the brain leans on:

- **Ground up.** Bend the knees to load, drive up through contact.
- **Contact in front.** On every stroke, meeting the ball in front lets you
  see it, move your weight into it, and control direction.
- **Early preparation.** Turn before the bounce; late prep cascades into late,
  rushed contact.
- **Hold your finish.** If you can't freeze a balanced finish for a beat, the
  swing wasn't balanced.

---

## 2. Measurable checkpoints (mapped to engine metrics)

Each subsection is one engine metric id. "Low / High" are the two deviation
**directions** the engine reports, and they line up 1:1 with the `faults` in
the JSON knowledge base, so a detected deviation maps straight to a cause, a
fix, a feel-cue and a drill.

### Arm angle — `elbow_angle` (interior shoulder–elbow–wrist; 180° = straight)

The elbow angle sets your **contact distance and leverage**. Too bent (small
interior angle) crowds contact into the body and shortens the lever; locked
straight costs control and loads the joint.

- **Serve benchmark:** elbow is still ~**30° flexed (≈150° interior)** at ball
  impact — internal *shoulder* rotation, not elbow extension, supplies most of
  the racket speed ([serve meta-analysis][serve-meta]; [Kovacs review][biomech]).
- **Forehand:** both straight-arm (~79° at the shoulder) and flexed-arm
  (~53°) patterns are used by pros — there's a viable range, not one "correct"
  angle ([comparative forehand study][comp-fh]).
- **Low fault** (too bent): extend through contact, meet the ball an arm's
  length in front. **High fault** (locked): keep a touch of give and move your
  feet so the ball comes into your zone.
- **Drills:** shadow-swing, mirror-contact, volley-punch.

### Leg position — `knee_flexion` (interior hip–knee–ankle; 180° = straight)

Bent knees lower your centre of mass, load the legs like springs, and let you
drive **up** through contact. Stiff legs force the arm to do everything.

- **Serve trophy benchmark:** front-knee **flexion ~64.5° ± 9.7° (≈115°
  interior)** at the fully-loaded trophy position ([serve meta-analysis][serve-meta]).
  Deeper knee bend measurably increases serve speed in intermediate players
  ([knee-flexion serve study][knee-serve]).
- **Low fault** (too upright): sit into an athletic squat, drive up through the
  hit. **High fault** (over-squatting): bend to load and spring, not to sit.
- **Drills:** chair-touch, balance-board, split-step.

### Body position — `trunk_tilt`, `shoulder_turn`, `hip_shoulder_sep`

**`trunk_tilt`** (lean from vertical). A slight forward tilt (~0–20°) attacks
the ball; an excessive or backward lean pulls the eyes off the ball and leaks
balance. Keep the chin level, finish with the chest to the target.

**`shoulder_turn`** (rotation of the shoulder line, ~**90°** = chest to the
side fence). The shoulder turn is the engine of the swing — it stores the
energy the arm releases at contact, and shoulder internal rotation contributes
a large share of forehand racket speed ([Feel Tennis][feeltennis-shoulder];
[groundstroke biomechanics][grok]). Under-rotation = arming the ball; start
the turn as the ball leaves the opponent's strings.

**`hip_shoulder_sep`** — the **X-factor** (shoulders turned past hips).
Stretching the shoulders past the hips pre-tensions the core; the hips fire
first on the way back, releasing "effortless" pace.
- Benchmarks: groundstrokes **~25–30°**; one-handed backhand **~30°**;
  two-handed backhand **~20°** ([groundstroke biomechanics][grok]).
- Only measurable from **front/back** camera views (the rotation collapses in
  a side projection), so the engine view-gates it.
- **Drills:** cross-coil, hip-first rotation, backhand-coil.

### Wrist position & swing height — `contact_in_front`, `contact_height`, `wrist_finish_height`

**`contact_in_front`** (wrist ahead of the body at contact). Meeting the ball
in front transfers weight forward and controls direction; late contact means
the ball is playing you.
- Benchmarks: forehand **~30–40 cm** in front ([forehand metrics][oncourt]);
  one-handed backhand **~0.59 m**, two-handed **~0.40 m** (closer, more
  reaction time) ([1H vs 2H backhand kinematics][bh-kin]).
- Only measurable from side/diagonal views.

**`contact_height`** (strike height). Groundstrokes are grooved around a
comfortable waist-height zone; serves want a **high, fully stretched** contact
at **~100–110° of arm abduction** ([8-stage serve model][kovacs8]). A higher,
well-timed serve impact is the biomechanical link that turns shoulder strength
into serve speed ([toss zenith / impact height][toss-zenith]).

**`wrist_finish_height`** (follow-through height). A high finish proves you
accelerated **low-to-high** *through* the ball (the topspin path) instead of
decelerating into it. Modern "windshield-wiper" forehands may finish anywhere
from waist to over-the-shoulder depending on contact height, but the swing
still travels low-to-high ([windshield-wiper forehand][wiper]).
- **Drills:** drop-feed contact, jump-reach contact, stuck-finish, slow-finish.

### Timing — `prep_before_contact_ms`

Early preparation buys time. Racket back **before the bounce** on your side
(~600–1200 ms of prep) flows into a balanced contact; late prep cascades into
late contact and rushed feet. Cue: say "turn" as the ball crosses the net.

### Footwork — `split_step_rate`, `stance_width`, `recovery_steps`

Scored over rolling ~10 s windows, not per shot.
- **Split step:** a small hop timed to **land as the opponent strikes**, on the
  balls of the feet, ready to push off any direction ([split step][splitstep]).
- **Stance width:** base **wider than the shoulders** lowers the centre of
  mass and lets you load the outside leg ([footwork guide][footwork]).
- **Recovery:** quick shuffle/crossover steps back toward position, then
  re-split before the next ball. Low, economical steps — not high hops.

### The racquet tracker — `racquet_angle`, `racquet_height`, `racquet_drop`

MoveNet has no racquet keypoints, so RallyCoach tracks the racquet as a
**rigid extension of the forearm**: the frame leaves the hand at the wrist and
continues ~1.35 torso lengths along the elbow→wrist line, giving a
**handle → throat → tip** skeleton in the same units as the body
(`lib/core/engine/racquet.dart`, `python_lab/engine_math.py`). It is drawn live
over the player so you can see the racquet the coach is reading.

This reads the racquet-**arm line and gross orientation** — *not* the
open/closed **face twist** or the **grip**, which are wrist/hand-driven and
**not sensible from a 2D body pose** (they remain verbal-only coaching, like
before). What it adds:

- **`racquet_angle`** — the shaft angle from vertical **at contact**. On
  groundstrokes and volleys (view-gated to side/diagonal) the racquet should
  swing **on the line of the shot with the head leading**; a lagging or
  flicking head turns the face over and sprays direction. On the serve the same
  measure wants the racquet **vertical (tip up)** at a fully reached contact.
- **`racquet_height`** — the **frame-tip reach at contact** on the serve and
  overhead. Striking with the racquet **fully extended overhead** is your power
  and your downward margin into the box; below full stretch you lose both. It
  complements `contact_height` (the *wrist* height) by adding the racquet length.
- **`racquet_drop`** — the tip height at the serve **racket-drop** (the
  back-scratch). Reported for context but **not scored** from pose alone (the
  back-scratch depth is foreshortened and unreliable in 2D).

A **`racquet_confidence` (0–1)** rides on every shot: how sure the tracker is a
racquet was actually swung, from the **racquet-head sweep + arm extension**
(or, when bundled, an optical detector). When it is low the coach **hedges or
stays quiet** instead of confidently coaching a non-shot — this is what keeps a
stray empty-hand wave from being treated like a real stroke.

> **Upgrade path — optical racquet detector.** Everything above runs from the
> forearm estimate today. The data contract (`racquetPose(..., detected:)`)
> already accepts measured `handle/throat/tip` keypoints, so bundling a
> racquet-keypoint TFLite model later (`tool/fetch_models.sh --racquet`,
> hooked into the pose isolate exactly like MoveNet) upgrades **every racquet
> metric in place** — and makes `racquet_confidence` an **authoritative
> presence gate**, the robust fix for "I'm not even holding a racquet."

---

## 3. Stroke-by-stroke

### Forehand
Topspin drive on an **early unit turn**, a **low-to-high** swing, and **contact
out in front**. Power is legs + trunk + shoulder internal rotation, not arm.
- **Grip (verbal only):** Eastern or **Semi-Western** (most common modern
  forehand grip; easiest topspin) ([grips explained][grips]).
- **Checkpoints:** early shoulder turn · loaded knees · relaxed slightly-bent
  elbow · contact 30–40 cm in front · **racquet swinging on the line, head
  leading** (`racquet_angle`) · balanced low-to-high finish.
- **Common faults:** not turning the body (arming it), wrong grip blocking
  topspin, late prep → late contact, **racquet head lagging / flicking across
  the ball**, decelerating into a low finish ([common mistakes][mistakes]).

### Backhand (one- and two-handed)
The **one-hander** is an *open* kinetic chain needing a stable, fairly
**straight hitting arm** and a contact point well in front; the **two-hander**
is a *closed* chain — more stable, contact **closer** to the body, more
reaction time ([1H vs 2H kinematics][bh-kin]).
- **Grips (verbal only):** 1H — Eastern backhand / Continental hitting hand;
  2H — dominant Continental + non-dominant Eastern/Semi-Western.
- A flat **side view can't tell 1H from 2H apart**, so the engine scores the
  visible arm shape and contact geometry and uses a contact band wide enough
  to cover both.

### Serve
The most complex stroke — Kovacs & Ellenbecker's **8 stages**: start, release,
loading, **cocking/trophy**, acceleration, **contact**, deceleration, finish
([8-stage model][kovacs8]).
- **Trophy = fully loaded:** maximum knee bend (~115° interior) and lowest
  elbow, tossing arm up.
- **Toss:** straight-arm lift, slightly in front and to the racket side (not
  12 o'clock); **peak just above the contact point**. Consistency of the toss
  matters more than raw height ([toss zenith][toss-zenith]).
- **Contact:** reach **up** to ~100–110° arm abduction, elbow ~150° interior,
  the **racquet vertical (tip up) at full reach** (`racquet_angle`,
  `racquet_height`); behind the trophy the head **drops down the back**
  (`racquet_drop`).
- **Grip (verbal only):** **Continental** — it enables the pronation/internal
  rotation that creates pace and spin. A forehand "pancake" grip is a classic
  fault.
- **Common faults:** toss too low / dropping the tossing arm early (downward
  swing into the net), pancake grip, shallow knee bend, contact too low
  ([serve mistakes][serve-mistakes]).

### Volley
A compact **punch**, not a swing: short/no backswing, **firm wrist**, contact
clearly in front, body weight stepped through the ball. **Continental grip for
both wings** so there's no grip change at net speed ([volley technique][volley];
[backhand volley][bh-volley]).
- **Common faults:** big backswing (slow, less control), loose/whippy wrist
  (**racquet head flailing**, `racquet_angle`), late contact, standing tall
  instead of in a low base.

---

## 4. How this feeds the brain

| Surface | What it consumes | Where this knowledge lands |
|---|---|---|
| `assets/reference/*.json` | per-stroke/tier/phase ideal ranges + low/high cues | ranges validated against the sources here; `biomech_reference.py` now cites them inline |
| `assets/reference/coaching_knowledge.json` | structured faults→causes→fixes→drills, keyed to metric id + direction | the machine-readable form of this document |
| `assets/drills.json` | drills keyed by the metric id they fix | every fault here names the drill ids that target it |
| `lib/core/brain/lite_coach.dart` | offline "why this matters / how to fix it" per metric | mirrors the rationale and fixes documented here |
| `lib/core/engine/racquet.dart` | the racquet tracker (handle→throat→tip) + `racquet_confidence` | the second tracker; estimates the racquet from the forearm, detector-upgradable |
| Gemma prompts (`assets/prompts/`) | the LLM's "general tennis technique knowledge" + a low-racquet-confidence hedge | this document is that knowledge, made explicit and sourced |

Engine **shot-detection thresholds were not loosened or changed** by this work —
they were validated against the literature (`python3 validate_engine.py` stays
100% on the synthetic suite, now including the racquet checks). What grew is the
**coaching knowledge** wrapped around each measurement and the **racquet
tracker** layered on top of the body pose.

---

## Sources

- [Kovacs & Ellenbecker — An 8-Stage Model for Evaluating the Tennis Serve][kovacs8]
- [Kinematics during the tennis serve: systematic review & meta-analysis (Frontiers, 2024)][serve-meta]
- [The Effects of Knee Flexion on Tennis Serve Performance][knee-serve]
- [Knudson & Elliott — Biomechanics and tennis][s3] / [Kovacs review][biomech]
- [Biomechanics of the elbow joint in tennis players][elbow]
- [The Kinematics of Trunk and Upper Extremities in One- and Two-Handed Backhand][bh-kin]
- [Toss Zenith and Impact Height vs serve speed][toss-zenith]
- [Groundstroke biomechanics — kinetic chain, X-factor, separation angles][grok]
- [A Comparative Study on Biomechanics of Men's Tennis Forehand][comp-fh]
- [Tennis Forehand Analysis Metrics — contact 30–40 cm in front][oncourt]
- [The Importance of Shoulder Rotation in Groundstrokes — Feel Tennis][feeltennis-shoulder]
- [Windshield Wiper Forehand][wiper]
- [Tennis Grips Explained][grips]
- [The Split Step — US Sports Camps][splitstep]
- [Ultimate Tennis Footwork Guide][footwork]
- [How To Volley][volley] / [Backhand Volley Technique — Feel Tennis][bh-volley]
- [Tennis Techniques: The Complete Blueprint][letsgo]
- [Common tennis mistakes & fixes][mistakes] / [Serve mistakes][serve-mistakes]

[kovacs8]: https://pmc.ncbi.nlm.nih.gov/articles/PMC3445225/
[serve-meta]: https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2024.1432030/full
[knee-serve]: https://pmc.ncbi.nlm.nih.gov/articles/PMC8398391/
[s3]: https://pmc.ncbi.nlm.nih.gov/articles/PMC2577481/
[biomech]: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC2577481/
[elbow]: https://pmc.ncbi.nlm.nih.gov/articles/PMC2465285/
[bh-kin]: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3588639/
[toss-zenith]: https://pmc.ncbi.nlm.nih.gov/articles/PMC12641958/
[grok]: https://grokipedia.com/page/Groundstroke
[comp-fh]: https://www.2winpub.com/static/uploads/journalArticle/jyglts0202014.pdf
[oncourt]: https://www.oncourtai.co.uk/tennis-forehand-analysis
[feeltennis-shoulder]: https://www.feeltennis.net/shoulder-rotation/
[wiper]: https://tennisinstruction.com/windshield-wiper-forehand/
[grips]: https://tenniscompanion.org/tennis-grips/
[splitstep]: https://www.ussportscamps.com/tips/tennis/tennis-tip-foundation-of-good-footwork-split-step
[footwork]: https://www.tennisnation.com/free-lessons/technique/ultimate-tennis-footwork-guide/
[volley]: https://thetennistribe.com/volley-checklist/
[bh-volley]: https://www.feeltennis.net/backhand-volley-technique/
[letsgo]: https://letsgotennis.com/tennis-guide/tennis-techniques/
[mistakes]: https://topspinpro.com/blog/10-common-mistakes-tennis-players-make/
[serve-mistakes]: https://www.experiencecdt.com/single-post/top-5-serve-mistakes-our-coaches-see
