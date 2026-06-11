"""Builds the three coach phrase banks -> assets/phrases/{maya,coach_k,doc}.json.

Each cue slot gets the shared imperative stems plus personality-decorated
variants (Maya warms them, Coach K sharpens them, Doc adds the mechanism),
so every coach reads distinctly while the technique content stays identical
to the validated reference cues. Constraints enforced here and re-checked by
test/phrase_banks_test.dart: <=8 words, no digits, >=10 variants per cue slot.

Run: python3 build_phrase_banks.py
"""
import json
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "phrases")

# Six neutral imperative stems per (metric, direction), <=6 words each.
STEMS = {
    ("shoulder_turn", "low"): [
        "turn those shoulders earlier",
        "fuller shoulder turn",
        "show your back to the net",
        "coil the shoulders before the bounce",
        "bigger turn on the takeback",
        "shoulders around sooner",
    ],
    ("shoulder_turn", "high"): [
        "shorten the shoulder turn",
        "ease off the coil",
        "less wind-up this time",
        "smaller turn, same intent",
        "keep the turn compact",
        "don't over-rotate the shoulders",
    ],
    ("knee_flexion", "low"): [
        "sit lower into your legs",
        "bend those knees",
        "get your base lower",
        "drop the seat an inch",
        "stay low through the shot",
        "more knee bend on the prep",
    ],
    ("knee_flexion", "high"): [
        "stay a touch taller",
        "less squat, more spring",
        "ease up on the knee bend",
        "don't sink so deep",
        "lighter in the legs",
        "rise out of the crouch slightly",
    ],
    ("trunk_tilt", "low"): [
        "stand a little more upright",
        "lift the chest",
        "tall through the spine",
        "straighten up at address",
        "posture up before the swing",
        "keep the trunk vertical",
    ],
    ("trunk_tilt", "high"): [
        "stay balanced, don't lean away",
        "quiet upper body",
        "keep the chest steady",
        "no falling off the shot",
        "control the lean",
        "finish on balance",
    ],
    ("elbow_angle", "low"): [
        "extend through contact",
        "free the arm out",
        "unbend that elbow",
        "reach through the ball",
        "longer arm at the hit",
        "stretch the hitting arm",
    ],
    ("elbow_angle", "high"): [
        "soften the elbow slightly",
        "give the arm some flex",
        "don't lock the arm out",
        "relax the hitting elbow",
        "a touch of bend at contact",
        "keep the arm springy",
    ],
    ("hip_shoulder_sep", "low"): [
        "coil shoulders past the hips",
        "stretch the spring on the takeback",
        "separate shoulders from hips",
        "load the torso twist",
        "wind the upper body more",
        "let the shoulders lead the coil",
    ],
    ("hip_shoulder_sep", "high"): [
        "ease the coil back",
        "less twist, more timing",
        "don't over-wind the torso",
        "smooth out the separation",
        "calm the coil down",
        "match hips and shoulders better",
    ],
    ("contact_in_front", "low"): [
        "meet the ball out in front",
        "take it earlier",
        "contact further forward",
        "strike before it gets deep",
        "reach the contact point sooner",
        "play the ball in front",
    ],
    ("contact_in_front", "high"): [
        "let the ball come to you",
        "wait on it a touch",
        "don't chase the contact",
        "take it a beat later",
        "relax, it will arrive",
        "stay patient at contact",
    ],
    ("contact_height", "low"): [
        "contact higher, stretch for it",
        "reach up at the hit",
        "go get it at the top",
        "full stretch to the ball",
        "strike at the peak",
        "taller contact point",
    ],
    ("contact_height", "high"): [
        "let contact settle lower",
        "don't overreach the toss",
        "bring the strike zone down",
        "hit it a touch lower",
        "ease the reach back",
        "find a comfortable height",
    ],
    ("wrist_finish_height", "low"): [
        "finish higher over the shoulder",
        "swing up through the finish",
        "complete the follow-through",
        "let the racket wrap high",
        "finish tall",
        "carry the swing all the way",
    ],
    ("wrist_finish_height", "high"): [
        "relax the finish",
        "let the follow-through breathe",
        "don't force the wrap",
        "softer finish this time",
        "ease the racket down",
        "smooth, not stiff, at the end",
    ],
    ("prep_before_contact_ms", "low"): [
        "start the preparation earlier",
        "racket back sooner",
        "prepare before the bounce",
        "earlier takeback, easier swing",
        "beat the ball with your prep",
        "no rushing, start sooner",
    ],
    ("prep_before_contact_ms", "high"): [
        "don't rush, let the swing breathe",
        "smooth tempo, no hurry",
        "give the swing its time",
        "relax the rhythm",
        "easy on the trigger",
        "let the shot develop",
    ],
    ("split_step_rate", "low"): [
        "split step before every ball",
        "hop as they hit",
        "land ready, every time",
        "small bounce, big readiness",
        "feet alive before each shot",
        "time the split step",
    ],
    ("split_step_rate", "high"): [
        "calm the feet between balls",
        "save the hops for the hit",
        "settle the rhythm down",
        "quieter feet, same readiness",
        "fewer bounces, better timing",
        "relax between shots",
    ],
    ("stance_width", "low"): [
        "wider base, feet outside shoulders",
        "spread the stance",
        "build a bigger platform",
        "feet apart for balance",
        "widen up before the swing",
        "strong wide base",
    ],
    ("stance_width", "high"): [
        "bring the feet in a touch",
        "narrow the base slightly",
        "stance a bit tighter",
        "don't over-spread the feet",
        "comfortable width, not a split",
        "ease the stance in",
    ],
    ("recovery_steps", "low"): [
        "recover with quick shuffle steps",
        "back to the middle, fast feet",
        "shuffle home after every shot",
        "quick steps to reset",
        "never watch, recover",
        "move back before the reply",
    ],
    ("recovery_steps", "high"): [
        "calm the recovery down",
        "fewer, bigger reset steps",
        "smooth recovery, no scramble",
        "easy feet on the way back",
        "controlled steps to the middle",
        "reset with rhythm",
    ],
}

PERSONALITIES = {
    "maya": {
        "name": "Maya",
        "tagline": "encouraging",
        "style": "Encouraging, warm, celebrates real progress with specific praise, never fake.",
        "preview": "Hey, I'm Maya. Let's find your best tennis.",
        "pitch": 1.15,
        "rate": 0.95,
        "prefixes": ["Come on — ", "You've got this — ", "There it is — ",
                     "Nearly there — "],
        "encourage": [
            "yes, that's the swing",
            "beautiful, keep that feeling",
            "there's the shot we want",
            "love that adjustment",
            "that one flowed",
            "great correction, it showed",
            "you found it that time",
            "clean, really clean",
            "that's the player I coach for",
            "see how easy that felt",
            "strong, balanced, lovely",
            "keep stacking those",
            "good rhythm right now",
        ],
        "ack": [
            "good", "better", "nice work", "that's closer", "yes",
            "there you go", "improving", "that counts", "solid",
            "trend is up", "cleaner", "okay, building now",
        ],
        "filler": [
            "stay with me",
            "breathe and reset",
            "next ball, fresh start",
            "you're doing the work",
            "keep the energy up",
            "patience, it's coming",
            "one swing at a time",
            "trust the practice",
            "let's keep rolling",
            "settle in, no hurry",
            "find your rhythm again",
            "stay loose out there",
        ],
        "system:see_you": [
            "I can see you",
            "got you, looking great",
            "there you are, ready when you are",
            "perfect spot, I see everything",
        ],
        "system:lost_you": [
            "I lost you — step back into frame",
            "where'd you go? step back in",
            "come back into view for me",
            "I can't see you, shift back",
        ],
        "system:paused": [
            "Paused — step back in when ready",
            "take your time, we're paused",
            "paused, breathe a moment",
            "we'll pick it up when you're back",
        ],
        "system:session_start": [
            "let's get to work",
            "okay, show me what you've got",
            "here we go, have fun with it",
            "fresh session, fresh swings",
        ],
        "system:session_end": [
            "great session, let's look at it",
            "done — be proud of that work",
            "that's a wrap, nice effort",
            "session complete, come see your numbers",
        ],
        "system:limited_view": [
            "limited angle, footwork cues only",
            "only your feet are clear from here",
            "angle's tight, focusing on footwork",
            "move me for more, footwork for now",
        ],
    },
    "coach_k": {
        "name": "Coach K",
        "tagline": "direct",
        "style": "Direct, terse, imperative, zero fluff. Says what to fix and moves on.",
        "preview": "Coach K. We fix things here.",
        "pitch": 0.9,
        "rate": 1.0,
        "prefixes": ["Again: ", "Fix it: ", "Now: ", "Every time: "],
        "encourage": [
            "that's it, lock it in",
            "good, do it again",
            "that's the standard",
            "correct, repeat it",
            "now we're working",
            "that's a real shot",
            "keep that, exactly that",
            "better, hold the standard",
            "clean rep",
            "that swing earns the next drill",
            "no notes on that one",
            "strong, again",
        ],
        "ack": [
            "good", "again", "better", "right", "yes", "that works",
            "acceptable", "cleaner", "closer", "keep going", "more",
            "hold that",
        ],
        "filler": [
            "reset",
            "next ball",
            "stay sharp",
            "focus up",
            "work the feet",
            "no coasting",
            "earn the next one",
            "concentrate",
            "back to it",
            "details win",
            "keep the intensity",
            "stay on task",
        ],
        "system:see_you": [
            "I can see you",
            "in frame, let's work",
            "got you, begin",
            "visible, start hitting",
        ],
        "system:lost_you": [
            "I lost you — step back into frame",
            "out of frame, fix it",
            "can't coach what I can't see",
            "step back in, now",
        ],
        "system:paused": [
            "Paused — step back in when ready",
            "paused, return when serious",
            "on hold, your call",
            "paused, clock's still running",
        ],
        "system:session_start": [
            "work begins now",
            "session on, no warm-up excuses",
            "begin, full attention",
            "go time",
        ],
        "system:session_end": [
            "session over, review the numbers",
            "done, the data doesn't lie",
            "that's time, debrief now",
            "wrap it, summary's ready",
        ],
        "system:limited_view": [
            "limited angle, footwork cues only",
            "bad angle, footwork only",
            "reposition me for full coaching",
            "view's restricted, working with feet",
        ],
    },
    "doc": {
        "name": "Doc",
        "tagline": "analytical",
        "style": "Analytical, precise, briefly explains the mechanism behind each cue.",
        "preview": "I'm Doc. We'll work on the why.",
        "pitch": 1.0,
        "rate": 0.9,
        "prefixes": ["Key point: ", "Watch this: ", "Mechanically: ",
                     "Remember: "],
        "encourage": [
            "that's the kinetic chain working",
            "textbook sequencing there",
            "the geometry was right on that one",
            "energy transfer was clean",
            "that's what efficiency feels like",
            "good mechanics produce that easily",
            "the model swing, well done",
            "your levers worked together",
            "that contact was structurally sound",
            "exactly the pattern we want",
            "repeatable, that's the goal",
            "the data will like that one",
        ],
        "ack": [
            "confirmed", "better mechanics", "improved", "good pattern",
            "that's progress", "measurably better", "yes", "cleaner shape",
            "on model", "trending right", "sound", "accepted",
        ],
        "filler": [
            "process the last one",
            "small adjustments compound",
            "consistency beats power",
            "think shape, not strength",
            "the pattern is forming",
            "review, then swing",
            "feel where the racket is",
            "every rep is data",
            "steady accumulation",
            "let the technique settle",
            "observe your own balance",
            "quality over volume",
        ],
        "system:see_you": [
            "I can see you",
            "full skeleton visible, proceed",
            "tracking established",
            "good position, all joints visible",
        ],
        "system:lost_you": [
            "I lost you — step back into frame",
            "tracking dropped, step back in",
            "no pose data, reposition please",
            "you've left my field of view",
        ],
        "system:paused": [
            "Paused — step back in when ready",
            "analysis paused, resume when ready",
            "on pause, data retained",
            "paused, your session is safe",
        ],
        "system:session_start": [
            "beginning analysis",
            "data collection started, swing naturally",
            "measuring from here on",
            "session live, be yourself",
        ],
        "system:session_end": [
            "analysis complete, results ready",
            "session closed, summary computed",
            "done, the numbers are in",
            "ending capture, review awaits",
        ],
        "system:limited_view": [
            "limited angle, footwork cues only",
            "occluded joints, footwork analysis only",
            "partial visibility, lower body only",
            "angle limits me to footwork",
        ],
    },
}


def build_bank(pid, p):
    phrases = {}
    for (metric, direction), stems in STEMS.items():
        variants = list(stems)
        for i, stem in enumerate(stems[:4]):
            prefix = p["prefixes"][i % len(p["prefixes"])]
            decorated = prefix + stem
            if len(decorated.split()) <= 8:
                variants.append(decorated)
        # Pad with remaining stems re-decorated if the word cap dropped any.
        i = 0
        while len(variants) < 10:
            decorated = p["prefixes"][(i + 1) % len(p["prefixes"])] + stems[4 + (i % 2)]
            if len(decorated.split()) <= 8 and decorated not in variants:
                variants.append(decorated)
            i += 1
        phrases[f"cue:{metric}:{direction}"] = variants
    for slot in ["encourage", "ack", "filler", "system:see_you",
                 "system:lost_you", "system:paused", "system:session_start",
                 "system:session_end", "system:limited_view"]:
        phrases[slot] = p[slot]
    return {
        "id": pid,
        "name": p["name"],
        "tagline": p["tagline"],
        "style": p["style"],
        "preview": p["preview"],
        "pitch": p["pitch"],
        "rate": p["rate"],
        "phrases": phrases,
    }


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for pid, p in PERSONALITIES.items():
        bank = build_bank(pid, p)
        for slot, variants in bank["phrases"].items():
            for v in variants:
                assert len(v.split()) <= 8, f"{pid}/{slot}: '{v}' too long"
                assert not any(ch.isdigit() for ch in v), f"{pid}/{slot}: digit in '{v}'"
            if slot.startswith("cue:"):
                assert len(variants) >= 10, f"{pid}/{slot}: only {len(variants)}"
        path = os.path.join(OUT_DIR, f"{pid}.json")
        with open(path, "w") as f:
            json.dump(bank, f, indent=1)
        print(f"wrote {path} ({len(bank['phrases'])} slots)")


if __name__ == "__main__":
    main()
