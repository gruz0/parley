#!/usr/bin/env bash
#
# transcribe.sh — turn a call recording into a speaker-labeled transcript.
#
# Runs WhisperX (Whisper large-v3 + pyannote diarization) fully locally on the GPU.
#
# With no speaker counts, this figures out the recording on its own: a multi-track
# (3+ audio streams) OBS file hands off to per-track mode, and a single-track file
# is diarized with the speaker count auto-detected.
#
# To override, set exactly one of:
#   - min/max speakers (positional)   -> force single-track diarization of the mix
#   - PARLEY_GUESTS="min max" (env)    -> force per-track mode, pinning the guest count
# PARLEY_NAME="You" labels your mic track in per-track mode.
#
# Usage:
#   ./transcribe.sh <video-or-audio-file> [en|pt] [min_speakers] [max_speakers]
#
# Examples:
#   ./transcribe.sh "~/Videos/Recordings/call.mp4"           # auto: detect type + speaker count
#   ./transcribe.sh "~/Videos/Recordings/call.mp4" pt        # force Portuguese, auto speakers
#   ./transcribe.sh "~/Videos/Recordings/call.mp4" en 2 2    # English, exactly 2 speakers
#   PARLEY_GUESTS="1 1" ./transcribe.sh "call.mkv" en        # per-track, exactly 1 guest
#
# Output (SRT + TXT + JSON) lands in ./transcripts/ next to this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

INPUT="${1:-}"
LANG="${2:-}"          # en | pt ; empty = autodetect
MIN_SPK="${3:-}"       # empty min+max = auto-detect the speaker count
MAX_SPK="${4:-}"

if [[ -z "$INPUT" || ! -f "$INPUT" ]]; then
  echo "Usage: $0 <video/audio file> [en|pt] [min_speakers] [max_speakers]" >&2
  exit 1
fi

# Per-track guest-count override, as "min max" (e.g. from `make transcribe GUESTS='1 1'`).
read -r GUEST_MIN GUEST_MAX _ <<<"${PARLEY_GUESTS:-}"

# SPEAKERS forces single-track diarization; GUESTS forces per-track mode. Both at
# once is contradictory — the mix can't also be split into separate tracks.
if [[ -n "$MIN_SPK$MAX_SPK" && -n "$GUEST_MIN$GUEST_MAX" ]]; then
  echo "ERROR: set either SPEAKERS (single-track headcount) or GUESTS (per-track guest count), not both." >&2
  exit 1
fi

# Hand off to per-track mode when the guest count is pinned, or — with nothing
# specified — when the file itself is multi-track (mix + mic + desktop).
if [[ -n "$GUEST_MIN$GUEST_MAX" ]]; then
  exec "$SCRIPT_DIR/transcribe-tracks.sh" "$INPUT" "$LANG" "${PARLEY_NAME:-Me}" "$GUEST_MIN" "$GUEST_MAX"
elif [[ -z "$MIN_SPK$MAX_SPK" ]] && [[ "$(count_audio_tracks "$INPUT")" -ge 3 ]]; then
  echo ">> Auto: multi-track recording detected — switching to per-track mode."
  echo
  exec "$SCRIPT_DIR/transcribe-tracks.sh" "$INPUT" "$LANG" "${PARLEY_NAME:-Me}"
fi

# Hugging Face token from .env (needed for diarization).
require_hf_token

# One folder per recording, named after the file, keeps outputs tidy.
BASE="$(basename "${INPUT%.*}")"
OUT_DIR="$SCRIPT_DIR/transcripts/$BASE"
mkdir -p "$OUT_DIR"

set_lang_args "$LANG"
set_speaker_args "$MIN_SPK" "$MAX_SPK" # empty min+max = auto-detect speaker count
set_quiet_args # quiet by default; VERBOSE=1 for full per-segment output

# shellcheck disable=SC1091
source "$VENV/bin/activate"

echo ">> File:     $(basename "$INPUT")"
echo ">> Language: ${LANG:-auto}   Speakers: $(speaker_label "$MIN_SPK" "$MAX_SPK")"
echo ">> Output:   $OUT_DIR"
echo

# batch_size 8 + float16 keeps peak VRAM under the 8 GB on the 3060 Ti.
whisperx "$INPUT" \
  --model large-v3 \
  "${LANG_ARG[@]}" \
  --diarize --diarize_model "$DIARIZE_MODEL" \
  "${SPEAKER_ARGS[@]}" \
  --hf_token "$HF_TOKEN" \
  --compute_type float16 \
  --batch_size 8 \
  "${QUIET_ARGS[@]}" \
  --output_format all \
  --output_dir "$OUT_DIR"

echo
echo ">> Done. Transcripts in: $OUT_DIR"
