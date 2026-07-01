#!/usr/bin/env bash
#
# rename-speakers.sh — replace SPEAKER_00 / SPEAKER_01 / ... with real names
# across every transcript file (.srt .txt .vtt .tsv .json) for one recording.
#
# 1) Preview who's who (no changes) — shows each speaker + a sample line:
#      ./rename-speakers.sh "<file-or-basename>"
#
# 2) Apply names (originals backed up as *.bak):
#      ./rename-speakers.sh "<file-or-basename>" SPEAKER_00=Alex SPEAKER_01=Sam
#
# <file-or-basename> can be a path to any of the transcript files, or just the
# recording's base name (looked up in ./transcripts/).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSCRIPTS="$SCRIPT_DIR/transcripts"

ARG="${1:-}"
if [[ -z "$ARG" ]]; then
  echo "Usage: $0 <file-or-basename> [SPEAKER_00=Name SPEAKER_01=Name ...]" >&2
  exit 1
fi
shift

# Resolve base name + directory, whether given a full path or a bare name.
BASE="$(basename "${ARG%.*}")"
if [[ -f "$ARG" ]]; then
  DIR="$(cd "$(dirname "$ARG")" && pwd)"
else
  # Each recording's files live in transcripts/<basename>/
  DIR="$TRANSCRIPTS/$BASE"
fi

# Collect the sibling transcript files that actually exist.
FILES=()
for ext in srt txt vtt tsv json; do
  [[ -f "$DIR/$BASE.$ext" ]] && FILES+=("$DIR/$BASE.$ext")
done
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No transcript files found for '$BASE' in $DIR" >&2
  exit 1
fi

# ---- Preview mode (no name pairs given) ----
if [[ $# -eq 0 ]]; then
  SRT="$DIR/$BASE.srt"
  [[ -f "$SRT" ]] || SRT="${FILES[0]}"
  echo "Speakers in \"$BASE\":"
  echo
  while IFS= read -r spk; do
    count=$(grep -c "$spk" "$SRT")
    sample=$(grep -m1 "$spk" "$SRT" | sed -E "s/.*\[$spk\]: ?//")
    printf '  %-12s (%s segments)\n     e.g. "%s"\n\n' "$spk" "$count" "${sample:0:90}"
  done < <(grep -oE "SPEAKER_[0-9]+" "$SRT" | sort -u)
  echo "Rename with, e.g.:"
  echo "  $0 \"$BASE\" SPEAKER_00=Alex SPEAKER_01=Sam"
  exit 0
fi

# ---- Apply mode ----
# Back up originals once, up front, so *.bak is the true pre-rename version.
for f in "${FILES[@]}"; do cp -f "$f" "$f.bak"; done

echo "Renaming across ${#FILES[@]} file(s) for \"$BASE\":"
# Collect all substitutions, then apply them in a single sed pass per file.
# '|' delimiter avoids clashes with names; keys/names won't contain it.
SED_EXPR=()
for pair in "$@"; do
  key="${pair%%=*}"; val="${pair#*=}"
  if [[ "$key" == "$pair" || -z "$key" || -z "$val" ]]; then
    echo "  ! skipping malformed pair: '$pair' (expected SPEAKER_XX=Name)" >&2
    continue
  fi
  echo "  $key -> $val"
  SED_EXPR+=(-e "s|$key|$val|g")
done
if [[ ${#SED_EXPR[@]} -gt 0 ]]; then
  for f in "${FILES[@]}"; do sed -i "${SED_EXPR[@]}" "$f"; done
fi
echo "Done. Originals saved as *.bak"
