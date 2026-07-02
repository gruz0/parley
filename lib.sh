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
# NB: ends with an explicit `return 0` — a trailing `[[ … ]] && …` would make the
# function exit non-zero when the condition is false and abort callers under `set -e`.
set_lang_args() {
  LANG_ARG=()
  [[ -n "${1:-}" ]] && LANG_ARG=(--language "$1")
  return 0
}

# set_speaker_args <min> <max> — populate SPEAKER_ARGS for whisperx --diarize.
# Empty min and max both omitted = let pyannote auto-detect the speaker count.
set_speaker_args() {
  SPEAKER_ARGS=()
  [[ -n "${1:-}" ]] && SPEAKER_ARGS+=(--min_speakers "$1")
  [[ -n "${2:-}" ]] && SPEAKER_ARGS+=(--max_speakers "$2")
  return 0
}

# speaker_label <min> <max> — human-readable speaker count for status output
# ("auto" when unbounded, "N" when min==max, "min-max" otherwise).
speaker_label() {
  if [[ -z "${1:-}" && -z "${2:-}" ]]; then
    echo "auto"
  elif [[ "${1:-}" == "${2:-}" ]]; then
    echo "${1:-${2:-}}"
  else
    echo "${1:-1}-${2:-?}"
  fi
}

# count_audio_tracks <file> — number of audio streams in the container.
count_audio_tracks() {
  ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$1" | wc -l
}
