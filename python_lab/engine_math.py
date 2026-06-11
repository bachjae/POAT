"""Reference implementation of the RallyCoach technique engine.

This is the frozen math that gets ported 1:1 to Dart (lib/core/engine/).
Pure Python (no numpy) so every operation has an exact Dart equivalent;
the shared test vectors assert parity within ±0.5.

Keypoint indices follow MoveNet SinglePose (17 points):
 0 nose 1 l_eye 2 r_eye 3 l_ear 4 r_ear 5 l_shoulder 6 r_shoulder
 7 l_elbow 8 r_elbow 9 l_wrist 10 r_wrist 11 l_hip 12 r_hip
 13 l_knee 14 r_knee 15 l_ankle 16 r_ankle

A frame is {"t": ms, "kp": [[x, y, conf] * 17]} with image-space coords
(x right, y DOWN — as MoveNet emits). Normalization flips y up.
"""
import math

NOSE, L_SHOULDER, R_SHOULDER = 0, 5, 6
L_ELBOW, R_ELBOW, L_WRIST, R_WRIST = 7, 8, 9, 10
L_HIP, R_HIP, L_KNEE, R_KNEE, L_ANKLE, R_ANKLE = 11, 12, 13, 14, 15, 16

MIN_CONF = 0.3

VIEW_SIDE_LEFT = "side_left"
VIEW_SIDE_RIGHT = "side_right"
VIEW_FRONT = "front"
VIEW_BACK = "back"
VIEW_DIAG_LEFT = "diagonal_left"
VIEW_DIAG_RIGHT = "diagonal_right"


def _mid(a, b):
    return [(a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0]


def _dist(a, b):
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2)


def _angle_deg(a, b, c):
    """Interior angle at b (degrees, 0..180)."""
    v1 = [a[0] - b[0], a[1] - b[1]]
    v2 = [c[0] - b[0], c[1] - b[1]]
    n1 = math.sqrt(v1[0] ** 2 + v1[1] ** 2)
    n2 = math.sqrt(v2[0] ** 2 + v2[1] ** 2)
    if n1 < 1e-9 or n2 < 1e-9:
        return 0.0
    cosv = (v1[0] * v2[0] + v1[1] * v2[1]) / (n1 * n2)
    cosv = max(-1.0, min(1.0, cosv))
    return math.degrees(math.acos(cosv))


# ---------------------------------------------------------------- Normalizer

def normalize_frame(kp):
    """SPEC §5: translate hip-mid to origin, scale by torso length, flip y up.

    Returns {"kp": [[x,y]*17], "torso": float, "view": str,
             "shoulder_width_ratio": float} or None if core joints missing.
    """
    for idx in (L_SHOULDER, R_SHOULDER, L_HIP, R_HIP):
        if kp[idx][2] < MIN_CONF:
            return None
    hip_mid = _mid(kp[L_HIP], kp[R_HIP])
    sho_mid = _mid(kp[L_SHOULDER], kp[R_SHOULDER])
    torso = _dist(hip_mid, sho_mid)
    if torso < 1e-6:
        return None
    out = []
    for p in kp:
        out.append([(p[0] - hip_mid[0]) / torso, -(p[1] - hip_mid[1]) / torso])
    view, ratio = classify_view(kp, torso)
    return {"kp": out, "torso": torso, "view": view, "shoulder_width_ratio": ratio}


def classify_view(kp, torso):
    """View bucket from shoulder-width foreshortening + nose visibility.

    ratio = shoulder width / torso length. Facing camera squarely the
    shoulder line is unforeshortened (ratio ≳ 0.75); fully side-on it
    collapses (ratio ≲ 0.45).
    """
    width = _dist(kp[L_SHOULDER], kp[R_SHOULDER])
    ratio = width / torso
    nose_visible = kp[NOSE][2] >= MIN_CONF
    # In image space (x right): for a side-on player facing left, the nose
    # sits left of the shoulder midpoint.
    sho_mid_x = (kp[L_SHOULDER][0] + kp[R_SHOULDER][0]) / 2.0
    nose_left = kp[NOSE][0] < sho_mid_x
    if ratio >= 0.75:
        return (VIEW_FRONT if nose_visible else VIEW_BACK), ratio
    if ratio <= 0.45:
        return (VIEW_SIDE_LEFT if nose_left else VIEW_SIDE_RIGHT), ratio
    return (VIEW_DIAG_LEFT if nose_left else VIEW_DIAG_RIGHT), ratio


def mirror_normalized(nkp):
    """Mirror a normalized frame for left-handed players: negate x and swap L/R."""
    swap = {0: 0, 1: 2, 2: 1, 3: 4, 4: 3, 5: 6, 6: 5, 7: 8, 8: 7,
            9: 10, 10: 9, 11: 12, 12: 11, 13: 14, 14: 13, 15: 16, 16: 15}
    out = [None] * 17
    for i in range(17):
        src = nkp[swap[i]]
        out[i] = [-src[0], src[1]]
    return out


def joint_angles(nkp):
    """Relative joint angles (view-robust per SPEC §5) from a normalized frame.

    Dominant side is RIGHT after handedness mirroring.
    """
    sho_mid = _mid(nkp[L_SHOULDER], nkp[R_SHOULDER])
    hip_mid = [0.0, 0.0]
    trunk_dx = sho_mid[0] - hip_mid[0]
    trunk_dy = sho_mid[1] - hip_mid[1]
    trunk_tilt = abs(math.degrees(math.atan2(trunk_dx, trunk_dy)))
    sho_vec = [nkp[R_SHOULDER][0] - nkp[L_SHOULDER][0],
               nkp[R_SHOULDER][1] - nkp[L_SHOULDER][1]]
    shoulder_line_deg = math.degrees(math.atan2(sho_vec[1], sho_vec[0]))
    hip_vec = [nkp[R_HIP][0] - nkp[L_HIP][0], nkp[R_HIP][1] - nkp[L_HIP][1]]
    hip_line_deg = math.degrees(math.atan2(hip_vec[1], hip_vec[0]))
    return {
        "elbow_angle": _angle_deg(nkp[R_SHOULDER], nkp[R_ELBOW], nkp[R_WRIST]),
        "knee_flexion": _angle_deg(nkp[R_HIP], nkp[R_KNEE], nkp[R_ANKLE]),
        "trunk_tilt": trunk_tilt,
        "shoulder_line_deg": shoulder_line_deg,
        "hip_line_deg": hip_line_deg,
        "wrist_x": nkp[R_WRIST][0],
        "wrist_y": nkp[R_WRIST][1],
        "wrist_height": nkp[R_WRIST][1],  # torso units above hip-mid
    }


# ------------------------------------------------------------- Shot detector

def wrist_speeds(frames):
    """Dominant (right after mirroring) wrist speed in torso-units/second
    between consecutive normalized frames. speeds[i] is speed at frame i
    (speeds[0] = 0)."""
    speeds = [0.0]
    for i in range(1, len(frames)):
        a, b = frames[i - 1], frames[i]
        dt = (b["t"] - a["t"]) / 1000.0
        if dt <= 0:
            speeds.append(0.0)
            continue
        d = _dist(a["kp"][R_WRIST], b["kp"][R_WRIST])
        speeds.append(d / dt)
    return speeds


def detect_shots(frames, base_threshold=6.0, window=45, min_gap=30):
    """Find swing events: wrist-speed peaks above an adaptive threshold.

    frames: list of {"t": ms, "kp": normalized 17x[x,y]} (already normalized,
    handedness-mirrored). Returns list of
    {"peak": i, "start": s, "end": e, "peak_speed": v}.
    """
    speeds = wrist_speeds(frames)
    n = len(speeds)
    if n < 10:
        return []
    mean = sum(speeds) / n
    var = sum((s - mean) ** 2 for s in speeds) / n
    std = math.sqrt(var)
    threshold = max(base_threshold, mean + 2.5 * std)
    shots = []
    i = 1
    while i < n - 1:
        if speeds[i] >= threshold and speeds[i] >= speeds[i - 1] and speeds[i] >= speeds[i + 1]:
            if shots and i - shots[-1]["peak"] < min_gap:
                if speeds[i] > shots[-1]["peak_speed"]:
                    shots[-1] = {"peak": i, "start": max(0, i - window),
                                 "end": min(n - 1, i + window), "peak_speed": speeds[i]}
                i += 1
                continue
            shots.append({"peak": i, "start": max(0, i - window),
                          "end": min(n - 1, i + window), "peak_speed": speeds[i]})
        i += 1
    return shots


def classify_shot(frames, shot):
    """SPEC §6 decision rules. frames normalized + mirrored (dominant = right).

    Serve: both wrists above shoulders in the pre-peak window AND overhead
           wrist peak (wrist above nose level at peak).
    Volley: short swing arc (low backswing amplitude).
    Forehand vs backhand: wrist x relative to body at backswing — forehand
    loads on the dominant (+x) side, backhand crosses to the off side.
    """
    s, p, e = shot["start"], shot["peak"], shot["end"]
    peak_kp = frames[p]["kp"]
    both_up = False
    for i in range(s, p + 1):
        kp = frames[i]["kp"]
        if (kp[L_WRIST][1] > kp[L_SHOULDER][1] and kp[R_WRIST][1] > kp[R_SHOULDER][1]):
            both_up = True
            break
    overhead = peak_kp[R_WRIST][1] > peak_kp[NOSE][1]
    if both_up and overhead:
        return "serve"

    min_x = min(frames[i]["kp"][R_WRIST][0] for i in range(s, p + 1))
    max_x = max(frames[i]["kp"][R_WRIST][0] for i in range(s, p + 1))
    amplitude = max_x - min_x
    if amplitude < 0.9:
        return "volley"

    backswing_i = backswing_frame(frames, s, p)
    bw_x = frames[backswing_i]["kp"][R_WRIST][0]
    return "forehand" if bw_x >= 0.0 else "backhand"


# ----------------------------------------------------------- Phase segmenter

def backswing_frame(frames, start, peak):
    """Wrist rearmost point: frame in [start, peak] with min projection of the
    wrist onto the swing direction at peak."""
    if peak - start < 2:
        return start
    a = frames[max(start, peak - 3)]["kp"][R_WRIST]
    b = frames[peak]["kp"][R_WRIST]
    dx, dy = b[0] - a[0], b[1] - a[1]
    norm = math.sqrt(dx * dx + dy * dy)
    if norm < 1e-9:
        return start
    dx, dy = dx / norm, dy / norm
    best_i, best_v = start, float("inf")
    for i in range(start, peak + 1):
        w = frames[i]["kp"][R_WRIST]
        v = w[0] * dx + w[1] * dy
        if v < best_v:
            best_v, best_i = v, i
    return best_i


def _smoothed_shoulder_deg(frames, i, half=2):
    """Mean shoulder-line angle over a centered window — damps keypoint
    jitter so prep-onset detection doesn't fire on noise."""
    lo = max(0, i - half)
    hi = min(len(frames) - 1, i + half)
    total = 0.0
    base = None
    count = 0
    for j in range(lo, hi + 1):
        a = joint_angles(frames[j]["kp"])["shoulder_line_deg"]
        if base is None:
            base = a
        diff = a - base
        while diff > 180.0:
            diff -= 360.0
        while diff < -180.0:
            diff += 360.0
        total += base + diff
        count += 1
    return total / count


def trunk_rotation_speed(frames, i):
    """Smoothed shoulder-line angular speed (deg/s) at frame i."""
    if i == 0:
        return 0.0
    a = _smoothed_shoulder_deg(frames, i - 1)
    b = _smoothed_shoulder_deg(frames, i)
    diff = b - a
    while diff > 180.0:
        diff -= 360.0
    while diff < -180.0:
        diff += 360.0
    dt = (frames[i]["t"] - frames[i - 1]["t"]) / 1000.0
    if dt <= 0:
        return 0.0
    return abs(diff) / dt


def serve_backswing_frame(frames, start, peak):
    """Serve: racket-drop = lowest wrist point AFTER the trophy and before
    contact. Trophy = first frame the dominant wrist rises above shoulder
    height. (The generic rearmost-projection rule picks the address stance for
    serves, so this overrides it.)"""
    if peak - start < 2:
        return start
    trophy_i = start
    for i in range(start, peak + 1):
        kp = frames[i]["kp"]
        sho_mid_y = (kp[L_SHOULDER][1] + kp[R_SHOULDER][1]) / 2.0
        if kp[R_WRIST][1] >= sho_mid_y:
            trophy_i = i
            break
    best_i, best_y = trophy_i, float("inf")
    for i in range(trophy_i, peak + 1):
        y = frames[i]["kp"][R_WRIST][1]
        if y < best_y:
            best_y, best_i = y, i
    return best_i


def segment_phases(frames, shot, stroke="forehand", trunk_speed_threshold=90.0):
    """Boundary events per SPEC §7. Returns frame indices."""
    s, p, e = shot["start"], shot["peak"], shot["end"]
    if stroke == "serve":
        bw = serve_backswing_frame(frames, s, p)
    else:
        bw = backswing_frame(frames, s, p)
    # Prep onset: two consecutive frames of sustained trunk rotation, so a
    # single noisy frame can't trigger it.
    prep = bw
    for i in range(s, bw):
        if (trunk_rotation_speed(frames, i) > trunk_speed_threshold
                and trunk_rotation_speed(frames, i + 1) > trunk_speed_threshold):
            prep = i
            break
    speeds = wrist_speeds(frames)
    peak_speed = speeds[p]
    follow_end = e
    for i in range(p + 1, e + 1):
        if speeds[i] < 0.2 * peak_speed:
            follow_end = i
            break
    return {"prep": prep, "backswing": bw, "contact": p, "follow_end": follow_end}


# ----------------------------------------------------------------- Scoring

def measure_metrics(frames, phases, address_angles):
    """Measured values per phase used by the scorer. address_angles = joint
    angles at shot address (window start) for turn deltas.

    Preparation-phase quality is the LOADED position, so its metrics are
    measured at the backswing frame; the prep onset index feeds timing only.
    """
    def ang(i):
        return joint_angles(frames[i]["kp"])

    bw_a = ang(phases["backswing"])
    prep_a = bw_a
    ct_a = ang(phases["contact"])
    ft_a = ang(phases["follow_end"])

    def turn(a):
        diff = a["shoulder_line_deg"] - address_angles["shoulder_line_deg"]
        while diff > 180.0:
            diff -= 360.0
        while diff < -180.0:
            diff += 360.0
        return abs(diff)

    def hip_turn(a):
        diff = a["hip_line_deg"] - address_angles["hip_line_deg"]
        while diff > 180.0:
            diff -= 360.0
        while diff < -180.0:
            diff += 360.0
        return abs(diff)

    prep_ms = frames[phases["contact"]]["t"] - frames[phases["prep"]]["t"]
    return {
        "preparation": {
            "shoulder_turn": turn(prep_a),
            "knee_flexion": prep_a["knee_flexion"],
            "trunk_tilt": prep_a["trunk_tilt"],
        },
        "backswing": {
            "elbow_angle": bw_a["elbow_angle"],
            "hip_shoulder_sep": abs(turn(bw_a) - hip_turn(bw_a)),
            "shoulder_turn": turn(bw_a),
        },
        "contact": {
            "elbow_angle": ct_a["elbow_angle"],
            "contact_in_front": ct_a["wrist_x"],
            "knee_flexion": ct_a["knee_flexion"],
            "contact_height": ct_a["wrist_height"],
        },
        "follow_through": {
            "wrist_finish_height": ft_a["wrist_height"],
            "trunk_tilt": ft_a["trunk_tilt"],
        },
        "timing": {"prep_before_contact_ms": float(prep_ms)},
    }


def score_metric(value, ideal, tolerance=None):
    """100 inside [lo,hi]; linear falloff to 0 at `tolerance` beyond the edge
    (default tolerance = range width)."""
    lo, hi = ideal
    if tolerance is None:
        tolerance = hi - lo
    if tolerance <= 0:
        tolerance = 1.0
    if lo <= value <= hi:
        return 100.0
    dev = (lo - value) if value < lo else (value - hi)
    return max(0.0, 100.0 - (dev / tolerance) * 100.0)


def score_shot(measured, reference, view):
    """Weighted phase scores → 0-100 shot score + deviation list for cues.

    reference: the skill-tier node {"phases": {...}, "timing": {...}}.
    Metrics whose `views` don't include the current view are skipped (SPEC §5).
    Returns {"score": float, "phase_scores": {...}, "deviations": [...]}.
    """
    phase_scores = {}
    deviations = []
    total_w, total_ws = 0.0, 0.0
    for phase, spec in reference["phases"].items():
        p_w, p_ws = 0.0, 0.0
        for metric in spec["metrics"]:
            views = metric["views"]
            if not _view_allowed(view, views):
                continue
            mid = metric["id"]
            if phase not in measured or mid not in measured[phase]:
                continue
            value = measured[phase][mid]
            sc = score_metric(value, metric["ideal"], metric.get("tolerance"))
            w = metric["weight"]
            p_w += w
            p_ws += w * sc
            if sc < 100.0:
                lo, hi = metric["ideal"]
                direction = "low" if value < lo else "high"
                deviations.append({
                    "phase": phase, "id": mid, "value": round(value, 2),
                    "ideal": metric["ideal"], "direction": direction,
                    "severity": round((100.0 - sc) / 100.0, 4),
                    "weight": w,
                    "cue": metric["cue_low"] if direction == "low" else metric["cue_high"],
                })
        if p_w > 0:
            phase_scores[phase] = p_ws / p_w
            total_w += p_w
            total_ws += p_ws
    timing_ref = reference.get("timing", {})
    if "prep_before_contact_ms" in timing_ref and "timing" in measured:
        v = measured["timing"]["prep_before_contact_ms"]
        sc = score_metric(v, timing_ref["prep_before_contact_ms"])
        phase_scores["timing"] = sc
        total_w += 0.5
        total_ws += 0.5 * sc
        if sc < 100.0:
            lo, hi = timing_ref["prep_before_contact_ms"]
            deviations.append({
                "phase": "timing", "id": "prep_before_contact_ms",
                "value": round(v, 2), "ideal": [lo, hi],
                "direction": "low" if v < lo else "high",
                "severity": round((100.0 - sc) / 100.0, 4), "weight": 0.5,
                "cue": "start the preparation earlier" if v < lo
                       else "don't rush — let the swing breathe",
            })
    score = (total_ws / total_w) if total_w > 0 else 0.0
    deviations.sort(key=lambda d: -(d["severity"] * d["weight"]))
    return {"score": score, "phase_scores": phase_scores, "deviations": deviations}


def _view_allowed(view, views):
    for v in views:
        if v == view:
            return True
        if v == "diagonal_*" and view.startswith("diagonal"):
            return True
        if v == "side_*" and view.startswith("side"):
            return True
    return False


# ----------------------------------------------------------------- Footwork

def analyze_footwork_window(frames, raw_hip_x, torso):
    """Continuous metrics for one 10s window (SPEC §7).

    frames: normalized frames in the window. raw_hip_x: image-space hip-mid x
    per frame; torso: image-space torso length (for converting lateral motion
    to torso units — normalization removes global translation).
    Returns {"split_step_rate": hops/s, "stance_width": torso units,
             "recovery_steps": direction changes}.
    """
    n = len(frames)
    if n < 5:
        return {"split_step_rate": 0.0, "stance_width": 0.0, "recovery_steps": 0.0}
    width_sum = 0.0
    ankle_y = []
    for f in frames:
        kp = f["kp"]
        width_sum += abs(kp[L_ANKLE][0] - kp[R_ANKLE][0])
        ankle_y.append((kp[L_ANKLE][1] + kp[R_ANKLE][1]) / 2.0)
    stance_width = width_sum / n

    base = sum(ankle_y) / n
    hops = 0
    in_hop = False
    for y in ankle_y:
        if y > base + 0.06:
            if not in_hop:
                hops += 1
                in_hop = True
        else:
            in_hop = False
    dur_s = (frames[-1]["t"] - frames[0]["t"]) / 1000.0
    split_step_rate = hops / dur_s if dur_s > 0 else 0.0

    steps = 0
    prev_dir = 0
    for i in range(1, n):
        dx = (raw_hip_x[i] - raw_hip_x[i - 1]) / torso
        if abs(dx) < 0.01:
            continue
        d = 1 if dx > 0 else -1
        if prev_dir != 0 and d != prev_dir:
            steps += 1
        prev_dir = d
    return {"split_step_rate": split_step_rate,
            "stance_width": stance_width,
            "recovery_steps": float(steps)}


# ----------------------------------------------------------- Cue prioritizer

def pick_cue(deviations, recent_metric_ids, recurrence_counts):
    """Highest weight × severity × recurrence, suppressing recently spoken
    metric ids (SPEC §8). recurrence_counts: metric_id -> occurrences in the
    last 10 shots. Returns the chosen deviation dict or None."""
    best, best_v = None, -1.0
    for d in deviations:
        if d["id"] in recent_metric_ids:
            continue
        rec = 1.0 + 0.15 * float(recurrence_counts.get(d["id"], 0))
        v = d["weight"] * d["severity"] * rec
        if v > best_v:
            best_v, best = v, d
    return best
