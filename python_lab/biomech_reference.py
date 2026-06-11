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

# Footwork is windowed, not per-shot (SPEC §7): continuous metrics per 10s window.
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


def build(stroke, phases):
    doc = {"stroke": stroke, "skill_levels": {}}
    for tier, widen in WIDEN.items():
        doc["skill_levels"][tier] = {
            "phases": scale_ranges(phases, widen),
            "timing": TIMING.get(stroke, {}),
        }
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
