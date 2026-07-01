# Roadmap

Ideas for where Parley could go next. Each numbered item is written to become a **GitHub issue** —
copy its **What / Why / How** into the issue body, and add the suggested labels.

Nothing here is committed to; it's a menu. 🥇 marks a good first issue (small, self-contained).
Effort is a rough T-shirt size (S / M / L).

## Suggested order

1. The three grounded quick-wins (#1–#3) — small, and they make the tool internally consistent.
2. **Local summarization** (#5) — highest user-visible value, and it stays 100% local (on-brand).
3. **Docker** (#7) — unlocks the "runs beyond WSL2 + Debian" story.
4. Everything else as interest/PRs arrive.

---

## Quick wins (grounded in the current code)

### 1. Recognize per-track speaker labels in `rename-speakers.sh`

**Type:** fix · **Effort:** S · **Labels:** `good first issue`, `bug`

**What.** `rename-speakers.sh` preview mode only detects labels matching `SPEAKER_[0-9]+`. But
`transcribe-tracks.sh` (via `merge_tracks.py`) emits labels like `Me`, `Guest 1`, `Guest 2`. So
`make speakers` prints nothing for per-track transcripts, and `make rename` forces the user to guess the
exact label strings.

**Why.** The two output paths produce different label shapes, and the rename tool silently fits only one
of them. Per-track (`make tracks`) is a headline feature — its transcripts should be first-class in the
rename workflow too.

**How.** In the preview block of `rename-speakers.sh`, replace the hardcoded `grep -oE "SPEAKER_[0-9]+"`
with detection of the bracketed label form `\[([^]]+)\]:` in the `.srt`/`.txt`. That captures
`SPEAKER_00`, `Me`, `Guest 1`, or already-applied names. Apply mode already does a literal `sed`
substitution on arbitrary keys, so only preview needs changing.

- Files: `rename-speakers.sh`
- Acceptance: `make speakers FILE="<a make-tracks recording>"` lists `Me`, `Guest 1`, … with sample
  lines; existing `SPEAKER_00` behavior unchanged.

### 2. Make `make doctor` actually check model readiness

**Type:** fix · **Effort:** S · **Labels:** `good first issue`

**What.** `doctor.sh` verifies ffmpeg, GPU, venv, torch-CUDA, and the token — but not whether the gated
diarization model's terms have been accepted. The `Makefile` target description says "token, model
readiness," which currently overstates what it does.

**Why.** The most common first-run failure is `GatedRepoError` (model terms not accepted). Doctor exists
precisely to catch setup problems before a long run — it should catch this one, the most likely of all.

**How.** Add a check that the token can access the model, e.g.:

```bash
python -c "from huggingface_hub import model_info; model_info('${DIARIZE_MODEL}', token='${HUGGING_FACE_ACCESS_TOKEN}')"
```

Report `ok`/`bad` accordingly. Treat a network error as a warning (don't hard-fail offline). If this
proves flaky, the minimum fix is to correct the `Makefile` description instead.

- Files: `doctor.sh`, `Makefile` (target description)
- Acceptance: with terms un-accepted, doctor reports the model isn't accessible and points to the setup
  step; with terms accepted, it passes.

### 3. Make the `.env`-block hook portable (no `grep -P`)

**Type:** fix · **Effort:** S · **Labels:** `good first issue`

**What.** `.claude/hooks/block-env-access.sh` uses `grep -P` (PCRE) with a negative lookahead. `grep -P`
is not available on stock macOS/BSD `grep`, so the hook errors there.

**Why.** The repo welcomes non-WSL contributors, and a hook that errors on macOS is worse than no hook —
it fails confusingly on every tool call.

**How.** Reimplement the match without PCRE. One approach: strip `.env.example` occurrences from the
check string first, then test with POSIX `grep -E '\.env([^a-zA-Z.]|$)'` (or an `awk` one-liner). Keep
the existing decisions identical and add a small self-test using these cases: `.env` → deny,
`.env.example` → allow, `README.md` → allow.

- Files: `.claude/hooks/block-env-access.sh`
- Acceptance: identical deny/allow decisions as today, running cleanly under macOS `grep`.

### 4. `make open` / `make list` quality-of-life targets

**Type:** feature · **Effort:** S · **Labels:** `good first issue`

**What.** `make open FILE="<name>"` opens a finished transcript in the default app; `make list` prints
all transcribed recordings (name + speaker count).

**Why.** After transcribing you immediately want to read the result; after a few weeks you want to see
what's already been processed without `ls`-ing a folder tree.

**How.** `open` runs the platform opener on `transcripts/<name>/<name>.txt` — detect
`explorer.exe` (WSL) / `xdg-open` (Linux) / `open` (macOS). `list` iterates `transcripts/*/` and prints
each name, optionally counting distinct `[label]:` speakers via `grep`. Add both `Makefile` targets.

- Files: `Makefile` (small helper if needed)
- Acceptance: `make open FILE="…"` opens the txt; `make list` prints one line per recording.

---

## Features

### 5. Local summarization (`make summarize`) + reusable prompt templates ⭐

**Type:** feature · **Effort:** M · **Labels:** `enhancement`

**What.** A `prompts/` directory of provider-agnostic prompt templates
(`summary.md`, `action-items.md`, `follow-up-email.md`), plus
`make summarize FILE="<name>" [PROMPT=action-items]` that pipes a transcript through a **local** model
via [Ollama](https://ollama.com).

**Why.** This completes the "chat with your calls" loop **without breaking the privacy promise** —
Ollama runs entirely on-device, unlike a cloud LLM. And the templates are useful even without Ollama:
paste them into Claude, ChatGPT, or NotebookLM. (This is deliberately _not_ a Claude Code-specific slash
command — that would couple Parley to one assistant and contradict its tool-agnostic positioning.)

**How.**

- Add `prompts/*.md` — each a plain-language instruction with a spot for the transcript.
- `summarize.sh <name> [prompt]`: read `transcripts/<name>/<name>.txt`, prepend the chosen prompt, pipe
  to `ollama run "${PARLEY_OLLAMA_MODEL:-llama3.1}"`, and write
  `transcripts/<name>/<name>.<prompt>.md`. Friendly error if `ollama` isn't installed. Source `lib.sh`.
- `make summarize FILE="…" PROMPT="…"`; document the templates as copy-paste-anywhere in the README's
  "chat with your calls" section.

- Files: `prompts/*.md`, `summarize.sh`, `Makefile`, `README.md`, `AGENTS.md` layout
- Acceptance: produces a local summary file; the templates are usable standalone in any assistant.

### 6. Auto-fallback on CUDA out-of-memory

**Type:** feature · **Effort:** M · **Labels:** `enhancement`

**What.** When WhisperX hits CUDA OOM, automatically retry with reduced settings
(`--batch_size 4`, then `--compute_type int8`) instead of failing.

**Why.** 8 GB (and smaller) cards can OOM on some files. Today the README tells users to hand-edit flags;
auto-fallback makes Parley robust out of the box on modest GPUs.

**How.** Add a helper in `lib.sh` (e.g. `run_whisperx_with_fallback`) that runs the command, and on a
detected OOM (scan stderr for `out of memory` / `CUDA`) re-runs with degraded params. Cap retries at two;
always print that it downgraded and why. Call it from both `transcribe.sh` and `transcribe-tracks.sh`.

- Files: `lib.sh`, `transcribe.sh`, `transcribe-tracks.sh`
- Acceptance: a file that OOMs at `batch_size 8` completes automatically at a lower setting, with a clear
  message. Keep stderr detection conservative to avoid masking unrelated failures.

### 7. Batch mode — transcribe a whole folder, skip what's done

**Type:** feature · **Effort:** M · **Labels:** `enhancement`

**What.** `make transcribe-all DIR="<folder>"` transcribes every recording in a folder, skipping any that
already have a `transcripts/<name>/` output.

**Why.** The workflow is "record 3–4 calls a week." Dropping them in a folder and processing only the new
ones (idempotently) is far nicer than one command per file.

**How.** New `transcribe-batch.sh <dir> [lang] [min] [max]`: loop over common extensions
(`mp4 mkv wav m4a mov`), compute `BASE` per file, `continue` if `transcripts/$BASE` exists, else call
`transcribe.sh`. Run sequentially (the GPU is shared). Print a done/skipped/failed summary. Reuse
`lib.sh`; add a `make transcribe-all` target.

- Files: `transcribe-batch.sh`, `Makefile`, `README.md`, `AGENTS.md` layout
- Acceptance: first run transcribes all; a second run transcribes only newly added files.

---

## Portability (the big open lane)

> Parley is currently tested only on WSL2 + Debian 12 with NVIDIA. These reduce that constraint.

### 8. Docker image (CUDA base) for a reproducible environment

**Type:** feature · **Effort:** L · **Labels:** `enhancement`, `help wanted`

**What.** A `Dockerfile` (NVIDIA CUDA base) + docs so anyone with an NVIDIA GPU and
`nvidia-container-toolkit` can run Parley in a container on any host OS.

**Why.** This is the most direct answer to "only tested on WSL2 + Debian": a pinned, reproducible
environment that sidesteps host-specific CUDA/driver setup.

**How.** Start from a CUDA-compatible base (or a slim Python base relying on pip-bundled CUDA libs),
install `ffmpeg` + `whisperx`. Mount recordings and `transcripts/` as volumes; pass the HF token via env.
Document `docker run --gpus all -v …`. Optionally pre-warm the model cache in the image.

- Files: `Dockerfile`, `.dockerignore`, `README.md` ("Run with Docker")
- Acceptance: `docker build` + `docker run --gpus all …` transcribes a file on a non-WSL host.
- Caveats: large image (torch + CUDA); GPU passthrough needs `nvidia-container-toolkit`.

### 9. CPU / Apple-Silicon fallback

**Type:** feature · **Effort:** L · **Labels:** `enhancement`, `help wanted`

**What.** Let Parley run on CPU (and, where feasible, Apple Silicon) for users without an NVIDIA GPU,
accepting slower transcription.

**Why.** Broadens the audience well beyond NVIDIA owners — a large share of potential users are on Macs.

**How.** WhisperX/faster-whisper support `--device cpu --compute_type int8`. Add device auto-detection in
`lib.sh`: if CUDA is unavailable, fall back to CPU + int8 and allow a `MODEL` override (a smaller model
for tolerable speed). Stop `doctor.sh` from hard-failing without CUDA (warn instead). Document the
non-NVIDIA path and its speed expectations. (Note: pyannote diarization on CPU works but is slow; MPS
support is limited — CPU int8 is the realistic path.)

- Files: `lib.sh`, `transcribe*.sh`, `doctor.sh`, `README.md`
- Acceptance: transcribes (slowly) end-to-end on a CPU-only machine.

---

## UX polish

### 10. Per-recording config / provenance sidecar

**Type:** feature · **Effort:** M · **Labels:** `enhancement`

**What.** Write a small sidecar (e.g. `transcripts/<name>/parley.json`) recording the args used
(language, speaker count, model, date). Optionally, re-running a recording without args reuses them.

**Why.** Users re-run files after tweaking settings; re-typing `LANG`/`SPEAKERS` is error-prone. A
sidecar also documents _how_ each transcript was produced — useful months later.

**How.** On each run, `transcribe.sh` writes the sidecar into the output folder. A follow-up could read it
to supply defaults when a recording is re-run. Keep it minimal — ship provenance first, auto-defaults
later, to avoid scope creep.

- Files: `transcribe.sh`, `transcribe-tracks.sh`, `lib.sh`
- Acceptance: every run leaves a readable record of its parameters in the output folder.
