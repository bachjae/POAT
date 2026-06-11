"""End-to-end validation of the engine math on synthetic fixtures.

Checks (SPEC §6 target: ≥92% classification accuracy before porting):
  - every fixture detects exactly one shot, classified correctly
  - clean (quality=1.0) swings score high; degraded swings score lower and
    surface the expected deviation ids
  - view buckets classify as constructed

Run: python3 validate_engine.py
"""
import json
import os

import engine_math as em
import synthetic_swings as sw

REF_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "reference")


def load_ref(stroke, tier="intermediate"):
    with open(os.path.join(REF_DIR, f"{stroke}.json")) as f:
        return json.load(f)["skill_levels"][tier]


def run_pipeline(frames):
    """Image-space frames -> normalized stream -> shots with scores."""
    norm = []
    views = {}
    for f in frames:
        n = em.normalize_frame(f["kp"])
        if n is None:
            continue
        norm.append({"t": f["t"], "kp": n["kp"]})
        views[n["view"]] = views.get(n["view"], 0) + 1
    view = max(views, key=views.get)
    shots = em.detect_shots(norm)
    results = []
    for shot in shots:
        stroke = em.classify_shot(norm, shot)
        phases = em.segment_phases(norm, shot, stroke)
        address = em.joint_angles(norm[shot["start"]]["kp"])
        measured = em.measure_metrics(norm, phases, address)
        results.append({"stroke": stroke, "shot": shot, "phases": phases,
                        "measured": measured, "view": view})
    return results, view


def main():
    total, correct = 0, 0
    failures = []
    for stroke in ["forehand", "backhand", "serve", "volley"]:
        ref = load_ref(stroke)
        for view in ["side", "diagonal", "front"]:
            for quality, seed, noise in [(1.0, 1, 0.0), (1.0, 2, 0.01),
                                         (0.85, 3, 0.01), (0.4, 4, 0.01),
                                         (1.0, 5, 0.02), (0.6, 6, 0.015)]:
                frames = sw.make(stroke, view=view, seed=seed, noise=noise,
                                 quality=quality)
                results, det_view = run_pipeline(frames)
                total += 1
                tag = f"{stroke}/{view}/q{quality}/s{seed}/n{noise}"
                if len(results) != 1:
                    failures.append(f"{tag}: {len(results)} shots detected")
                    continue
                r = results[0]
                if r["stroke"] != stroke:
                    failures.append(f"{tag}: classified {r['stroke']}")
                    continue
                correct += 1
                scored = em.score_shot(r["measured"], ref, r["view"])
                if quality >= 1.0 and scored["score"] < 75:
                    failures.append(
                        f"{tag}: clean swing scored {scored['score']:.0f} "
                        f"devs={[d['id'] for d in scored['deviations'][:3]]}")
                # Front view legitimately sees fewer metrics (positional
                # checks are view-gated), so the poor-swing floor only
                # applies where the full metric set is visible.
                if quality <= 0.4 and view != "front" and scored["score"] > 82:
                    failures.append(f"{tag}: poor swing scored {scored['score']:.0f}")
                if quality <= 0.4 and not scored["deviations"]:
                    failures.append(f"{tag}: poor swing produced no deviations")

    # view bucket sanity
    for view, expect_prefix in [("side", "side"), ("diagonal", "diagonal"),
                                ("front", "front")]:
        frames = sw.make("forehand", view=view, seed=9)
        _, det = run_pipeline(frames)
        if not det.startswith(expect_prefix):
            failures.append(f"view {view}: classified {det}")
    frames = sw.make("forehand", view="front", seed=9, hide_nose=True)
    _, det = run_pipeline(frames)
    if det != "back":
        failures.append(f"view back: classified {det}")

    acc = 100.0 * correct / total if total else 0.0
    print(f"classification: {correct}/{total} = {acc:.1f}%")
    if failures:
        print(f"\n{len(failures)} FAILURES:")
        for f in failures:
            print(" -", f)
        raise SystemExit(1)
    print("all checks passed")


if __name__ == "__main__":
    main()
