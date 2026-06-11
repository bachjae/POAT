"""Emit shared Python↔Dart test vectors.

The Dart engine port loads test/fixtures/engine_vectors.json, runs the same
inputs, and asserts identical outputs (±0.5 for angles/scores, exact for
indices and labels). Regenerate with: python3 make_test_vectors.py
"""
import json
import math
import os

import engine_math as em
import synthetic_swings as sw
from validate_engine import load_ref, run_pipeline

OUT = os.path.join(os.path.dirname(__file__), "..", "test", "fixtures",
                   "engine_vectors.json")

PIPELINE_CASES = [
    ("forehand", "side", 1.0, 11, 0.0),
    ("forehand", "diagonal", 0.5, 12, 0.01),
    ("backhand", "side", 1.0, 13, 0.0),
    ("backhand", "front", 0.6, 14, 0.015),
    ("serve", "side", 1.0, 15, 0.0),
    ("serve", "diagonal", 0.5, 16, 0.01),
    ("volley", "side", 1.0, 17, 0.0),
    ("volley", "front", 0.5, 18, 0.01),
]


def r2(frames):
    return [{"t": f["t"], "kp": [[round(v, 2) for v in p] for p in f["kp"]]}
            for f in frames]


def pipeline_vector(stroke, view, quality, seed, noise):
    frames = sw.make(stroke, view=view, seed=seed, noise=noise, quality=quality)
    results, det_view = run_pipeline(frames)
    assert len(results) == 1, f"{stroke}/{view}: {len(results)} shots"
    r = results[0]
    ref = load_ref(stroke)
    scored = em.score_shot(r["measured"], ref, r["view"])
    return {
        "name": f"{stroke}_{view}_q{quality}_s{seed}",
        "stroke_expected": stroke,
        "tier": "intermediate",
        "input_frames": r2(frames),
        "expected": {
            "view": r["view"],
            "shot": {k: r["shot"][k] for k in ("start", "peak", "end")},
            "peak_speed": round(r["shot"]["peak_speed"], 3),
            "stroke": r["stroke"],
            "phases": r["phases"],
            "measured": {ph: {k: round(v, 3) for k, v in mm.items()}
                         for ph, mm in r["measured"].items()},
            "score": round(scored["score"], 3),
            "phase_scores": {k: round(v, 3) for k, v in scored["phase_scores"].items()},
            "deviation_ids": [d["id"] for d in scored["deviations"]],
            "top_deviation": scored["deviations"][0]["id"] if scored["deviations"] else None,
        },
    }


def unit_vectors():
    """Direct vectors for normalizer / joint angles / scoring primitives."""
    frames = sw.make("forehand", view="side", seed=21, noise=0.01)
    samples = []
    for i in (0, 30, 50, 64, 80):
        f = frames[i]
        n = em.normalize_frame(f["kp"])
        samples.append({
            "kp": [[round(v, 2) for v in p] for p in f["kp"]],
            "expected": {
                "view": n["view"],
                "torso": round(n["torso"], 4),
                "shoulder_width_ratio": round(n["shoulder_width_ratio"], 4),
                "angles": {k: round(v, 3)
                           for k, v in em.joint_angles(n["kp"]).items()},
            },
        })
    score_cases = [
        {"value": 130.0, "ideal": [120, 150], "tolerance": None, "expected": 100.0},
        {"value": 110.0, "ideal": [120, 150], "tolerance": None, "expected": round(em.score_metric(110, [120, 150]), 4)},
        {"value": 170.0, "ideal": [120, 150], "tolerance": 10, "expected": 0.0},
        {"value": 119.0, "ideal": [120, 150], "tolerance": 30, "expected": round(em.score_metric(119, [120, 150], 30), 4)},
    ]
    mirror_in = [[round(v, 2) for v in p] for p in
                 em.normalize_frame(frames[40]["kp"])["kp"]]
    cue_case = {
        "deviations": [
            {"id": "elbow_angle", "severity": 0.4, "weight": 0.3},
            {"id": "shoulder_turn", "severity": 0.6, "weight": 0.3},
            {"id": "knee_flexion", "severity": 0.9, "weight": 0.15},
        ],
        "recent": ["shoulder_turn"],
        "recurrence": {"elbow_angle": 6, "knee_flexion": 0},
        "expected": em.pick_cue(
            [{"id": "elbow_angle", "severity": 0.4, "weight": 0.3},
             {"id": "shoulder_turn", "severity": 0.6, "weight": 0.3},
             {"id": "knee_flexion", "severity": 0.9, "weight": 0.15}],
            {"shoulder_turn"}, {"elbow_angle": 6, "knee_flexion": 0})["id"],
    }
    return {"normalize_samples": samples, "score_metric_cases": score_cases,
            "mirror_input": mirror_in,
            "mirror_expected": [[round(v, 4) for v in p]
                                for p in em.mirror_normalized(
                                    [[p[0], p[1]] for p in mirror_in])],
            "cue_case": cue_case}


def footwork_frames():
    """10s lateral shuffle drill: hop every 2s, ankles spread, hips traverse."""
    frames, raw_hip_x = [], []
    fps, torso = 30, 100.0
    for i in range(300):
        t = i / fps
        hip_img_x = 640.0 + 180.0 * math.sin(2.0 * math.pi * t / 5.0)
        hop = 0.22 if (t % 2.0) < 0.2 else 0.0
        kp = [[0.0, 0.0, 0.9] for _ in range(17)]

        def put(idx, bx, by):
            kp[idx] = [round(hip_img_x + bx * torso, 2),
                       round(360.0 - by * torso, 2), 0.9]
        put(0, -0.1, 1.35)
        for j in (1, 2, 3, 4):
            put(j, -0.1, 1.38)
        put(5, -0.35, 1.0)
        put(6, 0.35, 1.0)
        put(7, -0.45, 0.6)
        put(8, 0.45, 0.6)
        put(9, -0.4, 0.4)
        put(10, 0.4, 0.4)
        put(11, -0.15, 0.0)
        put(12, 0.15, 0.0)
        put(13, -0.45, -0.5)
        put(14, 0.45, -0.5)
        put(15, -0.62, -1.05 + hop)
        put(16, 0.62, -1.05 + hop)
        frames.append({"t": int(round(t * 1000.0)), "kp": kp})
        raw_hip_x.append(hip_img_x)
    return frames, raw_hip_x


def footwork_vector():
    frames, raw_hip_x = footwork_frames()
    norm = []
    for f in frames:
        n = em.normalize_frame(f["kp"])
        norm.append({"t": f["t"], "kp": n["kp"]})
    torso = em.normalize_frame(frames[0]["kp"])["torso"]
    out = em.analyze_footwork_window(norm, raw_hip_x, torso)
    return {
        "input_frames": r2(frames),
        "raw_hip_x": [round(x, 2) for x in raw_hip_x],
        "torso": round(torso, 4),
        "expected": {k: round(v, 4) for k, v in out.items()},
    }


def main():
    vectors = {
        "version": 1,
        "unit": unit_vectors(),
        "pipeline": [pipeline_vector(*c) for c in PIPELINE_CASES],
        "footwork": footwork_vector(),
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(vectors, f)
    size = os.path.getsize(OUT) // 1024
    print(f"wrote {OUT} ({size} KB, {len(vectors['pipeline'])} pipeline cases)")


if __name__ == "__main__":
    main()
