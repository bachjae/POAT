#!/usr/bin/env bash
# Fetches the on-device models RallyCoach bundles as assets.
#
#   MoveNet (pose):  public, no auth, small — always fetched, committed to git.
#   Gemma 4 E2B (coach brain): Apache-2.0, ungated on HuggingFace, 2.58 GB —
#     fetched only with --gemma, git-ignored, split into <2 GB APK-safe chunks.
#     Builds WITHOUT the chunks still work: the app runs in Lite mode.
#
# Usage: tool/fetch_models.sh [--gemma]
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

if [[ "${1:-}" == "--gemma" ]]; then
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
