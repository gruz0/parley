#!/usr/bin/env bash
#
# doctor.sh — preflight checks for Parley. Verifies your environment is ready
# before you spend time on a real transcription run.
#
#   ./doctor.sh   (or: make doctor)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

pass=0
fail=0
ok() {
  printf '  \033[32m✓\033[0m %s\n' "$1"
  pass=$((pass + 1))
}
bad() {
  printf '  \033[31m✗\033[0m %s\n' "$1"
  fail=$((fail + 1))
}

echo "Parley doctor — checking your environment"
echo

# ffmpeg
if command -v ffmpeg >/dev/null 2>&1; then
  ok "ffmpeg installed ($(ffmpeg -version | head -1 | cut -d' ' -f1-3))"
else
  bad "ffmpeg not found — sudo apt install ffmpeg"
fi

# GPU visible
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  ok "GPU visible ($(nvidia-smi --query-gpu=name --format=csv,noheader | head -1))"
else
  bad "nvidia-smi failed — GPU not visible in this shell (see README setup step 0)"
fi

# venv + whisperx + torch CUDA
if [[ -f "$VENV/bin/activate" ]]; then
  ok "venv found at $VENV"
  # shellcheck disable=SC1091
  source "$VENV/bin/activate"
  if command -v whisperx >/dev/null 2>&1; then
    ok "whisperx installed"
  else
    bad "whisperx not in venv — pip install whisperx"
  fi
  if [[ "$(python -c 'import torch; print(torch.cuda.is_available())' 2>/dev/null)" == "True" ]]; then
    ok "torch sees a CUDA GPU"
  else
    bad "torch.cuda.is_available() is False — a run would fall back to (very slow) CPU"
  fi
else
  bad "venv missing at $VENV — see README setup step 2, or run: make setup"
fi

# .env token
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  load_env
  if [[ -n "${HUGGING_FACE_ACCESS_TOKEN:-}" ]]; then
    ok ".env has HUGGING_FACE_ACCESS_TOKEN set"
  else
    bad ".env exists but HUGGING_FACE_ACCESS_TOKEN is empty"
  fi
else
  bad ".env not found — cp .env.example .env and add your Hugging Face token"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  printf '\033[32mAll good (%d checks passed). Ready: make transcribe FILE="..."\033[0m\n' "$pass"
else
  printf '\033[31m%d check(s) failed, %d passed. Fix the marked items above.\033[0m\n' "$fail" "$pass"
  exit 1
fi
