#!/usr/bin/env bash
#
# setup.sh — one-time install of Parley's dependencies on Debian/Ubuntu with an
# NVIDIA GPU. Idempotent; safe to re-run. (or: make setup)
#
# It does NOT install the GPU driver — see README setup step 0 for that.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

echo ">> Installing system packages (needs sudo)..."
sudo apt update
sudo apt install -y ffmpeg python3 python3-venv python3-pip git

echo ">> Setting up Python venv at $VENV..."
if [[ ! -d "$VENV" ]]; then
  python3 -m venv "$VENV"
fi
# shellcheck disable=SC1091
source "$VENV/bin/activate"
pip install --upgrade pip
pip install whisperx

echo ">> Preparing .env..."
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  echo "   .env already exists — leaving it as is."
else
  cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
  echo "   Created .env from .env.example."
fi

cat <<'EOF'

>> Dependencies installed. Two manual steps remain:

   1. Put your Hugging Face READ token in .env:
        HUGGING_FACE_ACCESS_TOKEN=hf_xxxxxxxx
      Create one at https://huggingface.co/settings/tokens

   2. Accept the diarization model terms (one click, free):
        https://huggingface.co/pyannote/speaker-diarization-community-1

Then verify everything is ready:

   make doctor
EOF
