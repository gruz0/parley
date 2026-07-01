#!/usr/bin/env python3
"""Merge two WhisperX JSON transcripts into one timeline-ordered transcript.

Used by transcribe-tracks.sh:
  - "you"    = your isolated mic track, transcribed as a single speaker
  - "guests" = the desktop/call track, diarized into SPEAKER_00/01/...

Your segments get a fixed name; guest speakers are relabeled "Guest 1",
"Guest 2", ... in order of first appearance. Everything is sorted by start time
and written as .srt + .txt.
"""
import argparse
import json


def load_segments(path, force_speaker=None, relabel_prefix=None):
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)

    order = {}
    segs = []
    for s in data.get("segments", []):
        text = (s.get("text") or "").strip()
        start = s.get("start")
        if not text or start is None:
            continue
        end = s.get("end")
        end = float(end) if end is not None else float(start)

        if force_speaker is not None:
            speaker = force_speaker
        else:
            raw = s.get("speaker") or "SPEAKER_?"
            if relabel_prefix:
                if raw not in order:
                    order[raw] = f"{relabel_prefix} {len(order) + 1}"
                speaker = order[raw]
            else:
                speaker = raw

        segs.append({
            "start": float(start),
            "end": end,
            "speaker": speaker,
            "text": text,
        })
    return segs


def ts(seconds, sep=","):
    if seconds < 0:
        seconds = 0
    ms = int(round(seconds * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d}{sep}{ms:03d}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--you", required=True, help="WhisperX JSON for your mic track")
    ap.add_argument("--guests", required=True, help="WhisperX JSON for the guests track")
    ap.add_argument("--you-name", default="Me", help="Label for your segments")
    ap.add_argument("--out-srt", required=True)
    ap.add_argument("--out-txt", required=True)
    args = ap.parse_args()

    segs = load_segments(args.you, force_speaker=args.you_name)
    segs += load_segments(args.guests, relabel_prefix="Guest")
    segs.sort(key=lambda x: x["start"])

    with open(args.out_srt, "w", encoding="utf-8") as srt:
        for i, s in enumerate(segs, 1):
            srt.write(f"{i}\n{ts(s['start'])} --> {ts(s['end'])}\n"
                      f"[{s['speaker']}]: {s['text']}\n\n")

    with open(args.out_txt, "w", encoding="utf-8") as txt:
        for s in segs:
            txt.write(f"[{ts(s['start'], sep='.')[:8]}] {s['speaker']}: {s['text']}\n")

    print(f"Merged {len(segs)} segments -> {args.out_srt}")


if __name__ == "__main__":
    main()
