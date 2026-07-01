#!/usr/bin/env bash
#
# lib.sh — shared helpers for Parley's scripts. Sourced, never executed.
# Callers set SCRIPT_DIR (their own directory) before sourcing this file.

# The values below are consumed by the sourcing scripts, not used here.
# shellcheck disable=SC2034

# Python venv holding whisperx (override with PARLEY_VENV).
VENV="${PARLEY_VENV:-$HOME/whisperx-env}"

# Default speaker-diarization model (override with DIARIZE_MODEL). community-1 is
# pyannote's newest and WhisperX's default. To use the older model, accept its
# terms on Hugging Face and set DIARIZE_MODEL=pyannote/speaker-diarization-3.1
DIARIZE_MODEL="${DIARIZE_MODEL:-pyannote/speaker-diarization-community-1}"

# load_env — export variables from .env next to the scripts, if it exists.
load_env() {
  [[ -f "$SCRIPT_DIR/.env" ]] || return 0
  set -a
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/.env"
  set +a
}

# require_hf_token — load .env and ensure HF_TOKEN is set, or exit with an error.
require_hf_token() {
  load_env
  HF_TOKEN="${HUGGING_FACE_ACCESS_TOKEN:-}"
  if [[ -z "$HF_TOKEN" ]]; then
    echo "ERROR: HUGGING_FACE_ACCESS_TOKEN not set (expected in $SCRIPT_DIR/.env)" >&2
    exit 1
  fi
}

# set_quiet_args — populate QUIET_ARGS from VERBOSE (default quiet). Quiet mode
# also silences library warnings and Hugging Face download progress bars.
set_quiet_args() {
  if [[ "${VERBOSE:-0}" == "1" ]]; then
    QUIET_ARGS=(--verbose True --print_progress True)
  else
    QUIET_ARGS=(--verbose False --print_progress False --log-level warning)
    export PYTHONWARNINGS="ignore"
    export HF_HUB_DISABLE_PROGRESS_BARS=1
  fi
}

# set_lang_args <lang> — populate LANG_ARG (empty lang = autodetect).
set_lang_args() {
  LANG_ARG=()
  [[ -n "${1:-}" ]] && LANG_ARG=(--language "$1")
}
