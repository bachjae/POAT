#!/usr/bin/env bash
# Fetches the on-device models RallyCoach bundles as assets.
#
#   MoveNet (pose):  public, no auth, small — always fetched, committed to git.
#   Gemma 4 E2B (coach brain): Apache-2.0, ungated on HuggingFace, 2.58 GB —
#     fetched only with --gemma, git-ignored, split into <2 GB APK-safe chunks.
#     Builds WITHOUT the chunks still work: the app runs in Lite mode.
#   Racquet detector (optional, --racquet): a single-instance racquet-keypoint
#     TFLite model (handle/throat/tip). OPTIONAL: without it the app estimates
#     the racquet from the forearm (lib/core/engine/racquet.dart). With it, the
#     racquet metrics use measured keypoints and racquet_confidence becomes an
#     authoritative presence gate. No public ungated model ships today, so this
#     flag installs a model you supply (RACQUET_MODEL=/path or the slot below)
#     and documents the asset slot rather than downloading one.
#
# Usage: tool/fetch_models.sh [--gemma] [--racquet]
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/models

fetch_movenet() {
  local name="$1" url="$2"
  if [[ -f "assets/models/${name}.tflite" ]]; then
    echo "assets/models/${name}.tflite already present"
    return
  fi
  echo "downloading ${name}..."
  local tmp
  tmp="$(mktemp -d)"
  curl -sL "$url" -o "$tmp/model.tar.gz"
  tar xzf "$tmp/model.tar.gz" -C "$tmp"
  local tflite
  tflite="$(find "$tmp" -name '*.tflite' | head -1)"
  mv "$tflite" "assets/models/${name}.tflite"
  rm -rf "$tmp"
  echo "  -> assets/models/${name}.tflite ($(du -h "assets/models/${name}.tflite" | cut -f1))"
}

fetch_movenet movenet_thunder \
  "https://www.kaggle.com/api/v1/models/google/movenet/tfLite/singlepose-thunder-tflite-float16/1/download"
fetch_movenet movenet_lightning \
  "https://www.kaggle.com/api/v1/models/google/movenet/tfLite/singlepose-lightning-tflite-float16/1/download"

want_gemma=false
want_racquet=false
for arg in "$@"; do
  case "$arg" in
    --gemma) want_gemma=true ;;
    --racquet) want_racquet=true ;;
  esac
done

if [[ "$want_racquet" == true ]]; then
  RACQUET_DEST="assets/models/racquet_keypoints.tflite"
  if [[ -f "$RACQUET_DEST" ]]; then
    echo "racquet detector already present at $RACQUET_DEST"
  elif [[ -n "${RACQUET_MODEL:-}" && -f "${RACQUET_MODEL}" ]]; then
    cp "${RACQUET_MODEL}" "$RACQUET_DEST"
    echo "installed racquet detector from \$RACQUET_MODEL -> $RACQUET_DEST"
  else
    cat <<'EOF'
No bundled racquet-keypoint model is downloaded by this script (no public,
ungated single-racquet-keypoint model ships today). To enable the optical
racquet tracker:
  1. Supply a TFLite model that outputs 3 racquet keypoints (handle, throat,
     tip) in image space, then re-run:
         RACQUET_MODEL=/path/to/your_model.tflite tool/fetch_models.sh --racquet
     (it is copied to assets/models/racquet_keypoints.tflite).
  2. Wire it into the pose isolate alongside MoveNet and pass the detected,
     torso-normalized [handle, throat, tip] into racquetPose(..., detected:)
     and a per-frame presence score into racquetConfidence(..., detectedPresence:).
Until then the app estimates the racquet from the forearm — fully functional,
just an estimate. See docs/TENNIS_COACHING_KNOWLEDGE.md (the racquet tracker).
EOF
  fi
fi

if [[ "$want_gemma" == true ]]; then
  GEMMA_URL="https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it-int4.litertlm"
  CHUNK_BYTES=$((1900 * 1024 * 1024))  # <2 GB per chunk: AAPT2/AssetManager limit
  if ls assets/models/gemma_e2b.chunk0 >/dev/null 2>&1; then
    echo "gemma chunks already present"
  else
    echo "downloading Gemma 4 E2B (~2.6 GB)..."
    curl -L "$GEMMA_URL" -o /tmp/gemma_e2b.litertlm
    sha256sum /tmp/gemma_e2b.litertlm | cut -d' ' -f1 > assets/models/gemma_e2b.sha256
    split -b "$CHUNK_BYTES" -d -a 1 /tmp/gemma_e2b.litertlm assets/models/gemma_e2b.chunk
    rm /tmp/gemma_e2b.litertlm
    ls -lh assets/models/gemma_e2b.chunk*
  fi
fi
echo "done"
