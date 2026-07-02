#!/usr/bin/env bash
#
# transcribe-tracks.sh — per-track transcription for OBS multi-track recordings.
#
# Assumes the recording's audio streams follow the OBS routing in the README:
#   a:0 = full mix (ignored)   a:1 = your mic ("you")   a:2 = desktop ("guests")
#
# Your track is transcribed as a single speaker (perfect "you" labeling); the
# guests track is diarized. Results are merged into one timeline-ordered
# transcript, so only the remote guests ever need diarizing.
#
# Guest count is auto-detected unless you pass guest_min/guest_max.
#
# Usage:
#   ./transcribe-tracks.sh <multitrack-file> [en|pt] [your-name] [guest_min] [guest_max]
#
# Examples:
#   ./transcribe-tracks.sh "~/Videos/Recordings/call.mkv" en "Alex"        # auto guest count
#   ./transcribe-tracks.sh "~/Videos/Recordings/call.mkv" pt "Alex" 1 1    # exactly 1 guest

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

INPUT="${1:-}"
LANG="${2:-}"
YOU_NAME="${3:-Me}"
GUEST_MIN="${4:-}" # empty min+max = auto-detect how many guests are on the desktop track
GUEST_MAX="${5:-}"

if [[ -z "$INPUT" || ! -f "$INPUT" ]]; then
  echo "Usage: $0 <multitrack-file> [en|pt] [your-name] [guest_min] [guest_max]" >&2
  exit 1
fi

# Hugging Face token (for diarization of the guests track).
require_hf_token

# Need at least 3 audio streams (mix + mic + desktop).
NUM_A=$(count_audio_tracks "$INPUT")
if [[ "$NUM_A" -lt 3 ]]; then
  echo "ERROR: '$(basename "$INPUT")' has $NUM_A audio track(s); per-track mode needs 3." >&2
  echo "       This looks like a single-track recording — use ./transcribe.sh instead." >&2
  exit 1
fi

BASE="$(basename "${INPUT%.*}")"
OUT_DIR="$SCRIPT_DIR/transcripts/$BASE"
WORK="$OUT_DIR/_tracks"
mkdir -p "$WORK"

set_lang_args "$LANG"
set_speaker_args "$GUEST_MIN" "$GUEST_MAX" # empty min+max = auto-detect guest count
set_quiet_args # quiet by default; VERBOSE=1 for full per-segment output
GUEST_LABEL=$(speaker_label "$GUEST_MIN" "$GUEST_MAX")

echo ">> File:     $(basename "$INPUT")"
echo ">> You:      \"$YOU_NAME\" (track a:1)   Guests: $GUEST_LABEL (track a:2)"
echo ">> Language: ${LANG:-auto}"
echo

echo ">> Extracting audio tracks..."
# One decode pass, two mapped outputs.
ffmpeg -y -loglevel error -i "$INPUT" \
  -map 0:a:1 -ac 1 -ar 16000 "$WORK/you.wav" \
  -map 0:a:2 -ac 1 -ar 16000 "$WORK/guests.wav"

# shellcheck disable=SC1091
source "$VENV/bin/activate"

echo ">> Transcribing YOUR track (single speaker)..."
whisperx "$WORK/you.wav" --model large-v3 "${LANG_ARG[@]}" \
  --compute_type float16 --batch_size 8 "${QUIET_ARGS[@]}" \
  --output_format json --output_dir "$WORK"

echo ">> Transcribing GUESTS track (diarized, $GUEST_LABEL speakers)..."
whisperx "$WORK/guests.wav" --model large-v3 "${LANG_ARG[@]}" \
  --diarize --diarize_model "$DIARIZE_MODEL" \
  "${SPEAKER_ARGS[@]}" \
  --hf_token "$HF_TOKEN" \
  --compute_type float16 --batch_size 8 "${QUIET_ARGS[@]}" \
  --output_format json --output_dir "$WORK"

echo ">> Merging tracks into one transcript..."
OUT_SRT="$OUT_DIR/${BASE}.srt"
OUT_TXT="$OUT_DIR/${BASE}.txt"
python "$SCRIPT_DIR/merge_tracks.py" \
  --you "$WORK/you.json" --guests "$WORK/guests.json" \
  --you-name "$YOU_NAME" --out-srt "$OUT_SRT" --out-txt "$OUT_TXT"

echo
echo ">> Done."
echo "   $OUT_SRT"
echo "   $OUT_TXT"
echo "   (intermediate per-track files kept in $WORK)"
