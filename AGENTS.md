# AGENTS.md

Guidance for AI assistants (Claude Code, Codex, Cursor, Gemini CLI, …) working in this repo.
Human contributors: see [CONTRIBUTING.md](CONTRIBUTING.md). End users: see [README.md](README.md).

## What this is

**Parley** turns call recordings into speaker-labeled transcripts, fully locally on an NVIDIA GPU. It's
a thin wrapper of Bash scripts + one small Python file around
[WhisperX](https://github.com/m-bain/whisperX) (Whisper `large-v3` + pyannote diarization).

## Layout

- `transcribe.sh` — recording → transcript; auto-detects single- vs multi-track (dispatches to
  `transcribe-tracks.sh` for the latter) and auto-detects the speaker count unless one is given
- `transcribe-tracks.sh` — OBS multi-track recording → per-track transcript
- `rename-speakers.sh` — replace `SPEAKER_00` with real names across all formats
- `merge_tracks.py` — merge per-track JSON into one timeline (used by `transcribe-tracks.sh`)
- `lib.sh` — shared helpers sourced by the scripts (`.env`/token load, quiet + language + speaker args, audio-track count, `VENV`/`DIARIZE_MODEL` defaults)
- `doctor.sh` / `setup.sh` — preflight check / one-time install
- `Makefile` — user-facing commands (`make help`)

## Commands

- Run: `make transcribe FILE="..." LANG=pt` — see `make help` for all targets
- Format docs: `bun run format` (verify: `bun run format:check`)
- Lint shell: `shellcheck *.sh`
- Lint Python: `ruff check .`

## Conventions

- **Shell:** Bash with `set -euo pipefail`. Must pass `shellcheck` with no findings. Keep scripts
  simple and dependency-light — match the existing style, don't introduce a framework.
- **Python:** ruff-clean, line length 100 (`ruff.toml`).
- **Markdown:** Prettier via Bun. Run `bun run format` after editing any `.md`.
- **Line endings:** LF everywhere (enforced by `.gitattributes`) — shell scripts break on CRLF.

## Hard rules

- **Never commit `.env`** (Hugging Face token) or anything under `transcripts/` — that is private data.
- **Keep committed docs and examples anonymized:** use `pt` for the non-English example language,
  generic paths like `~/Videos/Recordings/...`, and placeholder names/companies. Never put real names,
  company names, or personal file paths into committed files.
- **Platform:** only tested on WSL2 + Debian 12 with an NVIDIA GPU — don't assume other environments.

## Verifying a change

There's no formal test suite — verify by running on a short clip:

```bash
ffmpeg -ss 0 -t 45 -i input.mp4 -vn -c:a aac clip.m4a
./transcribe.sh clip.m4a en 2 2
# check that transcripts/clip/ has the speaker-labeled output
```

Before finishing, these must all pass: `shellcheck *.sh`, `bun run format:check`, `ruff check .`.
