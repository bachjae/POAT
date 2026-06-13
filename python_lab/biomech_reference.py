"""Biomechanics reference library builder.

Encodes per-stroke, per-skill-tier, per-phase ideal ranges from published
coaching literature (ITF/USPTA coaching manuals, Elliott et al. biomechanics
studies) and emits the reference JSONs the app bundles in assets/reference/.

Angle conventions (degrees):
  - elbow_angle: interior angle shoulder-elbow-wrist (180 = straight arm)
  - knee_flexion: interior angle hip-knee-ankle (180 = straight leg)
  - trunk_tilt: deviation of shoulder-mid->hip-mid line from vertical
  - shoulder_turn: rotation of the shoulder line relative to its address angle
  - hip_shoulder_sep: shoulder_turn minus hip_turn (X-factor)
Timing in milliseconds before contact.

NOTE on conventions vs the literature: sports-science papers report JOINT
FLEXION (0 = straight), whereas this engine uses the INTERIOR angle
(180 = straight). Convert with interior = 180 - flexion. Example: a serve
front-knee flexion of 64.5 deg at the trophy == ~115.5 deg interior, which
sits inside the serve preparation knee_flexion band below.

SOURCES (the human-readable dossier with full citations and the
metric-by-metric coaching knowledge lives in
docs/TENNIS_COACHING_KNOWLEDGE.md and assets/reference/coaching_knowledge.json):
  [S1] Kovacs & Ellenbecker, "An 8-Stage Model for Evaluating the Tennis
       Serve" (PMC3445225) - serve phases; trophy = max knee flexion + lowest
       elbow; contact ~100-110 deg arm abduction.
  [S2] "Kinematics characteristics ... during tennis serve: systematic review
       and meta-analysis", Frontiers 2024 (PMC11260724) - front-knee flexion
       at trophy 64.5 +/- 9.7 deg; elbow flexion at impact 30.1 +/- 15.9 deg
       (~150 deg interior).
  [S3] Knudson/Elliott, "Biomechanics and tennis" (PMC2577481) - kinetic chain,
       proximal-to-distal sequencing, groundstroke power.
  [S4] One- vs two-handed backhand kinematics (PMC3588639) - contact in front
       ~0.59 m (1H) vs ~0.40 m (2H); open vs closed kinetic chain.
  [S5] Groundstroke X-factor / hip-shoulder separation ~25-30 deg (1H BH ~30,
       2H BH ~20). [S6] The Effects of Knee Flexion on Serve Performance
       (PMC8398391) - deeper bend -> more vertical drive and serve speed.
Each stroke block below is annotated with the [S#] it draws on.

Run: python3 biomech_reference.py  (writes ../assets/reference/*.json)
"""
import json
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "reference")

ALL_VIEWS = ["side_left", "side_right", "front", "back", "diagonal_left", "diagonal_right"]
SIDE_DIAG = ["side_left", "side_right", "diagonal_left", "diagonal_right"]


def m(mid, ideal, weight, views, cue_low, cue_high, tolerance=None):
    """Metric entry. tolerance = degrees beyond ideal range at which score hits 0
    (defaults to the ideal range width)."""
    entry = {
        "id": mid,
        "ideal": ideal,
        "weight": weight,
        "views": views,
        "cue_low": cue_low,
        "cue_high": cue_high,
    }
    if tolerance is not None:
        entry["tolerance"] = tolerance
    return entry


def scale_ranges(phases, widen):
    """Beginner tiers get wider ideal bands; advanced narrower."""
    out = {}
    for phase, spec in phases.items():
        metrics = []
        for mm in spec["metrics"]:
            lo, hi = mm["ideal"]
            mid = (lo + hi) / 2.0
            half = (hi - lo) / 2.0 * widen
            mm2 = dict(mm)
            mm2["ideal"] = [round(mid - half, 1), round(mid + half, 1)]
            metrics.append(mm2)
        out[phase] = {"metrics": metrics}
    return out


# ---- Forehand (intermediate baseline; Elliott 2006, USPTA stroke standards) ----
FOREHAND_PHASES = {
    "preparation": {
        "metrics": [
            m("shoulder_turn", [70, 110], 0.30, ALL_VIEWS,
              "turn those shoulders earlier and fuller",
              "shorten the shoulder turn a touch"),
            m("knee_flexion", [120, 150], 0.20, ALL_VIEWS,
              "sit lower into your legs",
              "stay a bit taller through prep"),
            m("trunk_tilt", [0, 15], 0.10, ALL_VIEWS,
              "stand a little more upright",
              "lean into the court slightly"),
        ]
    },
    "backswing": {
        "metrics": [
            m("elbow_angle", [90, 140], 0.20, ALL_VIEWS,
              "let the arm relax back further",
              "keep the takeback more compact"),
            # X-factor groundstroke separation ~25-30 deg [S5]; band centred
            # there with tier-scaled width (front/back views only — the
            # rotation collapses in side projection).
            m("hip_shoulder_sep", [15, 40], 0.25, ["front", "back"],
              "coil hips and shoulders together more",
              "ease the coil — you're over-rotating"),
        ]
    },
    "contact": {
        "metrics": [
            m("elbow_angle", [120, 155], 0.30, ALL_VIEWS,
              "extend through contact — arm's too bent",
              "soften the elbow slightly at contact"),
            m("contact_in_front", [0.15, 0.60], 0.30, SIDE_DIAG,
              "meet the ball further out in front",
              "let the ball come to you a touch"),
            m("knee_flexion", [130, 160], 0.15, ALL_VIEWS,
              "drive up from the legs at contact",
              "stay grounded through the hit"),
        ]
    },
    "follow_through": {
        "metrics": [
            m("wrist_finish_height", [0.9, 1.8], 0.25, ALL_VIEWS,
              "finish higher — over the shoulder",
              "relax the finish, let it wrap"),
            m("trunk_tilt", [0, 20], 0.10, ALL_VIEWS,
              "stay balanced — don't fall away",
              "stay balanced — don't fall away"),
        ]
    },
}

# ---- Backhand (1H/2H; contact-in-front & coil per [S4], [S5]) ----
# Contact band is generous to span both the further-in-front one-hander
# (~0.59 m) and the closer two-hander (~0.40 m), which a 2D side view cannot
# tell apart. Hitting-arm elbow runs straighter than the forehand at contact.
BACKHAND_PHASES = {
    "preparation": {
        "metrics": [
            m("shoulder_turn", [80, 120], 0.30, ALL_VIEWS,
              "bigger shoulder turn — show your back",
              "shorten the shoulder turn a touch"),
            m("knee_flexion", [120, 150], 0.20, ALL_VIEWS,
              "sit lower into your legs",
              "stay a bit taller through prep"),
        ]
    },
    "backswing": {
        "metrics": [
            m("elbow_angle", [120, 165], 0.25, ALL_VIEWS,
              "set a straighter hitting arm early",
              "soften the arm in the takeback"),
            m("hip_shoulder_sep", [15, 40], 0.20, ["front", "back"],
              "coil hips and shoulders together more",
              "ease the coil — you're over-rotating"),
        ]
    },
    "contact": {
        "metrics": [
            m("elbow_angle", [140, 175], 0.30, ALL_VIEWS,
              "straighten the arm through contact",
              "keep a touch of give in the elbow"),
            m("contact_in_front", [0.20, 0.70], 0.30, SIDE_DIAG,
              "meet the ball further out in front",
              "let the ball come to you a touch"),
        ]
    },
    "follow_through": {
        "metrics": [
            m("wrist_finish_height", [0.8, 1.7], 0.25, ALL_VIEWS,
              "extend the finish up and through",
              "relax the finish"),
        ]
    },
}

# ---- Serve (8-stage model [S1]; angles from meta-analysis [S2], [S6]) ----
# Trophy = fully loaded: deep knee bend (front-knee flexion ~64.5 deg ==
# ~115 deg interior, inside the [105,140] prep band) and lowest elbow. Impact
# reaches toward extension (elbow flexion ~30 deg == ~150 deg interior) at
# ~100-110 deg arm abduction (the contact_height band).
SERVE_PHASES = {
    "preparation": {
        "metrics": [
            m("knee_flexion", [105, 140], 0.30, ALL_VIEWS,
              "deeper knee bend before you launch",
              "less knee bend — stay springy"),
            m("trunk_tilt", [0, 30], 0.15, ALL_VIEWS,
              "tilt up into the toss more",
              "keep the tilt under control"),
        ]
    },
    "backswing": {
        "metrics": [
            m("elbow_angle", [70, 110], 0.30, ALL_VIEWS,
              "drop the racket head deeper",
              "keep the trophy elbow compact"),
            m("shoulder_turn", [60, 100], 0.20, ALL_VIEWS,
              "turn the shoulders away more in the trophy",
              "ease the shoulder coil"),
        ]
    },
    "contact": {
        "metrics": [
            m("elbow_angle", [150, 180], 0.35, ALL_VIEWS,
              "reach up — full extension at contact",
              "reach up — full extension at contact"),
            m("contact_height", [1.9, 2.6], 0.25, ALL_VIEWS,
              "contact higher — stretch for it",
              "let contact settle a touch lower"),
        ]
    },
    "follow_through": {
        "metrics": [
            m("trunk_tilt", [0, 40], 0.20, ALL_VIEWS,
              "drive the chest through the court",
              "stay tall through the finish"),
        ]
    },
}

# ---- Volley (compact punch; firm arm, short backswing, contact in front) ----
VOLLEY_PHASES = {
    "preparation": {
        "metrics": [
            m("knee_flexion", [120, 155], 0.30, ALL_VIEWS,
              "lower base — bend the knees at net",
              "stay a touch taller"),
            m("shoulder_turn", [20, 60], 0.25, ALL_VIEWS,
              "small unit turn — set the shoulders",
              "less turn — volleys are compact"),
        ]
    },
    "contact": {
        "metrics": [
            m("elbow_angle", [120, 160], 0.30, ALL_VIEWS,
              "firmer arm — punch through the volley",
              "soften slightly, don't lock out"),
            m("contact_in_front", [0.25, 0.80], 0.35, SIDE_DIAG,
              "take it earlier, out in front",
              "let it come to you a touch"),
        ]
    },
    "follow_through": {
        "metrics": [
            m("wrist_finish_height", [0.6, 1.4], 0.20, ALL_VIEWS,
              "hold the finish — no big swing",
              "shorten the follow-through, it's a punch"),
        ]
    },
}

# Footwork is windowed, not per-shot (SPEC §7): continuous metrics per 10s
# window. Split step lands as the opponent strikes; base wider than the
# shoulders; quick economical recovery back to position ([S3] + USTA footwork).
FOOTWORK_WINDOW_METRICS = [
    m("split_step_rate", [0.5, 1.0], 0.35, ALL_VIEWS,
      "split step before every move",
      "split step before every move"),
    m("stance_width", [0.9, 1.6], 0.30, ALL_VIEWS,
      "wider base — feet outside the shoulders",
      "bring the feet in a touch"),
    m("recovery_steps", [2, 6], 0.35, ALL_VIEWS,
      "recover with quick shuffle steps",
      "calm the feet between balls"),
]

TIMING = {
    "forehand": {"prep_before_contact_ms": [600, 1200]},
    "backhand": {"prep_before_contact_ms": [600, 1200]},
    "serve": {"prep_before_contact_ms": [800, 1600]},
    "volley": {"prep_before_contact_ms": [250, 700]},
}

WIDEN = {"beginner": 1.5, "intermediate": 1.0, "advanced": 0.75}


# Serve toss metrics measured at the bimanual divergence peak (left wrist
# height / left-right wrist gap, torso units). Hand-calibrated per tier —
# the generic WIDEN factors over-stretch these short bands, so they bypass
# scale_ranges.
SERVE_TOSS_BY_TIER = {
    "beginner": {"toss_height": [0.6, 2.0], "wrist_divergence": [0.2, 1.2]},
    "intermediate": {"toss_height": [0.7, 1.9], "wrist_divergence": [0.3, 1.1]},
    "advanced": {"toss_height": [0.8, 1.8], "wrist_divergence": [0.35, 1.0]},
}


# ---- Racquet metrics (the second tracker; SPEC §5a) -----------------------
# Measured from the racquet skeleton (handle->throat->tip). With no optical
# detector bundled the racquet is estimated as a rigid forearm extension, so
# `racquet_angle` (shaft angle from vertical at contact) and `racquet_height`
# (frame-tip reach at contact) read the racquet-ARM line, not the racquet-face
# twist (which is documented as detector-only / not pose-sensible). Bands are
# calibrated to the extended, on-line racquet position each stroke wants and
# kept tier-independent (the estimate isn't precise enough to justify
# tier-tightening) and low-weight, so the racquet refines a shot's score and
# cues without ever outvoting the body metrics. Appended after scale_ranges.
RACQUET_BY_STROKE = {
    "forehand": {
        "contact": [
            m("racquet_angle", [150, 180], 0.12, SIDE_DIAG,
              "let the racquet extend through the line of the shot",
              "control the racquet head — don't fling it past contact"),
        ],
    },
    "backhand": {
        "contact": [
            m("racquet_angle", [140, 180], 0.12, SIDE_DIAG,
              "drive the racquet straight through the contact line",
              "keep the racquet head controlled through the hit"),
        ],
    },
    "volley": {
        "contact": [
            m("racquet_angle", [115, 180], 0.12, SIDE_DIAG,
              "firm racquet face — punch it through, no droop",
              "steady the face — it's a block, not a flick"),
        ],
    },
    "serve": {
        "contact": [
            m("racquet_angle", [0, 25], 0.18, ALL_VIEWS,
              "keep reaching straight up at contact",
              "reach UP — get the racquet vertical, not swinging out"),
            m("racquet_height", [3.0, 4.0], 0.18, ALL_VIEWS,
              "stretch taller — get the racquet tip up at contact",
              "settle the contact a touch — you're overreaching"),
        ],
    },
}


def build(stroke, phases):
    doc = {"stroke": stroke, "skill_levels": {}}
    for tier, widen in WIDEN.items():
        node = {
            "phases": scale_ranges(phases, widen),
            "timing": TIMING.get(stroke, {}),
        }
        if stroke == "serve":
            bands = SERVE_TOSS_BY_TIER[tier]
            node["phases"]["preparation"]["metrics"] += [
                m("toss_height", bands["toss_height"], 0.25, ALL_VIEWS,
                  "toss the ball higher — reach up on the release",
                  "toss slightly lower and in front"),
                # Left/right wrist separation collapses in side projection.
                m("wrist_divergence", bands["wrist_divergence"], 0.15,
                  ["front", "diagonal_left", "diagonal_right"],
                  "separate the tossing arm from the racket arm earlier",
                  "keep the toss synchronized with the trophy position"),
            ]
        # Racquet metrics (tier-independent), appended after the tier scaling.
        for phase, metrics in RACQUET_BY_STROKE.get(stroke, {}).items():
            node["phases"].setdefault(phase, {"metrics": []})
            node["phases"][phase]["metrics"] += [dict(mm) for mm in metrics]
        doc["skill_levels"][tier] = node
    return doc


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    strokes = {
        "forehand": FOREHAND_PHASES,
        "backhand": BACKHAND_PHASES,
        "serve": SERVE_PHASES,
        "volley": VOLLEY_PHASES,
    }
    for stroke, phases in strokes.items():
        path = os.path.join(OUT_DIR, f"{stroke}.json")
        with open(path, "w") as f:
            json.dump(build(stroke, phases), f, indent=2)
        print(f"wrote {path}")

    footwork = {"stroke": "footwork", "window_seconds": 10, "skill_levels": {}}
    for tier, widen in WIDEN.items():
        footwork["skill_levels"][tier] = {
            "phases": scale_ranges({"window": {"metrics": FOOTWORK_WINDOW_METRICS}}, widen),
            "timing": {},
        }
    path = os.path.join(OUT_DIR, "footwork.json")
    with open(path, "w") as f:
        json.dump(footwork, f, indent=2)
    print(f"wrote {path}")


if __name__ == "__main__":
    main()
