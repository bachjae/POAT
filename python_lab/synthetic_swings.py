"""Synthetic keypoint-sequence generator.

No labeled video footage is available in this build environment, so classifier
and segmenter validation runs on parameterized kinematic swings instead:
17-keypoint MoveNet-style sequences (image space, y down) built from keyframed
wrist paths, explicit elbow-angle targets, animated trunk rotation and knee
bend. Segments into contact use ease-in interpolation so wrist speed peaks at
the contact keyframe, as in a real accelerating swing.

Conventions (mirrors engine_math): after normalization the dominant side is
+x; forehands load the backswing at +x, backhands at -x, serves go overhead,
volleys are short-amplitude punches. Image: 1280x720, hip-mid ~(640,360),
torso length 100 px, 30 fps.
"""
import math
import random

FPS = 30
TORSO = 100.0
CX, CY = 640.0, 360.0

VIEW_WIDTHS = {"side": 0.16, "diagonal": 0.28, "front": 0.40}


def _ease(f, mode):
    if mode == "in":
        return f * f
    if mode == "out":
        return 1.0 - (1.0 - f) * (1.0 - f)
    return f


def _interp(keys, t):
    """keys: [(time, value, ease)] sorted. ease applies to the segment ENDING
    at that key. Values may be scalars or [x, y]."""
    if t <= keys[0][0]:
        return keys[0][1]
    if t >= keys[-1][0]:
        return keys[-1][1]
    for i in range(1, len(keys)):
        if t <= keys[i][0]:
            t0, v0 = keys[i - 1][0], keys[i - 1][1]
            t1, v1, ease = keys[i]
            f = _ease((t - t0) / (t1 - t0), ease)
            if isinstance(v0, (list, tuple)):
                return [v0[0] + (v1[0] - v0[0]) * f, v0[1] + (v1[1] - v0[1]) * f]
            return v0 + (v1 - v0) * f
    return keys[-1][1]


def _elbow_for_angle(shoulder, wrist, target_deg, sign=1.0):
    """Place the elbow so the interior angle S-E-W equals target_deg."""
    dx, dy = wrist[0] - shoulder[0], wrist[1] - shoulder[1]
    d = math.sqrt(dx * dx + dy * dy)
    mid = [shoulder[0] + dx / 2.0, shoulder[1] + dy / 2.0]
    if target_deg >= 178.0 or d < 1e-6:
        return mid
    theta = math.radians(target_deg)
    bone = d / math.sqrt(2.0 - 2.0 * math.cos(theta))
    h = math.sqrt(max(0.0, bone * bone - (d / 2.0) * (d / 2.0)))
    ux, uy = dx / d, dy / d
    return [mid[0] + sign * (-uy) * h, mid[1] + sign * ux * h]


def _rot(p, deg):
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    return [p[0] * c - p[1] * s, p[0] * s + p[1] * c]


def build_frames(spec, view="side", seed=0, noise=0.0, fps=FPS,
                 lead_s=1.2, tail_s=0.8, hide_nose=False):
    rng = random.Random(seed)
    hw = VIEW_WIDTHS[view]
    frames = []
    total = lead_s + spec["duration"] + tail_s
    n = int(total * fps)
    for i in range(n):
        t_abs = i / fps
        t = min(max((t_abs - lead_s) / spec["duration"], 0.0), 1.0)
        wrist = _interp(spec["wrist"], t)
        off_wrist = _interp(spec["off_wrist"], t)
        turn = _interp(spec["turn"], t)
        knee_off = _interp(spec["knee"], t)
        elbow_deg = _interp(spec["elbow"], t)

        # Full in-plane rotation: the measured shoulder_turn (atan2 delta of
        # the projected line) then equals the keyframed turn exactly.
        l_sho_b = _rot([-hw, 0.0], turn)
        r_sho_b = _rot([hw, 0.0], turn)
        l_sho = [l_sho_b[0], 1.0 + l_sho_b[1]]
        r_sho = [r_sho_b[0], 1.0 + r_sho_b[1]]
        sho_mid = [(l_sho[0] + r_sho[0]) / 2.0, (l_sho[1] + r_sho[1]) / 2.0]

        hip_hw = hw * 0.8
        l_hip_b = _rot([-hip_hw, 0.0], turn * 0.6)
        r_hip_b = _rot([hip_hw, 0.0], turn * 0.6)
        l_hip = [l_hip_b[0], l_hip_b[1]]
        r_hip = [r_hip_b[0], r_hip_b[1]]

        nose = [sho_mid[0] - 0.22, 1.35]
        l_eye = [nose[0] - 0.04, 1.40]
        r_eye = [nose[0] + 0.04, 1.40]
        l_ear = [nose[0] - 0.09, 1.37]
        r_ear = [nose[0] + 0.09, 1.37]

        r_elbow = _elbow_for_angle(r_sho, wrist, elbow_deg, 1.0)
        l_elbow = _elbow_for_angle(l_sho, off_wrist, 140.0, -1.0)

        l_knee = [l_hip[0] + knee_off, -0.55]
        r_knee = [r_hip[0] + knee_off, -0.55]
        l_ankle = [l_hip[0], -1.05]
        r_ankle = [r_hip[0], -1.05]

        body = [nose, l_eye, r_eye, l_ear, r_ear, l_sho, r_sho, l_elbow,
                r_elbow, off_wrist, wrist, l_hip, r_hip, l_knee, r_knee,
                l_ankle, r_ankle]
        kp = []
        for j, p in enumerate(body):
            nx = p[0] + (rng.random() - 0.5) * 2.0 * noise
            ny = p[1] + (rng.random() - 0.5) * 2.0 * noise
            conf = 0.1 if (hide_nose and j <= 4) else 0.9
            kp.append([round(CX + nx * TORSO, 2), round(CY - ny * TORSO, 2), conf])
        frames.append({"t": int(round(t_abs * 1000.0)), "kp": kp})
    return frames


def _lerp(a, b, t):
    return a + (b - a) * t


def forehand_spec(quality=1.0):
    """quality 1.0 = clean intermediate form; lower degrades contact point,
    elbow extension, shoulder turn and preparation timing (drives the
    deviation/cue fixtures)."""
    contact_x = _lerp(-0.35, 0.55, quality)
    contact_elbow = _lerp(75.0, 138.0, quality)
    turn_peak = _lerp(20.0, 85.0, quality)
    delay = (1.0 - quality) * 0.45
    return {
        "duration": 1.5,
        "wrist": [
            (0.00, [0.35, 0.45], "lin"),
            (0.32, [0.95, 0.55], "lin"),
            (0.55, [1.45, 0.30], "lin"),          # loaded backswing (+x)
            (0.62, [contact_x, 0.05], "in"),       # accelerate into contact
            (0.80, [-0.55, 1.40], "out"),          # over-shoulder finish
            (1.00, [-0.45, 1.30], "lin"),
        ],
        "off_wrist": [(0.0, [-0.35, 0.50], "lin"), (0.5, [-0.55, 0.60], "lin"),
                      (1.0, [-0.30, 0.80], "lin")],
        "turn": [(0.0, 0.0, "lin"), (delay, 0.0, "lin"),
                 (0.40 + delay * 0.4, turn_peak, "lin"),
                 (0.58, turn_peak, "lin"), (0.68, 15.0, "lin"), (1.0, -25.0, "lin")],
        "knee": [(0.0, 0.02, "lin"), (0.42, 0.20, "lin"), (0.58, 0.17, "lin"),
                 (0.66, 0.11, "lin"), (1.0, 0.03, "lin")],
        "elbow": [(0.0, 150.0, "lin"), (0.40, 120.0, "lin"), (0.55, 115.0, "lin"),
                  (0.62, contact_elbow, "lin"), (0.82, 100.0, "lin"), (1.0, 110.0, "lin")],
    }


def backhand_spec(quality=1.0):
    contact_x = _lerp(-0.35, 0.45, quality)
    contact_elbow = _lerp(100.0, 162.0, quality)
    turn_peak = _lerp(30.0, 95.0, quality)
    delay = (1.0 - quality) * 0.45
    return {
        "duration": 1.5,
        "wrist": [
            (0.00, [0.30, 0.45], "lin"),
            (0.32, [-0.70, 0.50], "lin"),
            (0.48, [-1.25, 0.35], "lin"),          # rearmost on off side (-x)
            (0.62, [contact_x, 0.30], "in"),
            (0.82, [0.95, 1.35], "out"),
            (1.00, [0.85, 1.25], "lin"),
        ],
        "off_wrist": [(0.0, [-0.30, 0.50], "lin"), (0.48, [-1.05, 0.45], "lin"),
                      (0.7, [-0.60, 0.70], "lin"), (1.0, [-0.50, 0.80], "lin")],
        "turn": [(0.0, 0.0, "lin"), (delay, 0.0, "lin"),
                 (0.40 + delay * 0.3, -turn_peak, "lin"),
                 (0.55, -turn_peak, "lin"), (0.68, -10.0, "lin"), (1.0, 20.0, "lin")],
        "knee": [(0.0, 0.02, "lin"), (0.40, 0.18, "lin"), (0.55, 0.16, "lin"),
                 (0.66, 0.10, "lin"), (1.0, 0.03, "lin")],
        "elbow": [(0.0, 150.0, "lin"), (0.48, 150.0, "lin"),
                  (0.62, contact_elbow, "lin"), (1.0, 120.0, "lin")],
    }


def serve_spec(quality=1.0):
    contact_y = _lerp(1.30, 2.25, quality)
    contact_elbow = _lerp(110.0, 172.0, quality)
    knee_peak = _lerp(0.02, 0.26, quality)
    turn_peak = _lerp(40.0, 70.0, quality)
    delay = (1.0 - quality) * 0.35
    return {
        "duration": 1.8,
        "wrist": [
            (0.00, [0.30, 0.50], "lin"),
            (0.30, [0.45, 1.25], "lin"),           # trophy — both wrists up
            (0.54, [0.35, 0.90], "lin"),           # racket drop (backswing)
            (0.62, [0.15, contact_y], "in"),       # overhead contact
            (0.85, [-0.40, 0.60], "out"),
            (1.00, [-0.30, 0.45], "lin"),
        ],
        "off_wrist": [(0.0, [-0.25, 0.50], "lin"), (0.30, [-0.20, 1.45], "lin"),
                      (0.55, [-0.30, 1.10], "lin"), (0.75, [-0.35, 0.60], "lin"),
                      (1.0, [-0.30, 0.55], "lin")],
        "turn": [(0.0, 0.0, "lin"), (delay, 0.0, "lin"),
                 (0.30 + delay * 0.4, turn_peak, "lin"), (0.55, turn_peak, "lin"),
                 (0.66, 10.0, "lin"), (1.0, -15.0, "lin")],
        "knee": [(0.0, 0.02, "lin"), (0.42, knee_peak, "lin"), (0.54, knee_peak * 0.8, "lin"),
                 (0.62, 0.04, "lin"), (1.0, 0.02, "lin")],
        "elbow": [(0.0, 150.0, "lin"), (0.30, 95.0, "lin"), (0.54, 90.0, "lin"),
                  (0.62, contact_elbow, "lin"), (1.0, 120.0, "lin")],
    }


def volley_spec(quality=1.0):
    contact_x = _lerp(-0.25, 0.55, quality)
    contact_elbow = _lerp(70.0, 140.0, quality)
    turn_peak = _lerp(-15.0, 35.0, quality)
    knee_peak = _lerp(0.02, 0.16, quality)
    return {
        "duration": 0.9,
        "wrist": [
            (0.00, [contact_x - 0.70, 0.75], "lin"),
            (0.45, [contact_x - 0.75, 0.80], "lin"),   # compact set
            (0.56, [contact_x, 0.95], "in"),           # punch contact
            (0.75, [contact_x - 0.15, 0.75], "out"),
            (1.00, [contact_x - 0.20, 0.70], "lin"),
        ],
        "off_wrist": [(0.0, [-0.30, 0.70], "lin"), (1.0, [-0.35, 0.75], "lin")],
        "turn": [(0.0, 0.0, "lin"), (0.38, turn_peak, "lin"), (0.56, turn_peak, "lin"),
                 (0.72, 10.0, "lin"), (1.0, 0.0, "lin")],
        "knee": [(0.0, 0.10, "lin"), (0.5, knee_peak, "lin"), (1.0, 0.10, "lin")],
        "elbow": [(0.0, 150.0, "lin"), (0.45, 148.0, "lin"), (0.56, contact_elbow, "lin"),
                  (1.0, 135.0, "lin")],
    }


SPECS = {
    "forehand": forehand_spec,
    "backhand": backhand_spec,
    "serve": serve_spec,
    "volley": volley_spec,
}


def make(stroke, view="side", seed=0, noise=0.0, quality=1.0, hide_nose=False):
    return build_frames(SPECS[stroke](quality), view=view, seed=seed,
                        noise=noise, hide_nose=hide_nose)
