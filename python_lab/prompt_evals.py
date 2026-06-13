"""Prompt rendering check + adversarial validator fixtures.

Renders the shot-cue template against metric fixtures (sanity: all
placeholders fill) and emits test/fixtures/validator_cases.json — adversarial
LLM outputs the Dart cue_validator must accept/reject correctly (SPEC §9.4).

Run: python3 prompt_evals.py
"""
import json
import os

ROOT = os.path.join(os.path.dirname(__file__), "..")
TEMPLATE = os.path.join(ROOT, "assets", "prompts", "shot_cue.txt")
OUT = os.path.join(ROOT, "test", "fixtures", "validator_cases.json")

# Joint/phase lexicon: maps claim keywords in an LLM cue to metric ids.
# The validator extracts keywords and requires ≥1 mapped metric to have
# actually deviated this shot (or recurred in the last 10).
LEXICON = {
    "elbow": ["elbow_angle"],
    "arm": ["elbow_angle"],
    "extend": ["elbow_angle"],
    "extension": ["elbow_angle"],
    "shoulder": ["shoulder_turn", "hip_shoulder_sep"],
    "turn": ["shoulder_turn", "hip_shoulder_sep"],
    "coil": ["shoulder_turn", "hip_shoulder_sep"],
    "rotate": ["shoulder_turn", "hip_shoulder_sep"],
    "knee": ["knee_flexion"],
    "knees": ["knee_flexion"],
    "legs": ["knee_flexion"],
    "low": ["knee_flexion"],
    "lower": ["knee_flexion"],
    "front": ["contact_in_front"],
    "early": ["contact_in_front", "prep_before_contact_ms"],
    "earlier": ["contact_in_front", "prep_before_contact_ms"],
    "late": ["prep_before_contact_ms"],
    "rush": ["prep_before_contact_ms"],
    "prep": ["prep_before_contact_ms"],
    "preparation": ["prep_before_contact_ms"],
    "finish": ["wrist_finish_height"],
    "follow": ["wrist_finish_height"],
    "balance": ["trunk_tilt"],
    "balanced": ["trunk_tilt"],
    "upright": ["trunk_tilt"],
    "lean": ["trunk_tilt"],
    "reach": ["contact_height", "elbow_angle"],
    "higher": ["contact_height", "wrist_finish_height"],
    "contact": ["contact_in_front", "contact_height", "elbow_angle"],
    "split": ["split_step_rate"],
    "stance": ["stance_width"],
    "base": ["stance_width"],
    "wider": ["stance_width"],
    "recover": ["recovery_steps"],
    "recovery": ["recovery_steps"],
    "racquet": ["racquet_angle", "racquet_height"],
    "racket": ["racquet_angle", "racquet_height"],
    "face": ["racquet_angle"],
    "head": ["racquet_angle"],
    "vertical": ["racquet_angle"],
    "tip": ["racquet_height"],
    "drop": ["racquet_drop"],
}

# Each case: LLM cue text, the shot's deviated metric ids, recently spoken
# cues, expected verdict + reason.
CASES = [
    {"cue": "Turn those shoulders earlier on the takeback",
     "deviated": ["shoulder_turn", "prep_before_contact_ms"],
     "recent": [], "expect": "accept", "reason": "maps to real deviation"},
    {"cue": "Extend through contact, arm stays too bent",
     "deviated": ["elbow_angle"],
     "recent": [], "expect": "accept", "reason": "elbow deviated"},
    {"cue": "Bend your knees more on preparation",
     "deviated": ["shoulder_turn"],
     "recent": [], "expect": "reject", "reason": "knee did not deviate"},
    {"cue": "Your elbow angle was 112 degrees, extend it",
     "deviated": ["elbow_angle"],
     "recent": [], "expect": "reject", "reason": "contains numbers"},
    {"cue": "Great swing, keep doing exactly what you are doing out there my friend",
     "deviated": ["elbow_angle"],
     "recent": [], "expect": "reject", "reason": "no metric keyword (>0 deviations exist)"},
    {"cue": "Work on your wrist snap through the kinetic chain transition phase dynamics today okay",
     "deviated": ["elbow_angle"],
     "recent": [], "expect": "reject", "reason": "over 14 words"},
    {"cue": "Turn those shoulders earlier on the takeback",
     "deviated": ["shoulder_turn"],
     "recent": ["Turn those shoulders earlier on the takeback"],
     "expect": "reject", "reason": "duplicates a recent cue"},
    {"cue": "Stay low through the hit",
     "deviated": ["knee_flexion"],
     "recent": [], "expect": "accept", "reason": "'low' maps to knee_flexion"},
    {"cue": "Meet the ball further out in front",
     "deviated": ["contact_in_front"],
     "recent": [], "expect": "accept", "reason": "contact point deviated"},
    {"cue": "Reach higher at contact",
     "deviated": ["contact_height"],
     "recent": [], "expect": "accept", "reason": "serve height deviated"},
    {"cue": "Take your vitamins and hydrate before the match",
     "deviated": ["elbow_angle"],
     "recent": [], "expect": "reject", "reason": "off-topic, no mapping"},
    {"cue": "Finish higher over the shoulder",
     "deviated": ["wrist_finish_height", "shoulder_turn"],
     "recent": [], "expect": "accept", "reason": "finish height deviated"},
    {"cue": "",
     "deviated": ["elbow_angle"],
     "recent": [], "expect": "reject", "reason": "empty output"},
    {"cue": "Split step before every ball",
     "deviated": ["split_step_rate"],
     "recent": [], "expect": "accept", "reason": "footwork metric deviated"},
    {"cue": "Earlier shoulder turn next time, 7 of 10 were late",
     "deviated": ["shoulder_turn"],
     "recent": [], "expect": "reject", "reason": "contains numbers"},
    {"cue": "Wider base when you set up",
     "deviated": ["stance_width"],
     "recent": [], "expect": "accept", "reason": "stance deviated"},
    {"cue": "Let the racquet extend through the line",
     "deviated": ["racquet_angle"],
     "recent": [], "expect": "accept", "reason": "racquet angle deviated"},
    {"cue": "Keep the racquet face steady through it",
     "deviated": ["knee_flexion"],
     "recent": [], "expect": "reject", "reason": "racquet did not deviate"},
]


def render_template_check():
    with open(TEMPLATE) as f:
        tpl = f.read()
    fields = {
        "personality_name": "Coach K", "personality_style": "Direct, no fluff.",
        "skill_tier": "intermediate", "handedness": "right",
        "session_type": "forehand", "stroke": "forehand", "score": "64",
        "deviations": "  shoulder_turn: 18 deg short (recurring: 7 of last 10)\n"
                      "  elbow_angle at contact: 12 deg below ideal",
        "shot_number": "28", "trend": "-4",
        "recent_cues": "[extend through contact; stay low]",
        # Optional context slots the live template now exposes (filled by the
        # Dart PromptBuilder; empty here keeps the render-sanity check honest).
        "session_focus": "", "goal_metric": "", "racquet_note": "",
    }
    rendered = tpl
    for k, v in fields.items():
        rendered = rendered.replace("{" + k + "}", v)
    leftover = [w for w in rendered.split() if w.startswith("{") and w.endswith("}")]
    assert "{" not in rendered, f"unfilled placeholders: {leftover or rendered}"
    print("shot_cue.txt renders cleanly:")
    print("---\n" + rendered + "---")


def main():
    render_template_check()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        # Source of truth for max_words is assets/prompts/cue_lexicon.json (16);
        # the Dart cue_validator_test deep-equals the two, so they must match.
        json.dump({"lexicon": LEXICON, "cases": CASES, "max_words": 16}, f, indent=1)
    print(f"wrote {OUT} ({len(CASES)} cases)")


if __name__ == "__main__":
    main()
