#!/usr/bin/env bash
#
# rename-speakers.sh — replace speaker labels (SPEAKER_00 / SPEAKER_01, or the
# per-track labels Me / Guest 1 / Guest 2) with real names across every transcript
# file (.srt .txt .vtt .tsv .json) for one recording.
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
  # Labels live in the bracketed prefix of each subtitle line — "[SPEAKER_00]: ",
  # or per-track "[Me]: " / "[Guest 1]: " (from merge_tracks.py), or already-applied
  # names. Match on that form so every label shape is listed, not just SPEAKER_NN.
  LABELS=()
  while IFS= read -r spk; do
    LABELS+=("$spk")
    # Anchor counts/samples on the literal "[label]:" so short labels like "Me"
    # don't match substrings inside the dialogue text.
    count=$(grep -cF "[$spk]:" "$SRT")
    sample=$(grep -m1 -F "[$spk]:" "$SRT" | sed -E 's/^\[[^]]*\]: ?//')
    printf '  %-12s (%s segments)\n     e.g. "%s"\n\n' "$spk" "$count" "${sample:0:90}"
  done < <(grep -oE '^\[[^]]+\]:' "$SRT" | sed -E 's/^\[|\]:$//g' | sort -u)

  # Seed a copy-paste rename command from the labels we found, quoting any that
  # contain spaces (e.g. "Guest 1") so the pair survives word-splitting.
  hint=""
  demo=(Alex Sam Jordan Riley Casey)
  n=0
  for l in "${LABELS[@]}"; do
    name="${demo[n]:-Name}"; n=$((n + 1))
    if [[ "$l" == *[![:alnum:]_]* ]]; then hint+=" \"$l=$name\""; else hint+=" $l=$name"; fi
  done
  [[ -n "$hint" ]] || hint=" SPEAKER_00=Alex SPEAKER_01=Sam"
  echo "Rename with, e.g.:"
  echo "  $0 \"$BASE\"$hint"
  exit 0
fi

# ---- Apply mode ----
# Back up originals once, up front, so *.bak is the true pre-rename version.
for f in "${FILES[@]}"; do cp -f "$f" "$f.bak"; done

echo "Renaming across ${#FILES[@]} file(s) for \"$BASE\":"
# Collect all substitutions, then apply them in a single sed pass per file.
# '|' delimiter avoids clashes with names; keys/names won't contain it.
#
# Anchor on where a label actually appears, so a short label like the per-track
# "Me" can't rewrite the same letters inside dialogue ("Me too" -> "Alex too"):
#   [label]:   subtitle prefix — srt, vtt, and single-track txt
#   ] label:   per-track txt, e.g. "[00:00:01] Me: ..."
# SPEAKER_NN also appears bare in the JSON ("speaker": "SPEAKER_00") and never
# inside dialogue, so for those a plain substitution is safe and covers the format.
SED_EXPR=()
for pair in "$@"; do
  key="${pair%%=*}"; val="${pair#*=}"
  if [[ "$key" == "$pair" || -z "$key" || -z "$val" ]]; then
    echo "  ! skipping malformed pair: '$pair' (expected LABEL=Name, e.g. SPEAKER_00=Alex or 'Guest 1=Sam')" >&2
    continue
  fi
  echo "  $key -> $val"
  SED_EXPR+=(-e "s|\[$key\]:|[$val]:|g" -e "s|\] $key:|] $val:|g")
  [[ "$key" =~ ^SPEAKER_[0-9]+$ ]] && SED_EXPR+=(-e "s|$key|$val|g")
done
if [[ ${#SED_EXPR[@]} -gt 0 ]]; then
  for f in "${FILES[@]}"; do sed -i "${SED_EXPR[@]}" "$f"; done
fi
echo "Done. Originals saved as *.bak"
