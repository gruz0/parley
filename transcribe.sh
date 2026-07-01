#!/usr/bin/env bash
#
# transcribe.sh — turn a call recording into a speaker-labeled transcript.
#
# Runs WhisperX (Whisper large-v3 + pyannote diarization) fully locally on the GPU.
#
# Usage:
#   ./transcribe.sh <video-or-audio-file> [en|pt] [min_speakers] [max_speakers]
#
# Examples:
#   ./transcribe.sh "~/Videos/Recordings/call.mp4"          # autodetect lang, 2-3 speakers
#   ./transcribe.sh "~/Videos/Recordings/call.mp4" pt       # force Portuguese
#   ./transcribe.sh "~/Videos/Recordings/call.mp4" en 2 2   # English, exactly 2 speakers
#
# Output (SRT + TXT + JSON) lands in ./transcripts/ next to this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

INPUT="${1:-}"
LANG="${2:-}"          # en | pt ; empty = autodetect
MIN_SPK="${3:-2}"
MAX_SPK="${4:-3}"

if [[ -z "$INPUT" || ! -f "$INPUT" ]]; then
  echo "Usage: $0 <video/audio file> [en|pt] [min_speakers] [max_speakers]" >&2
  exit 1
fi

# Hugging Face token from .env (needed for diarization).
require_hf_token

# One folder per recording, named after the file, keeps outputs tidy.
BASE="$(basename "${INPUT%.*}")"
OUT_DIR="$SCRIPT_DIR/transcripts/$BASE"
mkdir -p "$OUT_DIR"

set_lang_args "$LANG"
set_quiet_args # quiet by default; VERBOSE=1 for full per-segment output

# shellcheck disable=SC1091
source "$VENV/bin/activate"

echo ">> File:     $(basename "$INPUT")"
echo ">> Language: ${LANG:-auto}   Speakers: ${MIN_SPK}-${MAX_SPK}"
echo ">> Output:   $OUT_DIR"
echo

# batch_size 8 + float16 keeps peak VRAM under the 8 GB on the 3060 Ti.
whisperx "$INPUT" \
  --model large-v3 \
  "${LANG_ARG[@]}" \
  --diarize --diarize_model "$DIARIZE_MODEL" \
  --min_speakers "$MIN_SPK" --max_speakers "$MAX_SPK" \
  --hf_token "$HF_TOKEN" \
  --compute_type float16 \
  --batch_size 8 \
  "${QUIET_ARGS[@]}" \
  --output_format all \
  --output_dir "$OUT_DIR"

echo
echo ">> Done. Transcripts in: $OUT_DIR"
